/**
 * Anonymous player suggestions. Each one becomes a GitHub Issue in
 * Zephino/Lastborn_Colony, titled "[Player suggestion] ...", created with the
 * Worker's GITHUB_TOKEN secret (fine-grained, Issues: Read and write). The
 * player needs no account or email address.
 *
 *   GET  /suggestions   { accepting: true|false } (false until GITHUB_TOKEN is set)
 *   POST /suggestions   { category, title, description, website: "", client: {...} }
 *                       → 201 { accepted: true, issue_number } or { error } with a reason
 *
 * Protections (adapted from Mythriven's suggestions.js):
 *   - category from a fixed list; title 5–100 and description 20–2000
 *     characters; body at most MAX_BODY_BYTES; at most 2 links;
 *   - "website" is a hidden spam trap: the game always sends "", bots fill it;
 *   - 3 suggestions per address per day (the address is only kept as a salted
 *     hash for a day) and 40 per day for everyone, counted in LEADERBOARD_KV.
 *     KV is not atomic, so these caps are best-effort, not exact;
 *   - invisible, control and bidirectional characters are removed, titles are
 *     one line, and all player text is escaped for GitHub Markdown, so it can't
 *     add headings, links, images, HTML, @mentions or #issue links;
 *   - only coarse details are kept (game version, web or app, desktop / phone /
 *     tablet, OS family, browser family), each from a fixed list. Never a raw
 *     user agent, device id or IP address.
 */

import { corsHeaders } from "./cors.js";
import { charCount, cleanText, escapeMarkdown, isPlainObject, markdownQuote, neutralizeTitle, parseJson, readBody } from "./safety.js";

/** Must match Online.suggestion_categories() in scripts/net/online.gd. */
export const SUGGESTION_CATEGORIES = Object.freeze(["Gameplay", "Balance", "Interface", "Bug", "Online", "Other"]);
export const MIN_TITLE = 5;
export const MAX_TITLE = 100;
export const MIN_DESCRIPTION = 20;
export const MAX_DESCRIPTION = 2000;
export const MAX_LINKS = 2;
/** Room for 2,100 characters of 4-byte text plus JSON; anything bigger is refused unread. */
export const MAX_BODY_BYTES = 10_000;
export const DAILY_IP_LIMIT = 3;
export const DAILY_GLOBAL_LIMIT = 40;

const RUNTIMES = ["Web", "Native"];
const DEVICES = ["Desktop", "Phone", "Tablet"];
const PLATFORMS = ["Windows", "macOS", "Linux", "ChromeOS", "Android", "iOS", "FreeBSD"];
const BROWSERS = ["Chrome", "Edge", "Firefox", "Safari", "Opera", "Samsung Internet", "Other", "N/A"];
const VERSION_PATTERN = /^\d{2}\.\d{2}\.\d{2}$/;

function reply(request, body, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders(request), "Content-Type": "application/json; charset=utf-8", "Cache-Control": "no-store" },
  });
}

/** Coarse device details, each from a fixed list ("Unknown" otherwise); null if not sent. */
export function normalizeClient(client) {
  if (!isPlainObject(client)) return null;
  const pick = (value, allowed) => (typeof value === "string" && allowed.includes(value) ? value : "Unknown");
  return {
    game_version: typeof client.game_version === "string" && VERSION_PATTERN.test(client.game_version) ? client.game_version : "Unknown",
    runtime: pick(client.runtime, RUNTIMES),
    device_type: pick(client.device_type, DEVICES),
    platform: pick(client.platform, PLATFORMS),
    browser: pick(client.browser, BROWSERS),
  };
}

/** { category, title, description, client } when acceptable, else { error }. */
export function validateSuggestion(body) {
  if (!isPlainObject(body)) return { error: "invalid suggestion" };
  // The hidden spam trap: the game always sends "" (or nothing).
  if (body.website !== undefined && body.website !== "") return { error: "invalid suggestion" };
  if (typeof body.category !== "string" || !SUGGESTION_CATEGORIES.includes(body.category)) {
    return { error: "invalid category" };
  }
  if (typeof body.title !== "string") return { error: "invalid title" };
  if (typeof body.description !== "string") return { error: "invalid description" };
  const title = cleanText(body.title).replace(/\s+/g, " ");
  const description = cleanText(body.description)
    .split("\n")
    .map((line) => line.trimEnd())
    .join("\n")
    .replace(/\n{3,}/g, "\n\n");
  const titleLength = charCount(title);
  if (titleLength < MIN_TITLE || titleLength > MAX_TITLE) return { error: `title must be ${MIN_TITLE}-${MAX_TITLE} characters` };
  const descriptionLength = charCount(description);
  if (descriptionLength < MIN_DESCRIPTION || descriptionLength > MAX_DESCRIPTION) {
    return { error: `description must be ${MIN_DESCRIPTION}-${MAX_DESCRIPTION} characters` };
  }
  if ((description.match(/https?:\/\/|www\./gi) || []).length > MAX_LINKS) return { error: "too many links" };
  return { category: body.category, title, description, client: normalizeClient(body.client) };
}

