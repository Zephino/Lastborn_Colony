/**
 * Hostile input against every route: SQL-looking text, HTML/script, BBCode,
 * Markdown, control / bidirectional / zero-width characters, over-long text,
 * wrong types, huge bodies and broken JSON. Each must be refused or made
 * harmless; none may crash the Worker (500) or be stored as sent.
 */
import { test } from "node:test";
import assert from "node:assert/strict";
import worker from "../src/index.js";
import { AccountVault } from "../src/accounts.js";
import { SaveVault } from "../src/cloud.js";
import { validateScore } from "../src/board.js";
import { cleanText } from "../src/safety.js";
import { suggestEnv, suggestRequest, fakeGitHub } from "./helpers.js";
import { handleSuggestionPost } from "../src/suggestions.js";

const BASE = "https://example.workers.dev";
const SQL = ["'; DROP TABLE scores; --", "1 OR 1=1", "' OR '1'='1", "admin'--", "1; DELETE FROM saves"];
const MARKUP = ["<script>alert(1)</script>", "<img src=x onerror=alert(1)>", "[color=red]Ari[/color]", "[url=https://evil.example]x[/url]", "**Ari**", "# Ari", "[x](https://evil.example)"];
const INVISIBLE = ["A\u0000ri", "A\u0007ri", "\u202EirA", "A\u2066ri\u2069", "A\u200Bri", "A\u200Dri", "\uFEFFAri", "A\u00ADri", "A\u{E0041}ri"];
const WRONG_TYPES = [null, 42, true, [], ["Ari"], { $ne: 1 }, "64"];

function kvEnv() {
  const store = new Map();
  return {
    store,
    LEADERBOARD_KV: {
      async get(key, opts) {
        if (!store.has(key)) return null;
        return opts?.type === "json" ? JSON.parse(store.get(key)) : store.get(key);
      },
      async put(key, value) {
        store.set(key, value);
      },
    },
  };
}

function score(overrides = {}) {
  return { name: "Ari", colony: "Margin", planet: "brume", ending: "silent", turn: 64, debt_paid: 1200, debt_total: 6000, population: 31, version: "00.01.07", ...overrides };
}

function postScore(body, ip) {
  return new Request(BASE + "/leaderboard", {
    method: "POST",
    headers: { "Content-Type": "application/json", "CF-Connecting-IP": ip },
    body: typeof body === "string" ? body : JSON.stringify(body),
  });
}

/** Everything stored on the board must use only the safe name characters. */
function assertBoardClean(env) {
  const board = env.store.has("board") ? JSON.parse(env.store.get("board")) : { planets: {} };
  for (const rows of Object.values(board.planets)) {
    for (const row of rows) {
      assert.match(row.name, /^[A-Za-z0-9 _-]{1,16}$/);
      assert.match(row.colony, /^[A-Za-z0-9 _-]{1,24}$/);
    }
  }
}

// --- Leaderboard -------------------------------------------------------------

test("leaderboard: SQL-looking names are refused or reduced to plain letters", async () => {
  for (const text of SQL) {
    const r = validateScore(score({ name: text, colony: text }));
    if (r.entry) {
      assert.match(r.entry.name, /^[A-Za-z0-9 _-]+$/, text);
      assert.match(r.entry.colony, /^[A-Za-z0-9 _-]+$/, text);
    } else {
      assert.match(r.error, /invalid (name|colony)/);
    }
  }
  assert.equal(validateScore(score({ name: "'; DROP TABLE scores; --" })).error, "invalid name");
  assert.equal(validateScore(score({ name: "1 OR 1=1" })).entry.name, "1 OR 11");
});

