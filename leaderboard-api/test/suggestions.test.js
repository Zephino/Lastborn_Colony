import { test } from "node:test";
import assert from "node:assert/strict";
import worker from "../src/index.js";
import {
  DAILY_GLOBAL_LIMIT,
  DAILY_IP_LIMIT,
  MAX_BODY_BYTES,
  MAX_DESCRIPTION,
  MAX_TITLE,
  SUGGESTION_CATEGORIES,
  handleSuggestionPost,
  issueFor,
  validateSuggestion,
} from "../src/suggestions.js";
import { fakeGitHub, payload, suggestEnv, suggestRequest } from "./helpers.js";


test("the categories are Lastborn's", () => {
  assert.deepEqual([...SUGGESTION_CATEGORIES], ["Gameplay", "Balance", "Interface", "Bug", "Online", "Other"]);
});

test("a normal suggestion passes; bad category, lengths, honeypot and links are refused", () => {
  assert.equal(validateSuggestion(payload).error, undefined);
  assert.equal(validateSuggestion({ ...payload, category: "admin" }).error, "invalid category");
  assert.equal(validateSuggestion({ ...payload, category: "balance" }).error, "invalid category", "exact match only");
  assert.ok(validateSuggestion({ ...payload, title: "hi" }).error);
  assert.ok(validateSuggestion({ ...payload, title: "x".repeat(MAX_TITLE + 1) }).error);
  assert.equal(validateSuggestion({ ...payload, title: "x".repeat(MAX_TITLE) }).error, undefined);
  assert.ok(validateSuggestion({ ...payload, description: "short" }).error);
  assert.ok(validateSuggestion({ ...payload, description: "y".repeat(MAX_DESCRIPTION + 1) }).error);
  assert.equal(validateSuggestion({ ...payload, description: "y".repeat(MAX_DESCRIPTION) }).error, undefined);
  assert.ok(validateSuggestion({ ...payload, website: "spam.example" }).error);
  assert.ok(validateSuggestion({ ...payload, website: null }).error);
  assert.ok(validateSuggestion({ ...payload, description: "a".repeat(30) + " http://a http://b www.c" }).error);
  const noWebsite = { ...payload };
  delete noWebsite.website;
  assert.equal(validateSuggestion(noWebsite).error, undefined, "an absent honeypot is fine");
});

test("lengths count characters, not UTF-16 units (emoji count once, like Godot)", () => {
  assert.equal(validateSuggestion({ ...payload, title: "\u{1F680}".repeat(MAX_TITLE) }).error, undefined);
});

test("titles become one line; descriptions keep at most one blank line", () => {
  const c = validateSuggestion({ ...payload, title: "Two\nline\r\n  title", description: "First line here\n\n\n\n\nsecond line is here too" });
  assert.equal(c.title, "Two line title");
  assert.equal(c.description, "First line here\n\nsecond line is here too");
});

test("client details are coarse and from fixed lists only", () => {
  const c = validateSuggestion({
    ...payload,
    client: { game_version: "1.0; rm -rf", runtime: "Native", device_type: "iPhone 15 Pro", platform: "Windows", browser: "Mozilla/5.0 (X11)", ip: "9.9.9.9" },
  }).client;
  assert.deepEqual(c, { game_version: "Unknown", runtime: "Native", device_type: "Unknown", platform: "Windows", browser: "Unknown" });
  assert.equal(validateSuggestion({ ...payload, client: "Chrome" }).client, null);
  assert.equal(validateSuggestion({ ...payload, client: [1] }).client, null);
});

test("GET /suggestions says whether suggestions are accepted", async () => {
  const off = await worker.fetch(new Request("https://example.workers.dev/suggestions"), { LEADERBOARD_KV: suggestEnv().LEADERBOARD_KV });
  assert.equal(off.status, 200);
  assert.deepEqual(await off.json(), { accepting: false });
  const on = await worker.fetch(new Request("https://example.workers.dev/suggestions"), suggestEnv());
  assert.deepEqual(await on.json(), { accepting: true });
});

test("without GITHUB_TOKEN a suggestion is refused clearly (503), not crashed on", async () => {
  const res = await worker.fetch(suggestRequest(), { LEADERBOARD_KV: suggestEnv().LEADERBOARD_KV });
  assert.equal(res.status, 503);
  assert.match((await res.json()).error, /not set up/);
  assert.equal((await handleSuggestionPost(suggestRequest(), {}, "1.2.3.4")).status, 503);
});

test("creates exactly one issue in Zephino/Lastborn_Colony and confirms it", async () => {
  const gh = fakeGitHub();
  const env = suggestEnv();
  const res = await handleSuggestionPost(suggestRequest(), env, "1.2.3.4", gh);
  assert.equal(res.status, 201);
  assert.deepEqual(await res.json(), { accepted: true, issue_number: 42 });
  assert.equal(gh.calls.length, 1);
  assert.equal(gh.calls[0].url, "https://api.github.com/repos/Zephino/Lastborn_Colony/issues");
  assert.equal(gh.calls[0].init.headers.Authorization, "Bearer test-token");
  const issue = gh.calls[0].issue;
  assert.equal(issue.title, "[Player suggestion] Vent Taps feel too strong");
  assert.match(issue.body, /\*\*Category:\*\* Balance/);
  assert.match(issue.body, /single Vent Tap/);
  assert.match(issue.body, /Device: Phone/);
  assert.equal(issue.body.includes("1.2.3.4"), false, "no IP address in the issue");
  assert.equal(env._data.size, 2, "one per-address counter and one daily counter");
  for (const key of env._data.keys()) assert.equal(key.includes("1.2.3.4"), false, "KV never holds the raw address");
});

