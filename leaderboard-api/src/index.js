/**
 * Lastborn Colony online services (a Cloudflare Worker).
 *   GET  /leaderboard?planet=brume[&difficulty=hard]
 *                                    one board, best first: { planet, difficulty, updated, entries }
 *   GET  /leaderboard                every planet's board: { updated, planets: { brume: [...] } }
 *   POST /leaderboard                send one score; it is checked, then saved:
 *                                    { accepted, rank, planet, entries }
 *   GET/PUT /cloud/save              cloud saves, by private sync code (see cloud.js)
 *   GET/POST /suggestions            anonymous player suggestions → GitHub Issues (see suggestions.js)
 *   /auth/*                          Sign in with Google (see accounts.js)
 *   GET  /privacy                    the privacy policy (see privacy.js)
 *
 * The Worker is the only thing that can write the board. It keeps the board in
 * Workers KV (key "board"). If the optional GITHUB_TOKEN secret is set, it
 * also commits leaderboard.json to the repo's `data` branch so anyone can see
 * it on GitHub; without the token the board works from KV alone. The game
 * never holds any key.
 *
 * Binding:  LEADERBOARD_KV (Workers KV), SAVE_VAULT and ACCOUNTS (Durable Objects)
 * Secrets:  GOOGLE_CLIENT_ID, GOOGLE_CLIENT_SECRET, optional GITHUB_TOKEN
 *           (fine-grained token on Zephino/Lastborn_Colony only: Issues read/write
 *           for suggestions; Contents read/write only for the optional board copy)
 *
 * Input safety: every value from a player's device is checked here, whatever
 * the game checked (see safety.js and README "Input safety"). No SQL is used:
 * storage is Workers KV and the Durable Object key/value API. Any future SQL
 * must pass player values as bound parameters, never inside the query text.
 * Vars:     GITHUB_OWNER, GITHUB_REPO, GITHUB_PATH, GITHUB_BRANCH (see wrangler.toml)
 */

import { DIFFICULTIES, PLANET_PATTERN, addEntry, boardKey, emptyBoard, isDuplicate, normalizeBoard, planetEntries, qualifies, validateScore } from "./board.js";
import { handleCloud } from "./cloud.js";
import { handleAuth } from "./accounts.js";
import { corsHeaders } from "./cors.js";
import { privacyPage } from "./privacy.js";
import { handleSuggestionPost, suggestionStatus } from "./suggestions.js";
import { parseJson, readBody } from "./safety.js";

export { SaveVault } from "./cloud.js";
export { AccountVault } from "./accounts.js";

const MAX_BODY_BYTES = 4000;
const RATE_LIMIT_WINDOW_MS = 60_000;
/** Requests of any kind per IP per minute. */
const RATE_LIMIT_MAX = 30;
/** Scores sent per IP per minute (a game takes far longer than this). */
const SUBMIT_LIMIT_MAX = 3;

function jsonResponse(request, body, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders(request), "Content-Type": "application/json; charset=utf-8", "Cache-Control": "no-store" },
  });
}

function settings(env) {
  return {
    owner: env.GITHUB_OWNER || "Zephino",
    repo: env.GITHUB_REPO || "Lastborn_Colony",
    path: env.GITHUB_PATH || "leaderboard.json",
    branch: env.GITHUB_BRANCH || "data",
  };
}

/**
 * True while `ip` is under `max` requests this minute for this `kind`.
 * Each check writes to KV, and Cloudflare's free plan allows about 1,000 KV
 * writes a day, so only sending (POST) is counted, never reading the board.
 * If KV can't be used (for example the daily write limit is reached), the
 * check lets the request through rather than breaking score submission.
 */
async function underLimit(env, kind, ip, max) {
  if (!env.LEADERBOARD_KV) return true;
  // Storage note: KV keys and values only, no SQL. Any future SQL must use bound parameters.
  const key = `rl:${kind}:${ip}`;
  const now = Date.now();
  let data = { t: now, n: 0 };
  try {
    const existing = await env.LEADERBOARD_KV.get(key, { type: "json" });
    if (existing && typeof existing === "object") data = existing;
  } catch (_) {}
  if (now - (data.t || 0) > RATE_LIMIT_WINDOW_MS) data = { t: now, n: 0 };
  data.n = (data.n || 0) + 1;
  try {
    await env.LEADERBOARD_KV.put(key, JSON.stringify(data), { expirationTtl: 120 });
  } catch (err) {
    console.log("rate limit write failed:", String(err));
  }
  return data.n <= max;
}

/** The board from KV; only if KV is empty and a GitHub token is set, the copy on GitHub. */
async function loadBoard(env) {
  if (env.LEADERBOARD_KV) {
    const cached = await env.LEADERBOARD_KV.get("board", { type: "json" });
    if (cached) return normalizeBoard(cached);
  }
  if (!env.GITHUB_TOKEN) return emptyBoard();
  const s = settings(env);
  const url = `https://raw.githubusercontent.com/${s.owner}/${s.repo}/${s.branch}/${s.path}`;
  try {
    const res = await fetch(url, { headers: { Accept: "application/json", Authorization: `Bearer ${env.GITHUB_TOKEN}` } });
    if (!res.ok) return emptyBoard();
    return normalizeBoard(await res.json());
  } catch (err) {
    console.log("loadBoard: GitHub copy unreadable:", String(err));
    return emptyBoard();
  }
}