test("leaderboard: HTML, BBCode, Markdown and invisible characters never reach the board", async () => {
  for (const text of [...MARKUP, ...INVISIBLE]) {
    const r = validateScore(score({ name: text }));
    if (r.entry) assert.match(r.entry.name, /^[A-Za-z0-9 _-]+$/, JSON.stringify(text));
  }
  assert.equal(validateScore(score({ name: "<script>alert(1)</script>" })).error, "invalid name");
  assert.equal(validateScore(score({ name: "[color=red]Ari[/color]" })).entry.name, "colorredAricolor");
  assert.equal(validateScore(score({ name: "\u202EirA" })).entry.name, "irA");
  assert.equal(validateScore(score({ name: "A\u200Bri" })).entry.name, "Ari");
  assert.equal(validateScore(score({ name: "A\u0000ri" })).error, "invalid name", "control characters are refused");
  assert.equal(validateScore(score({ name: "\u200B\u200B" })).error, "invalid name", "nothing visible left");
});

test("leaderboard: over-long text is cut or refused", () => {
  assert.equal(validateScore(score({ name: "A".repeat(5000) })).entry.name.length, 16);
  assert.equal(validateScore(score({ colony: "B".repeat(5000) })).entry.colony.length, 24);
  assert.equal(validateScore(score({ planet: "a".repeat(25) })).error, "invalid planet");
  assert.equal(validateScore(score({ version: "00.01.07" + "0".repeat(100) })).error, "invalid version");
});

test("leaderboard: wrong types are refused (numbers as strings, arrays, objects, null)", () => {
  for (const bad of WRONG_TYPES) {
    for (const field of ["turn", "debt_paid", "debt_total", "population"]) {
      if (bad === 42) continue; // a whole number is the right type for these
      assert.ok(validateScore(score({ [field]: bad })).error, `${field} = ${JSON.stringify(bad)}`);
    }
    for (const field of ["name", "colony", "planet", "ending", "version"]) {
      if (bad === "64") continue; // a string is the right type for these
      assert.ok(validateScore(score({ [field]: bad })).error, `${field} = ${JSON.stringify(bad)}`);
    }
  }
  assert.ok(validateScore(score({ turn: 1.5 })).error);
  assert.ok(validateScore(score({ turn: -1 })).error);
  assert.ok(validateScore(score({ ending: "free; DROP" })).error);
});

test("leaderboard: hostile requests get 4xx, never 500, and the board stays clean", async () => {
  const env = kvEnv();
  let ip = 0;
  const send = async (body) => (await worker.fetch(postScore(body, `10.0.0.${ip++}`), env)).status;
  for (const body of ["{", "not json", "", "null", "[]", "42", '"text"', "true", JSON.stringify([score()])]) {
    assert.equal(await send(body), 400, `body ${JSON.stringify(body).slice(0, 30)}`);
  }
  assert.equal(await send(JSON.stringify(score({ name: "x".repeat(10_000) }))), 413);
  assert.equal(await send("{" + " ".repeat(5000) + "}"), 413);
  // Multi-byte text is measured in bytes, not characters.
  assert.equal(await send(JSON.stringify(score({ colony: "\u{1F680}".repeat(1100) }))), 413);
  for (const text of [...SQL, ...MARKUP, ...INVISIBLE]) {
    const status = await send(score({ name: text, turn: 100 + ip }));
    assert.ok(status === 200 || status === 400, `${JSON.stringify(text)} \u2192 ${status}`);
  }
  assertBoardClean(env);
  for (const query of ["?planet=' OR 1=1 --", "?planet=<script>", "?planet=brume%00", "?planet=" + "a".repeat(300)]) {
    const res = await worker.fetch(new Request(BASE + "/leaderboard" + query), env);
    assert.equal(res.status, 400, query);
    assert.equal((await res.text()).includes("<script>"), false, "input is not echoed back");
  }
  assert.equal((await worker.fetch(new Request(BASE + "/leaderboard", { method: "DELETE" }), env)).status, 405);
});

// --- Sign-in -----------------------------------------------------------------

function fakeAccounts() {
  const vaults = new Map();
  return {
    vaults,
    idFromName: (name) => name,
    get(id) {
      if (!vaults.has(id)) {
        const data = new Map();
        vaults.set(id, { data, vault: new AccountVault({ storage: { get: async (k) => data.get(k), put: async (k, v) => data.set(k, v), deleteAll: async () => data.clear() } }) });
      }
      const { vault } = vaults.get(id);
      return { fetch: (url, init) => vault.fetch(new Request(url, init)) };
    },
  };
}

