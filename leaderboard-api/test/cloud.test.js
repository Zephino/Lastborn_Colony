import { test } from "node:test";
import assert from "node:assert/strict";
import worker from "../src/index.js";
import { SaveVault, hashCode, normalizeCode, validateSave, MIN_WRITE_GAP_MS, MAX_SAVE_BYTES } from "../src/cloud.js";

/** A stand-in for Cloudflare's Durable Objects: one SaveVault per name. */
function fakeVaults() {
  const vaults = new Map();
  return {
    names: vaults,
    idFromName(name) {
      return name;
    },
    get(id) {
      if (!vaults.has(id)) {
        const data = new Map();
        const storage = {
          async get(key) {
            return data.get(key);
          },
          async put(entries, value) {
            if (typeof entries === "string") data.set(entries, value);
            else for (const [k, v] of Object.entries(entries)) data.set(k, v);
          },
        };
        vaults.set(id, new SaveVault({ storage }));
      }
      const vault = vaults.get(id);
      return { fetch: (url, init) => vault.fetch(new Request(url, init)) };
    },
  };
}

function request(method, code, body) {
  const headers = { Authorization: `Bearer ${code}` };
  return new Request("https://w.example/cloud/save", { method, headers, body });
}

const CODE = "ABCD-EFGH-JK23";
/** Key order and float precision matter in a Lastborn save. */
const SAVE_TEXT = '{"version":1,"turn":42,"structures":{"2":{"id":"2"},"10":{"id":"10"}},"debt":5123.456789012345}';

test("codes are checked and tidied", () => {
  assert.equal(normalizeCode("abcd efgh jk23"), "ABCDEFGHJK23");
  assert.equal(normalizeCode("ABCD-EFGH-JK2"), "", "too short");
  assert.equal(normalizeCode("ABCD-EFGH-JK2O"), "", "O is not used (looks like 0)");
  assert.equal(normalizeCode(42), "");
});

test("a save must be a Lastborn Colony save object", () => {
  assert.ok(validateSave(SAVE_TEXT).save);
  assert.equal(validateSave("[]").error, "invalid save");
  assert.equal(validateSave("{").error, "invalid json");
  assert.equal(validateSave(JSON.stringify({ turn: 5 })).error, "invalid save");
  assert.equal(validateSave("x".repeat(MAX_SAVE_BYTES + 1)).error, "save too large");
});

test("a save is stored and read back, as the exact same text, with the same code only", async () => {
  const env = { SAVE_VAULT: fakeVaults() };
  let res = await worker.fetch(request("GET", CODE), env);
  assert.deepEqual(await res.json(), { save: null, updated: 0 });
  res = await worker.fetch(request("PUT", CODE, SAVE_TEXT), env);
  assert.equal(res.status, 200);
  res = await worker.fetch(request("GET", "abcdefghjk23"), env);
  const back = await res.json();
  assert.equal(back.save, SAVE_TEXT);
  assert.ok(back.updated > 0);
  res = await worker.fetch(request("GET", "ZZZZ-ZZZZ-ZZZZ"), env);
  assert.equal((await res.json()).save, null, "another code sees nothing");
});

test("the code itself is never used as a storage name", async () => {
  const env = { SAVE_VAULT: fakeVaults() };
  await worker.fetch(request("GET", CODE), env);
  const names = [...env.SAVE_VAULT.names.keys()];
  assert.deepEqual(names, [await hashCode("ABCDEFGHJK23")]);
  assert.ok(!names[0].includes("ABCD"));
});

test("bad codes, bad saves, and rapid writes are refused", async () => {
  const env = { SAVE_VAULT: fakeVaults() };
  assert.equal((await worker.fetch(request("GET", "nope"), env)).status, 401);
  assert.equal((await worker.fetch(request("PUT", CODE, "{}"), env)).status, 400);
  assert.equal((await worker.fetch(request("PUT", CODE, SAVE_TEXT), env)).status, 200);
  assert.equal((await worker.fetch(request("PUT", CODE, SAVE_TEXT), env)).status, 429, `within ${MIN_WRITE_GAP_MS} ms`);
  assert.equal((await worker.fetch(request("POST", CODE, SAVE_TEXT), env)).status, 405);
});

test("cloud saves answer the browser's preflight with Authorization allowed", async () => {
  const res = await worker.fetch(new Request("https://w.example/cloud/save", { method: "OPTIONS", headers: { Origin: "https://zephino.github.io" } }), {});
  assert.equal(res.status, 204);
  assert.match(res.headers.get("Access-Control-Allow-Headers"), /Authorization/);
  assert.match(res.headers.get("Access-Control-Allow-Methods"), /PUT/);
  assert.equal(res.headers.get("Access-Control-Allow-Origin"), "https://zephino.github.io");
});

test("without the Durable Object set up, cloud saves say so", async () => {
  const res = await worker.fetch(request("GET", CODE), {});
  assert.equal(res.status, 503);
});

test("/cloud/play (a one-device-at-a-time rule) isn't served", async () => {
  const res = await worker.fetch(new Request("https://w.example/cloud/play", { method: "POST", headers: { Authorization: `Bearer ${CODE}` } }), { SAVE_VAULT: fakeVaults() });
  assert.equal(res.status, 404);
});
