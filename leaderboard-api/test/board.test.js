import { test } from "node:test";
import assert from "node:assert/strict";
import worker from "../src/index.js";
import {
  MAX_ENTRIES,
  MAX_PLANETS,
  addEntry,
  emptyBoard,
  normalizeBoard,
  qualifies,
  sanitizeName,
  validateScore,
} from "../src/board.js";

function score(overrides = {}) {
  return {
    name: "Ari",
    colony: "Margin",
    planet: "brume",
    ending: "receivership",
    turn: 64,
    debt_paid: 1200,
    debt_total: 6000,
    population: 31,
    version: "00.01.04",
    ...overrides,
  };
}

const entry = (o) => validateScore(score(o)).entry;

test("a normal score is accepted as is", () => {
  const { entry: e, error } = validateScore(score());
  assert.equal(error, undefined);
  assert.deepEqual(e, score());
});

test("names keep only safe characters and are cut to size", () => {
  assert.equal(sanitizeName("  Zeph  ino!!  "), "Zeph ino");
  assert.equal(sanitizeName("ABCDEFGHIJKLMNOPQRST"), "ABCDEFGHIJKLMNOP");
  assert.equal(entry({ colony: "New Hope Settlement Number Nine" }).colony, "New Hope Settlement Numb");
  assert.equal(validateScore(score({ name: "<script>" })).error, "invalid name");
  assert.equal(validateScore(score({ name: "!!!" })).error, "invalid name");
  assert.equal(validateScore(score({ colony: "x'; DROP" })).error, "invalid colony");
  assert.equal(validateScore(score({ colony: "" })).error, "invalid colony");
});

test("impossible numbers and unknown values are refused", () => {
  assert.equal(validateScore(score({ turn: 0 })).error, "invalid turn");
  assert.equal(validateScore(score({ turn: 5001 })).error, "invalid turn");
  assert.equal(validateScore(score({ turn: 12.5 })).error, "invalid turn");
  assert.equal(validateScore(score({ turn: "" })).error, "invalid turn");
  assert.equal(validateScore(score({ debt_paid: 6001 })).error, "invalid debt");
  assert.equal(validateScore(score({ debt_paid: -1 })).error, "invalid debt");
  assert.equal(validateScore(score({ debt_total: 1_000_001, debt_paid: 0 })).error, "invalid debt");
  assert.equal(validateScore(score({ ending: "free", debt_paid: 5999 })).error, "invalid debt", "free means all paid");
  assert.equal(validateScore(score({ population: 100_001 })).error, "invalid population");
  assert.equal(validateScore(score({ population: -3 })).error, "invalid population");
  assert.equal(validateScore(score({ ending: "won" })).error, "invalid ending");
  assert.equal(validateScore(score({ planet: "../main" })).error, "invalid planet");
  assert.equal(validateScore(score({ planet: "" })).error, "invalid planet");
  assert.equal(validateScore(score({ version: "1" })).error, "invalid version");
  assert.equal(validateScore([1, 2]).error, "invalid json");
});

test("free colonies rank first by fewest turns, then marks paid, then turns survived", () => {
  let board = emptyBoard();
  const add = (o, date) => (board = addEntry(board, entry(o), date).board);
  add({ name: "A", ending: "silent", debt_paid: 500, turn: 90 }, "2026-11-01T00:00:00Z");
  add({ name: "B", ending: "free", debt_paid: 6000, turn: 120 }, "2026-11-01T00:00:01Z");
  add({ name: "C", ending: "free", debt_paid: 6000, turn: 95 }, "2026-11-01T00:00:02Z");
  add({ name: "D", ending: "receivership", debt_paid: 2000, turn: 70 }, "2026-11-01T00:00:03Z");
  add({ name: "E", ending: "retired", debt_paid: 2000, turn: 80 }, "2026-11-01T00:00:04Z");
  add({ name: "F", ending: "receivership", debt_paid: 2000, turn: 80 }, "2026-11-01T00:00:05Z");
  assert.deepEqual(board.planets.brume.map((e) => e.name), ["C", "B", "E", "F", "D", "A"]);
});

test("each planet has its own board of the best 100", () => {
  let board = emptyBoard();
  for (let i = 1; i <= MAX_ENTRIES; i++) {
    board = addEntry(board, entry({ name: `P${i}`, debt_paid: 100 + i }), "2026-11-01T00:00:00Z").board;
  }
  assert.equal(qualifies(board, entry({ debt_paid: 50 })), false);
  assert.equal(qualifies(board, entry({ debt_paid: 5000 })), true);
  assert.equal(qualifies(board, entry({ debt_paid: 50, planet: "cinder" })), true, "another planet starts empty");
  const { board: more, rank } = addEntry(board, entry({ name: "Top", ending: "free", debt_paid: 6000 }), "2026-11-01T00:00:09Z");
  assert.equal(rank, 1);
  assert.equal(more.planets.brume.length, MAX_ENTRIES);
});

test("there's a limit on how many planets can have a board", () => {
  let board = emptyBoard();
  for (let i = 0; i < MAX_PLANETS; i++) board = addEntry(board, entry({ planet: `p${i}` }), "2026-11-01T00:00:00Z").board;
  assert.equal(qualifies(board, entry({ planet: "one_too_many" })), false);
  assert.equal(qualifies(board, entry({ planet: "p0", debt_paid: 5000 })), true);
});

test("hand-edited junk in the stored file is dropped", () => {
  const board = normalizeBoard({
    planets: {
      brume: [score({ date: "2026-10-28T00:00:00Z" }), { name: "x", turn: "lots" }, 7, score({ planet: "cinder" })],
      "Bad Planet": [score({ planet: "Bad Planet" })],
    },
  });
  assert.deepEqual(Object.keys(board.planets), ["brume"]);
  assert.equal(board.planets.brume.length, 1);
  assert.deepEqual(normalizeBoard(null).planets, {});
});