test("sign-in: hostile /auth/start bodies start a fresh sign-in or are refused; nothing crashes", async () => {
  const env = { ACCOUNTS: fakeAccounts(), GOOGLE_CLIENT_ID: "id", GOOGLE_CLIENT_SECRET: "secret" };
  const start = (body) => worker.fetch(new Request(BASE + "/auth/start", { method: "POST", body }), env);
  const bodies = ["{", "null", "[]", "42", '"x"', JSON.stringify({ code: SQL[0] }), JSON.stringify({ code: { $ne: 1 } }), JSON.stringify({ code: ["ABCDEFGHJK23"] }), JSON.stringify({ code: "<script>" }), JSON.stringify({ code: "ABCD\u200BEFGHJK23" })];
  for (const body of bodies) {
    const res = await start(body);
    assert.equal(res.status, 200, body);
    assert.match((await res.json()).login, /^[0-9a-f]{32}$/);
  }
  for (const [name, { data }] of env.ACCOUNTS.vaults) {
    if (name.startsWith("login:")) assert.equal(data.get("value").device_code, "", "a hostile code is stored as no code");
  }
  assert.equal((await start("x".repeat(5000))).status, 413);
});

test("sign-in: hostile login ids and Google parameters are refused without echoing them", async () => {
  const env = { ACCOUNTS: fakeAccounts(), GOOGLE_CLIENT_ID: "id", GOOGLE_CLIENT_SECRET: "secret" };
  for (const login of [SQL[1], "<script>alert(1)</script>", "../../etc", "A".repeat(5000), "0".repeat(31) + "\u0000"]) {
    const q = encodeURIComponent(login);
    const poll = await worker.fetch(new Request(`${BASE}/auth/poll?login=${q}`), env);
    assert.equal(poll.status, 400);
    for (const path of [`/auth/google?login=${q}`, `/auth/callback?state=${q}&code=${q}`]) {
      const res = await worker.fetch(new Request(BASE + path), env);
      assert.equal(res.status, 400, path);
      assert.equal((await res.text()).includes("<script>alert"), false, "the page never shows the input");
    }
  }
});

// --- Cloud save --------------------------------------------------------------

