/**
 * Cloud saves: one saved game per Google account, so a colony can be carried
 * between devices (see accounts.js for how a device gets its account's code).
 *
 *   GET /cloud/save   the player's cloud save: { save: "<the save file's text>", updated }
 *                     (updated = when it was stored, ms since 1970), or { save: null, updated: 0 }
 *   PUT /cloud/save   store the player's save (a Lastborn Colony save file, as JSON text)
 *
 * A player is known only by their private sync code, sent as
 * `Authorization: Bearer <code>`. The Worker never stores the code itself:
 * each save lives in its own Durable Object named by the code's SHA-256 hash,
 * so nobody can list saves or read one without the code.
 *
 * Binding: SAVE_VAULT (Durable Object class SaveVault, see wrangler.toml)
 */

import { corsHeaders } from "./cors.js";

export const CODE_ALPHABET = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789";
export const CODE_LENGTH = 12;
/** A save is the whole colony as JSON; a long game is still well under this. */
export const MAX_SAVE_BYTES = 1_000_000;
/** A device may write at most once every this many ms. */
export const MIN_WRITE_GAP_MS = 5_000;

function headersFor(request) {
  return {
    ...corsHeaders(request, "GET, PUT, OPTIONS", "Content-Type, Accept, Authorization"),
    "Content-Type": "application/json; charset=utf-8",
    "Cache-Control": "no-store",
  };
}

function json(request, body, status = 200) {
  return new Response(JSON.stringify(body), { status, headers: headersFor(request) });
}

/** The code without dashes or spaces, upper-case; "" if it isn't a valid code. */
export function normalizeCode(raw) {
  if (typeof raw !== "string") return "";
  const code = raw.replace(/[\s-]/g, "").toUpperCase();
  if (code.length !== CODE_LENGTH) return "";
  for (const ch of code) {
    if (!CODE_ALPHABET.includes(ch)) return "";
  }
  return code;
}

export async function hashCode(code) {
  const digest = await crypto.subtle.digest("SHA-256", new TextEncoder().encode("lastborn-save:" + code));
  return [...new Uint8Array(digest)].map((b) => b.toString(16).padStart(2, "0")).join("");
}

/** A save the Worker will keep: a Lastborn Colony save (a JSON object with a numeric `version`), not too big. */
export function validateSave(text) {
  if (typeof text !== "string" || text.length === 0) return { error: "empty save" };
  if (text.length > MAX_SAVE_BYTES) return { error: "save too large" };
  let save;
  try {
    save = JSON.parse(text);
  } catch {
    return { error: "invalid json" };
  }
  if (!save || typeof save !== "object" || Array.isArray(save)) return { error: "invalid save" };
  if (!Number.isFinite(save.version)) return { error: "invalid save" };
  return { save };
}

/** Routes /cloud/save to the player's own SaveVault. */
export async function handleCloud(request, env) {
  if (request.method === "OPTIONS") return new Response(null, { status: 204, headers: headersFor(request) });
  if (!env.SAVE_VAULT) return json(request, { error: "cloud saves are not set up" }, 503);
  const auth = request.headers.get("Authorization") || "";
  const code = normalizeCode(auth.replace(/^Bearer\s+/i, ""));
  if (!code) return json(request, { error: "invalid code" }, 401);
  if (request.method !== "GET" && request.method !== "PUT") return json(request, { error: "method not allowed" }, 405);
  let body = "";
  if (request.method === "PUT") {
    const declared = parseInt(request.headers.get("content-length") || "0", 10);
    if (Number.isFinite(declared) && declared > MAX_SAVE_BYTES) return json(request, { error: "save too large" }, 413);
    body = await request.text();
    const checked = validateSave(body);
    if (checked.error) return json(request, { error: checked.error }, checked.error === "save too large" ? 413 : 400);
  }
  const stub = env.SAVE_VAULT.get(env.SAVE_VAULT.idFromName(await hashCode(code)));
  const res = await stub.fetch("https://vault/save", { method: request.method, body: request.method === "PUT" ? body : undefined });
  // The vault's answer, with this request's CORS headers.
  return new Response(await res.text(), { status: res.status, headers: headersFor(request) });
}

/** One player's cloud save. */
export class SaveVault {
  constructor(state) {
    this.storage = state.storage;
  }

  async fetch(request) {
    const reply = (body, status = 200) =>
      new Response(JSON.stringify(body), { status, headers: { "Content-Type": "application/json; charset=utf-8" } });
    if (request.method === "GET") {
      const save = (await this.storage.get("save")) ?? null;
      const updated = (await this.storage.get("updated")) ?? 0;
      // The save goes back as the exact text the game sent (key order and
      // number precision matter to a Lastborn save), not re-encoded.
      return reply({ save: typeof save === "string" ? save : null, updated });
    }
    const now = Date.now();
    const last = (await this.storage.get("updated")) ?? 0;
    if (now - last < MIN_WRITE_GAP_MS) return reply({ error: "too soon", updated: last }, 429);
    const text = await request.text();
    await this.storage.put({ save: text, updated: now });
    return reply({ ok: true, updated: now });
  }
}