function fakeEnv() {
  const store = new Map();
  return {
    store,
    LEADERBOARD_KV: {
      async get(key) {
        return store.has(key) ? JSON.parse(store.get(key)) : null;
      },
      async put(key, value) {
        store.set(key, value);
      },
    },
  };
}

function post(body, ip = "1.2.3.4") {
  return new Request("https://example.workers.dev/leaderboard", {
    method: "POST",
    headers: { "Content-Type": "application/json", "CF-Connecting-IP": ip },
    body: JSON.stringify(body),
  });
}

const get = (query = "") => new Request("https://example.workers.dev/leaderboard" + query, { headers: { "CF-Connecting-IP": "5.5.5.5" } });

test("the Worker saves a score from KV alone and refuses a duplicate", async () => {
  const env = fakeEnv();
  const realFetch = globalThis.fetch;
  globalThis.fetch = async () => assert.fail("no GitHub calls without GITHUB_TOKEN");
  try {
    const first = await (await worker.fetch(post(score()), env)).json();
    assert.equal(first.accepted, true);
    assert.equal(first.rank, 1);
    assert.equal(first.planet, "brume");
    assert.match(first.entries[0].date, /^\d{4}-/);
    const again = await (await worker.fetch(post(score()), env)).json();
    assert.equal(again.accepted, false);
    const bad = await worker.fetch(post(score({ population: -1 })), env);
    assert.equal(bad.status, 400);
    const brume = await (await worker.fetch(get("?planet=brume"), env)).json();
    assert.equal(brume.entries.length, 1);
    assert.equal(brume.planet, "brume");
    const empty = await (await worker.fetch(get("?planet=cinder"), env)).json();
    assert.deepEqual(empty.entries, []);
    const all = await (await worker.fetch(get(), env)).json();
    assert.deepEqual(Object.keys(all.planets), ["brume"]);
    assert.equal((await worker.fetch(get("?planet=BAD!"), env)).status, 400);
  } finally {
    globalThis.fetch = realFetch;
  }
});

test("with a GitHub token, the board is also committed to the data branch", async () => {
  const env = { ...fakeEnv(), GITHUB_TOKEN: "t", GITHUB_OWNER: "Zephino", GITHUB_REPO: "Lastborn_Colony", GITHUB_BRANCH: "data", GITHUB_PATH: "leaderboard.json" };
  await env.LEADERBOARD_KV.put("board", JSON.stringify({ planets: {} }));
  const calls = [];
  const realFetch = globalThis.fetch;
  globalThis.fetch = async (url, init = {}) => {
    calls.push([String(url), init.method || "GET"]);
    return init.method === "PUT" ? new Response("{}") : new Response("{}", { status: 404 });
  };
  try {
    assert.equal((await (await worker.fetch(post(score()), env)).json()).accepted, true);
  } finally {
    globalThis.fetch = realFetch;
  }
  assert.ok(calls.some(([u, m]) => m === "PUT" && u === "https://api.github.com/repos/Zephino/Lastborn_Colony/contents/leaderboard.json"));
});

test("one player can't flood the board", async () => {
  const env = fakeEnv();
  const statuses = [];
  for (let i = 0; i < 5; i++) {
    statuses.push((await worker.fetch(post(score({ turn: 100 + i }), "9.9.9.9"), env)).status);
  }
  assert.deepEqual(statuses, [200, 200, 200, 429, 429]);
});

test("reading the board writes nothing to KV (free plan: ~1,000 writes a day)", async () => {
  const env = fakeEnv();
  let writes = 0;
  const put = env.LEADERBOARD_KV.put;
  env.LEADERBOARD_KV.put = async (key, value) => { writes += 1; return put(key, value); };
  for (let i = 0; i < 10; i++) {
    assert.equal((await worker.fetch(get("?planet=brume"), env)).status, 200);
  }
  assert.equal(writes, 0);
});

test("a score is still accepted when KV writes fail (daily limit reached)", async () => {
  const env = fakeEnv();
  env.LEADERBOARD_KV.put = async () => { throw new Error("KV put() limit exceeded for the day."); };
  const res = await worker.fetch(post(score(), "6.6.6.6"), env);
  assert.equal(res.status, 200);
  assert.equal((await res.json()).accepted, true);
});

test("only the web game's own address gets CORS access", async () => {
  const env = fakeEnv();
  const from = (origin) => worker.fetch(new Request("https://example.workers.dev/leaderboard", { method: "OPTIONS", headers: { Origin: origin } }), env);
  assert.equal((await from("https://zephino.github.io")).headers.get("Access-Control-Allow-Origin"), "https://zephino.github.io");
  assert.equal((await from("http://localhost:8060")).headers.get("Access-Control-Allow-Origin"), "http://localhost:8060");
  assert.equal((await from("https://evil.example")).headers.get("Access-Control-Allow-Origin"), null);
  const res = await worker.fetch(new Request("https://example.workers.dev/leaderboard?planet=brume", { headers: { Origin: "https://zephino.github.io" } }), env);
  assert.equal(res.headers.get("Access-Control-Allow-Origin"), "https://zephino.github.io");
});

test("unknown paths answer 404", async () => {
  assert.equal((await worker.fetch(new Request("https://example.workers.dev/lobby"), fakeEnv())).status, 404);
  assert.equal((await worker.fetch(new Request("https://example.workers.dev/suggestions"), fakeEnv())).status, 404);
});