function fakeVaults() {
  const vaults = new Map();
  return {
    vaults,
    idFromName: (name) => name,
    get(id) {
      if (!vaults.has(id)) {
        const data = new Map();
        const storage = {
          get: async (k) => data.get(k),
          put: async (entries, value) => {
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

test("cloud: hostile codes are refused (401) before any storage is touched", async () => {
  const env = { SAVE_VAULT: fakeVaults() };
  // (Headers can't carry characters above U+00FF or NUL at all, so those never arrive.)
  for (const code of [...SQL, ...MARKUP, "ABCD\u00ADEFGH-JK23", "ABCDEFGHJK2\u0007", "A".repeat(5000), "null", "[]", "ABCDEFGHJK23ABCDEFGHJK23"]) {
    const res = await worker.fetch(new Request(BASE + "/cloud/save", { headers: { Authorization: `Bearer ${code}` } }), env);
    assert.equal(res.status, 401, code);
  }
  assert.equal(env.SAVE_VAULT.vaults.size, 0);
});

test("cloud: broken, wrong-typed and huge saves are refused; odd text inside a real save stays inert", async () => {
  const env = { SAVE_VAULT: fakeVaults() };
  const put = (body) => worker.fetch(new Request(BASE + "/cloud/save", { method: "PUT", headers: { Authorization: "Bearer ABCDEFGHJK23" }, body }), env);
  for (const body of ["{", "", "null", "[]", "42", '"save"', JSON.stringify({ version: "1" }), JSON.stringify({ version: null }), JSON.stringify({ version: [1] }), JSON.stringify({ turn: 5 })]) {
    assert.equal((await put(body)).status, 400, body);
  }
  assert.equal((await put(JSON.stringify({ version: 1, pad: "x".repeat(1_000_001) }))).status, 413);
  assert.equal((await put(JSON.stringify({ version: 1, pad: "\u00E9".repeat(600_000) }))).status, 413, "measured in bytes");
  // The save is the player's own data, kept as opaque text, returned only to the same code,
  // and always served as JSON (never as a page), so markup inside it can't run anywhere.
  const odd = JSON.stringify({ version: 1, colony_name: "<script>alert(1)</script>'; DROP TABLE saves; --" });
  assert.equal((await put(odd)).status, 200);
  const back = await worker.fetch(new Request(BASE + "/cloud/save", { headers: { Authorization: "Bearer ABCDEFGHJK23" } }), env);
  assert.match(back.headers.get("Content-Type"), /^application\/json/);
  assert.equal((await back.json()).save, odd);
});

// --- Suggestions ---------------------------------------------------------------

test("suggestions: wrong types, broken JSON and huge bodies are refused", async () => {
  const good = { category: "Bug", title: "The map flickers", description: "When I zoom out fast the map flickers for a moment.", website: "" };
  const gh = fakeGitHub();
  let n = 0;
  const send = async (body) => (await handleSuggestionPost(suggestRequest(body), suggestEnv(), `10.1.0.${n++}`, gh)).status;
  for (const body of ["{", "", "null", "[]", "42", '"x"', "true"]) assert.equal(await send(body), 400, body);
  for (const bad of WRONG_TYPES) {
    for (const field of ["category", "title", "description"]) {
      if (bad === "64" && field !== "category") continue;
      assert.equal(await send({ ...good, [field]: bad }), 400, `${field} = ${JSON.stringify(bad)}`);
    }
    if (bad !== null) assert.equal(await send({ ...good, website: bad }), 400, `honeypot = ${JSON.stringify(bad)}`);
  }
  assert.equal(await send({ ...good, category: SQL[0] }), 400);
  assert.equal(await send({ ...good, category: "<script>" }), 400);
  assert.equal(await send({ ...good, title: "x".repeat(101) }), 400);
  assert.equal(await send({ ...good, description: "x".repeat(2001) }), 400);
  assert.equal(await send({ ...good, description: "x".repeat(20_000) }), 413);
  assert.equal(await send({ ...good, title: "\u200B\u200B\u200B\u200B\u200Bab" }), 400, "invisible characters don't count toward the minimum");
  assert.equal(gh.calls.length, 0, "nothing hostile reached GitHub");
});

test("suggestions: SQL, HTML, BBCode, Markdown and invisible characters arrive at GitHub inert", async () => {
  const gh = fakeGitHub();
  let n = 0;
  for (const text of [...SQL, ...MARKUP, ...INVISIBLE]) {
    const body = { category: "Other", title: `Idea ${text} here`, description: `Please read: ${text} and that is all I wanted to say.`, website: "" };
    const res = await handleSuggestionPost(suggestRequest(body), suggestEnv(), `10.2.0.${n++}`, gh);
    assert.equal(res.status, 201, JSON.stringify(text));
  }
  for (const { issue } of gh.calls) {
    const all = issue.title + "\n" + issue.body;
    assert.equal(/[\u0000-\u0008\u000B-\u001F\u007F\u00AD\u200B-\u200F\u202A-\u202E\u2066-\u2069\uFEFF]|[\u{E0000}-\u{E007F}]/u.test(all), false, "no invisible characters");
    assert.equal(/<[a-z/]/i.test(issue.body), false, "no HTML tags in the body");
    assert.equal(/(^|[^\\])\[(?!Player suggestion\])/.test(issue.body), false, "every [ in the body is escaped");
    assert.equal(/^> .*[^\\]\*\*/m.test(issue.body), false, "no bold in player text");
    assert.equal(/^#/m.test(issue.body), false, "no headings");
  }
  assert.equal(cleanText("A\u202Eb\u200Bc\u0000d\u2066e"), "Abcde");
});
