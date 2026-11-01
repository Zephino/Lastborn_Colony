/**
 * Input safety helpers shared by every route. Everything a player's device
 * sends is untrusted: the Worker checks type, length and allowed characters
 * itself, whatever the game already checked.
 *
 * No SQL is used anywhere in this Worker. Storage is Workers KV and the
 * Durable Object key/value API (storage.get/put). The Durable Objects are
 * SQLite-backed, but the code never calls ctx.storage.sql / sql.exec. If SQL
 * is ever added, every player value MUST be passed as a bound parameter
 * (sql.exec("... WHERE id = ?", id)), never joined into the query text.
 * Filtering characters is not protection against SQL injection.
 */

const encoder = new TextEncoder();

/** Size of `text` in UTF-8 bytes (what the network carries), not JS string length. */
export function byteLength(text) {
  return encoder.encode(String(text)).length;
}

/**
 * The request body as text, read at most `max` bytes. Returns { text } or
 * { tooLarge: true }. Stops reading as soon as the limit is passed, so a huge
 * body (or a chunked one with no Content-Length) can't fill memory.
 */
export async function readBody(request, max) {
  const declared = parseInt(request.headers.get("content-length") || "0", 10);
  if (Number.isFinite(declared) && declared > max) return { tooLarge: true };
  if (!request.body) return { text: "" };
  const reader = request.body.getReader();
  const chunks = [];
  let total = 0;
  for (;;) {
    const { done, value } = await reader.read();
    if (done) break;
    total += value.byteLength;
    if (total > max) {
      try {
        await reader.cancel();
      } catch (_) {}
      return { tooLarge: true };
    }
    chunks.push(value);
  }
  const all = new Uint8Array(total);
  let offset = 0;
  for (const chunk of chunks) {
    all.set(chunk, offset);
    offset += chunk.byteLength;
  }
  return { text: new TextDecoder().decode(all) };
}

/** JSON.parse that answers undefined instead of throwing. */
export function parseJson(text) {
  try {
    return JSON.parse(text);
  } catch {
    return undefined;
  }
}

/** A plain JSON object ({...}), not null, an array, a number or a string. */
export function isPlainObject(value) {
  return value !== null && typeof value === "object" && !Array.isArray(value);
}

/**
 * Characters that don't print but can hide or spoof text: C0/C1 controls
 * (except tab and newline, handled by the caller), soft hyphen, bidirectional
 * overrides and isolates, zero-width spaces/joiners, word joiner, BOM,
 * invisible Hangul fillers, interlinear annotation marks and Unicode "tag"
 * characters (used to smuggle hidden text).
 */
const INVISIBLE =
  /[\u0000-\u0008\u000B\u000C\u000E-\u001F\u007F-\u009F\u00AD\u034F\u061C\u115F\u1160\u180E\u200B-\u200F\u202A-\u202E\u2060-\u2064\u2066-\u206F\u3164\uFEFF\uFFA0\uFFF9-\uFFFB]|[\u{E0000}-\u{E007F}]/gu;
/** Half of a UTF-16 surrogate pair with no partner (not a real character). */
const LONE_SURROGATE = /[\uD800-\uDBFF](?![\uDC00-\uDFFF])|(?<![\uD800-\uDBFF])[\uDC00-\uDFFF]/g;

/**
 * Player text, tidied: NFC, line endings as \n, tabs as spaces, invisible and
 * spoofing characters removed, trimmed. "" for anything that isn't a string.
 */
export function cleanText(value) {
  if (typeof value !== "string") return "";
  return value
    .replace(LONE_SURROGATE, "")
    .normalize("NFC")
    .replace(/\r\n?|\u0085|\u2028|\u2029/g, "\n")
    .replace(/\t/g, " ")
    .replace(INVISIBLE, "")
    .trim();
}

/** Length in characters (code points), the way the game counts them. */
export function charCount(text) {
  return [...text].length;
}

/**
 * Makes player text inert inside a GitHub Markdown issue body: no headings,
 * lists, quotes, tables, links, images, HTML, math, @mentions, #issue
 * references or clickable URLs. The text still reads normally on GitHub.
 */
export function escapeMarkdown(text) {
  return String(text)
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    // Full-width look-alikes: GitHub never treats these as a mention or an issue link.
    .replace(/@/g, "\uFF20")
    .replace(/#/g, "\uFF03")
    .replace(/([\\`*_{}\[\]()+.!|~=$^-])/g, "\\$1")
    // Bare links: GitHub would make these clickable, so break the pattern.
    .replace(/:\/\//g, ":&#47;&#47;")
    .replace(/\bwww\\\./gi, "www&#46;")
    // "GH-123" is another way to link an issue.
    .replace(/\bGH\\-(?=\d)/gi, "GH\u2011");
}

/** Each line of `text`, escaped, as a Markdown quote ("> ..."). */
export function markdownQuote(text) {
  return escapeMarkdown(text)
    .split("\n")
    .map((line) => "> " + line)
    .join("\n");
}

/** An issue title: one line, no mentions or issue references. */
export function neutralizeTitle(text) {
  return String(text).replace(/@/g, "\uFF20").replace(/#/g, "\uFF03").replace(/\bGH-(?=\d)/gi, "GH\u2011");
}