/** The GitHub issue ({title, body}) for a checked suggestion. */
export function issueFor(checked) {
  const c = checked.client;
  return {
    title: `[Player suggestion] ${neutralizeTitle(checked.title)}`,
    body: [
      "Anonymous suggestion sent from inside **Lastborn Colony**.",
      "",
      `**Category:** ${escapeMarkdown(checked.category)}`,
      "",
      "**Title:**",
      markdownQuote(checked.title),
      "",
      "**Suggestion:**",
      markdownQuote(checked.description),
      "",
      "**Game details (sent automatically):**",
      ...(c
        ? [
            `- Game version: ${escapeMarkdown(c.game_version)}`,
            `- Runs as: ${escapeMarkdown(c.runtime)}`,
            `- Device: ${escapeMarkdown(c.device_type)}`,
            `- System: ${escapeMarkdown(c.platform)}`,
            `- Browser: ${escapeMarkdown(c.browser)}`,
          ]
        : ["- Not sent"]),
      "",
      "*Sent without a player account. The player's text above is escaped and can't contain links, mentions or formatting.*",
    ].join("\n"),
  };
}

async function hashedAddress(ip, env, day) {
  // The address is mixed with the day and a secret, then hashed: KV never holds a raw IP.
  const digest = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(`${day}:${ip}:${env.GITHUB_TOKEN}`));
  return [...new Uint8Array(digest)].map((b) => b.toString(16).padStart(2, "0")).join("");
}

export function suggestionsOpen(env) {
  return Boolean(env.GITHUB_TOKEN && env.LEADERBOARD_KV);
}

/** GET /suggestions */
export function suggestionStatus(request, env) {
  return reply(request, { accepting: suggestionsOpen(env) });
}

/**
 * POST /suggestions. `githubFetch` is replaceable so tests never call GitHub.
 * Only GitHub's 201 counts as delivered.
 */
export async function handleSuggestionPost(request, env, ip, githubFetch = fetch) {
  if (!suggestionsOpen(env)) {
    return reply(request, { error: "suggestions are not set up on the server yet (no GITHUB_TOKEN)" }, 503);
  }
  const read = await readBody(request, MAX_BODY_BYTES);
  if (read.tooLarge) return reply(request, { error: "message too large" }, 413);
  const incoming = parseJson(read.text);
  if (incoming === undefined) return reply(request, { error: "invalid json" }, 400);
  const checked = validateSuggestion(incoming);
  if (checked.error) return reply(request, { error: checked.error }, 400);

  const day = new Date().toISOString().slice(0, 10);
  const ipKey = "suggest:ip:" + (await hashedAddress(ip, env, day));
  const globalKey = "suggest:global:" + day;
  let ipCount = 0;
  let globalCount = 0;
  try {
    [ipCount, globalCount] = (await Promise.all([env.LEADERBOARD_KV.get(ipKey), env.LEADERBOARD_KV.get(globalKey)])).map(
      (v) => Number(v) || 0,
    );
  } catch (err) {
    console.log("suggestion counter read failed:", String(err));
  }
  if (ipCount >= DAILY_IP_LIMIT || globalCount >= DAILY_GLOBAL_LIMIT) {
    return reply(request, { error: "daily limit reached; try again tomorrow" }, 429);
  }

  const owner = env.GITHUB_OWNER || "Zephino";
  const repo = env.GITHUB_REPO || "Lastborn_Colony";
  let response;
  try {
    response = await githubFetch(`https://api.github.com/repos/${owner}/${repo}/issues`, {
      method: "POST",
      headers: {
        Authorization: `Bearer ${env.GITHUB_TOKEN}`,
        Accept: "application/vnd.github+json",
        "X-GitHub-Api-Version": "2022-11-28",
        "Content-Type": "application/json",
        "User-Agent": "lastborn-colony-suggestions-worker",
      },
      body: JSON.stringify(issueFor(checked)),
    });
  } catch {
    return reply(request, { error: "could not reach GitHub" }, 502);
  }
  if (response.status !== 201) {
    // A short reason the owner can act on; never GitHub's reply body or the token.
    console.log("create GitHub issue failed:", response.status);
    const reasons = {
      401: "the server's GitHub token is invalid or expired (401)",
      403: "GitHub refused the server's token (403): it needs Issues: Read and write on Zephino/Lastborn_Colony",
      404: "GitHub couldn't find the repository (404): check the token's repository access and that Issues are turned on",
      410: "Issues are turned off for the repository (410)",
      422: "GitHub refused the suggestion (422)",
    };
    return reply(request, { error: reasons[response.status] || `GitHub could not save the suggestion (${response.status})` }, 502);
  }
  try {
    await Promise.all([
      env.LEADERBOARD_KV.put(ipKey, String(ipCount + 1), { expirationTtl: 90_000 }),
      env.LEADERBOARD_KV.put(globalKey, String(globalCount + 1), { expirationTtl: 90_000 }),
    ]);
  } catch (err) {
    console.log("suggestion counter write failed:", String(err));
  }
  const result = await response.json().catch(() => ({}));
  return reply(request, { accepted: true, issue_number: Number(result?.number) || 0 }, 201);
}