test("3 a day per address and 40 a day overall", async () => {
  const env = suggestEnv();
  const gh = fakeGitHub();
  const statuses = [];
  for (let i = 0; i < DAILY_IP_LIMIT + 1; i++) statuses.push((await handleSuggestionPost(suggestRequest(), env, "7.7.7.7", gh)).status);
  assert.deepEqual(statuses, [201, 201, 201, 429]);
  assert.equal((await handleSuggestionPost(suggestRequest(), env, "8.8.8.8", gh)).status, 201, "another address may still send");
  const day = new Date().toISOString().slice(0, 10);
  await env.LEADERBOARD_KV.put("suggest:global:" + day, String(DAILY_GLOBAL_LIMIT));
  assert.equal((await handleSuggestionPost(suggestRequest(), env, "9.9.9.9", gh)).status, 429);
  assert.equal(gh.calls.length, 4);
});

test("a GitHub failure is never reported as success, and leaks nothing", async () => {
  const cases = [
    [401, /invalid or expired/],
    [403, /Issues: Read and write/],
    [404, /repository/],
    [422, /refused/],
    [500, /\(500\)/],
  ];
  for (const [status, why] of cases) {
    const env = suggestEnv();
    const res = await handleSuggestionPost(suggestRequest(), env, "1.2.3.4", fakeGitHub(status));
    assert.equal(res.status, 502);
    const text = await res.text();
    assert.match(JSON.parse(text).error, why);
    assert.equal(text.includes("do-not-repeat") || text.includes("test-token"), false);
    assert.equal(env._data.size, 0, "a failed suggestion doesn't use up the daily allowance");
  }
  const down = await handleSuggestionPost(suggestRequest(), suggestEnv(), "1.2.3.4", async () => {
    throw new Error("network down");
  });
  assert.equal(down.status, 502);
});

test("the issue body escapes Markdown, HTML, mentions, issue links and URLs", () => {
  const checked = validateSuggestion({
    ...payload,
    title: "@Zephino see #12 <b>now</b>",
    description: [
      "# Heading",
      "[click](https://evil.example) ![img](x.png)",
      "<script>alert(1)</script> <img src=x onerror=alert(1)>",
      "@everyone and @Zephino, see #1 and GH-2 and owner/repo#3",
      "> fake quote",
      "| a | b |",
      "Setext heading",
      "===",
      "$x^2$ and `code` and *bold* and ~~strike~~",
      "visit www.evil.example",
    ].join("\n"),
  });
  assert.equal(checked.error, undefined);
  const { title, body } = issueFor(checked);
  assert.equal(title.includes("@"), false);
  assert.equal(title.includes("#"), false);
  const quoted = body.split("**Suggestion:**")[1].split("**Game details")[0];
  for (const line of quoted.trim().split("\n")) assert.ok(line.startsWith("> "), `every player line is quoted: ${line}`);
  assert.equal(/<[a-z]/i.test(body), false, "no raw HTML tags");
  assert.equal(body.includes("@"), false, "no mentions");
  assert.equal(/#\d/.test(body.replace(/&#\d+;/g, "")), false, "no issue links (HTML entities like &#47; aside)");
  assert.equal(/GH-\d/i.test(body), false);
  assert.equal(/\]\(/.test(body.replace(/\\\]\\\(/g, "")), false, "no Markdown links");
  assert.equal(body.includes("https://"), false, "URLs aren't clickable");
  assert.equal(/www\.evil/.test(body), false);
  assert.match(quoted, /> \\=\\=\\=/, "setext underline is escaped");
  assert.match(quoted, /> \uFF03 Heading/, "heading marker is neutralized");
});

test("bodies over the byte limit are refused before they are read", async () => {
  const big = { ...payload, description: "z".repeat(MAX_BODY_BYTES) };
  const res = await handleSuggestionPost(suggestRequest(big), suggestEnv(), "1.2.3.4", fakeGitHub());
  assert.equal(res.status, 413);
});

test("CORS on /suggestions allows only the web game and localhost", async () => {
  const from = (origin) =>
    worker.fetch(new Request("https://example.workers.dev/suggestions", { headers: { Origin: origin } }), suggestEnv());
  assert.equal((await from("https://zephino.github.io")).headers.get("Access-Control-Allow-Origin"), "https://zephino.github.io");
  assert.equal((await from("http://localhost:8060")).headers.get("Access-Control-Allow-Origin"), "http://localhost:8060");
  assert.equal((await from("https://evil.example")).headers.get("Access-Control-Allow-Origin"), null);
  assert.equal((await from("https://zephino.github.io.evil.example")).headers.get("Access-Control-Allow-Origin"), null);
  const pre = await worker.fetch(
    new Request("https://example.workers.dev/suggestions", { method: "OPTIONS", headers: { Origin: "https://evil.example" } }),
    suggestEnv(),
  );
  assert.equal(pre.status, 204);
  assert.equal(pre.headers.get("Access-Control-Allow-Origin"), null);
  const del = await worker.fetch(new Request("https://example.workers.dev/suggestions", { method: "DELETE" }), suggestEnv());
  assert.equal(del.status, 405);
});