async function saveBoard(env, board) {
  if (env.LEADERBOARD_KV) {
    try {
      await env.LEADERBOARD_KV.put("board", JSON.stringify(board));
    } catch (err) {
      console.log("board KV write failed:", String(err));
    }
  }
  try {
    await commitToGitHub(env, board);
  } catch (err) {
    console.log("GitHub commit failed:", String(err));
  }
}

/** Writes leaderboard.json on the data branch (never any other branch). Skipped without GITHUB_TOKEN. */
async function commitToGitHub(env, board) {
  if (!env.GITHUB_TOKEN) return;
  const s = settings(env);
  const api = `https://api.github.com/repos/${s.owner}/${s.repo}/contents/${s.path}`;
  const headers = {
    Authorization: `Bearer ${env.GITHUB_TOKEN}`,
    Accept: "application/vnd.github+json",
    "User-Agent": "lastborn-colony-leaderboard-worker",
    "Content-Type": "application/json",
  };
  let sha;
  const getRes = await fetch(`${api}?ref=${encodeURIComponent(s.branch)}`, { headers });
  if (getRes.ok) sha = (await getRes.json()).sha;
  const text = JSON.stringify(board, null, "\t") + "\n";
  const content = btoa(unescape(encodeURIComponent(text)));
  const putRes = await fetch(api, {
    method: "PUT",
    headers,
    body: JSON.stringify({ message: "Leaderboard update", content, branch: s.branch, sha }),
  });
  if (!putRes.ok) console.log("GitHub commit failed:", putRes.status, await putRes.text());
}

async function handleGet(request, env, url) {
  const board = await loadBoard(env);
  const planet = url.searchParams.get("planet");
  if (planet === null || planet === "") return jsonResponse(request, { updated: board.updated, planets: board.planets });
  if (!PLANET_PATTERN.test(planet)) return jsonResponse(request, { error: "invalid planet" }, 400);
  const difficulty = url.searchParams.get("difficulty") || "normal";
  if (!DIFFICULTIES.includes(difficulty)) return jsonResponse(request, { error: "invalid difficulty" }, 400);
  const key = boardKey({ planet, difficulty });
  return jsonResponse(request, { planet, difficulty, updated: board.updated, entries: planetEntries(board, key) });
}

async function handlePost(request, env, ip) {
  const read = await readBody(request, MAX_BODY_BYTES);
  if (read.tooLarge) return jsonResponse(request, { error: "payload too large" }, 413);
  const body = parseJson(read.text);
  if (body === undefined) return jsonResponse(request, { error: "invalid json" }, 400);
  const checked = validateScore(body);
  if (checked.error) return jsonResponse(request, { error: checked.error }, 400);
  if (!(await underLimit(env, "post", ip, SUBMIT_LIMIT_MAX))) {
    return jsonResponse(request, { error: "rate limited" }, 429);
  }
  const entry = checked.entry;
  const board = await loadBoard(env);
  const key = boardKey(entry);
  if (isDuplicate(planetEntries(board, key), entry) || !qualifies(board, entry)) {
    return jsonResponse(request, { accepted: false, rank: 0, planet: entry.planet, difficulty: entry.difficulty, entries: planetEntries(board, key) });
  }
  const { board: updated, rank } = addEntry(board, entry, new Date().toISOString());
  await saveBoard(env, updated);
  return jsonResponse(request, { accepted: true, rank, planet: entry.planet, difficulty: entry.difficulty, entries: planetEntries(updated, key) });
}

export default {
  async fetch(request, env) {
    try {
      const url = new URL(request.url);
      // Cloud saves and sign-in answer their own preflight (no KV use).
      if (url.pathname === "/cloud/save") return await handleCloud(request, env);
      if (url.pathname.startsWith("/auth/")) return await handleAuth(request, env);
      if (url.pathname === "/privacy") return privacyPage();
      if (request.method === "OPTIONS") {
        return new Response(null, { status: 204, headers: corsHeaders(request) });
      }
      // Set by Cloudflare itself; cut short so it can't make an oversized KV key.
      const ip = (request.headers.get("CF-Connecting-IP") || "unknown").slice(0, 64);
      if (url.pathname === "/suggestions") {
        if (request.method === "GET") return suggestionStatus(request, env);
        if (request.method === "POST") return await handleSuggestionPost(request, env, ip);
        return jsonResponse(request, { error: "method not allowed" }, 405);
      }
      if (url.pathname !== "/leaderboard" && url.pathname !== "/") {
        return jsonResponse(request, { error: "not found" }, 404);
      }
      if (request.method === "GET") return await handleGet(request, env, url);
      if (request.method === "POST") {
        // Only sending is rate limited: reading the board writes nothing to KV.
        if (!(await underLimit(env, "any", ip, RATE_LIMIT_MAX))) {
          return jsonResponse(request, { error: "rate limited" }, 429);
        }
        return await handlePost(request, env, ip);
      }
      return jsonResponse(request, { error: "method not allowed" }, 405);
    } catch (err) {
      console.log("worker error:", String(err && err.stack ? err.stack : err));
      return jsonResponse(request, { error: "server error" }, 500);
    }
  },
};
