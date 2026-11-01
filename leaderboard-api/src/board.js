/**
 * Lastborn Colony leaderboard rules: what a score must look like, how each
 * planet's board is sorted, and how many rows it keeps. No network code here,
 * so it can be tested with `npm test`.
 *
 * A score (one row) says how far a colony got, on which planet:
 *   name        the player's name: letters, numbers, space, _ and - only, up to 16
 *   colony      the colony's name, same characters, up to 24
 *   planet      planet id, e.g. "brume" (lower-case letters and numbers)
 *   difficulty  "easy", "normal" or "hard" (games from before difficulty
 *               levels existed send none and count as "normal")
 *   ending      "free" (paid off the Charter), "receivership" (the Company took
 *               over), "silent" (everyone died), "retired" (the player left),
 *               "independence" (the colony declared itself free) or
 *               "company_town" (the colony was signed over to the Company)
 *   turn        turns played, 1..5000
 *   debt_paid   marks paid off, 0..debt_total ("free" means all of it)
 *   debt_total  the colony's starting debt, 1..1,000,000
 *   population  people alive at the end, 0..100,000
 *   version     game version, "XX.XX.XX"
 *   date        set by the Worker, never by the game
 *
 * Each planet and difficulty has its own board. Normal boards are stored
 * under the planet id ("brume", as before difficulty levels existed); Easy and
 * Hard under "brume_easy" and "brume_hard" (see boardKey).
 *
 * Ranking (per board): "free" endings first, fewest turns first; then
 * everyone else by most marks paid, then most turns survived; ties go to
 * the earlier date. Each board keeps its best 100.
 */

export const MAX_ENTRIES = 100;
export const MAX_NAME_LENGTH = 16;
export const MAX_COLONY_LENGTH = 24;
export const MAX_TURN = 5000;
export const MAX_DEBT_TOTAL = 1_000_000;
export const MAX_POPULATION = 100_000;
/** No more boards than this (stops junk planet ids filling KV). */
export const MAX_PLANETS = 16;
export const DIFFICULTIES = ["easy", "normal", "hard"];
export const ENDINGS = ["free", "receivership", "silent", "retired", "independence", "company_town"];
export const ABOUT =
  "Lastborn Colony shared leaderboard. Written only by the leaderboard Worker; edits by hand are overwritten.";

export const PLANET_PATTERN = /^[a-z0-9]{1,24}$/;
/** A board's key: the planet, plus "_easy" or "_hard" for those difficulties. */
export const BOARD_KEY_PATTERN = /^[a-z0-9]{1,24}(_(easy|hard))?$/;

/** Where a score (or a planet + difficulty) is filed. */
export function boardKey(entry) {
  const difficulty = entry.difficulty ?? "normal";
  return difficulty === "normal" ? entry.planet : `${entry.planet}_${difficulty}`;
}
const VERSION_PATTERN = /^\d{2}\.\d{2}\.\d{2}$/;
const DATE_PATTERN = /^\d{4}-\d{2}-\d{2}T[\d:.]+Z$/;
/** Script / markup characters: a name containing any of these is refused outright. */
const INJECTION_MARKERS = ["'", '"', ";", "--", "/*", "*/", "\\", "`", "<", ">"];

export function looksLikeInjection(raw) {
  const s = String(raw ?? "");
  for (const marker of INJECTION_MARKERS) {
    if (s.includes(marker)) return true;
  }
  for (let i = 0; i < s.length; i++) {
    if (s.charCodeAt(i) < 32) return true;
  }
  return false;
}

/** Keeps A–Z, a–z, 0–9, space, _ and -; squeezes spaces; trims; cuts to `max`. */
export function sanitizeName(raw, max = MAX_NAME_LENGTH) {
  let cleaned = "";
  for (const ch of String(raw ?? "")) {
    if (/[A-Za-z0-9 _-]/.test(ch)) cleaned += ch;
  }
  cleaned = cleaned.replace(/ {2,}/g, " ").trim();
  return cleaned.slice(0, max).trim();
}

/** A JSON number that is whole and in min..max. Strings ("12"), arrays, null and true are refused. */
function wholeNumber(raw, min, max) {
  if (typeof raw !== "number" || !Number.isInteger(raw) || raw < min || raw > max) return null;
  return raw;
}

/**
 * Checks one score. Returns { entry } when it's acceptable, or { error } with
 * a short reason. `date` is added by the caller.
 */
export function validateScore(body) {
  if (!body || typeof body !== "object" || Array.isArray(body)) return { error: "invalid json" };
  // Text fields must really be strings: ["Ari"] or 42 would otherwise turn into text.
  if (typeof body.name !== "string" || looksLikeInjection(body.name)) return { error: "invalid name" };
  const name = sanitizeName(body.name, MAX_NAME_LENGTH);
  if (!name) return { error: "invalid name" };
  if (typeof body.colony !== "string" || looksLikeInjection(body.colony)) return { error: "invalid colony" };
  const colony = sanitizeName(body.colony, MAX_COLONY_LENGTH);
  if (!colony) return { error: "invalid colony" };
  const planet = typeof body.planet === "string" ? body.planet : "";
  if (!PLANET_PATTERN.test(planet)) return { error: "invalid planet" };
  const difficulty = body.difficulty === undefined ? "normal" : body.difficulty;
  if (typeof difficulty !== "string" || !DIFFICULTIES.includes(difficulty)) return { error: "invalid difficulty" };
  const ending = typeof body.ending === "string" ? body.ending : "";
  if (!ENDINGS.includes(ending)) return { error: "invalid ending" };
  const turn = wholeNumber(body.turn, 1, MAX_TURN);
  if (turn === null) return { error: "invalid turn" };
  const debt_total = wholeNumber(body.debt_total, 1, MAX_DEBT_TOTAL);
  if (debt_total === null) return { error: "invalid debt" };
  const debt_paid = wholeNumber(body.debt_paid, 0, debt_total);
  if (debt_paid === null) return { error: "invalid debt" };
  if (ending === "free" && debt_paid !== debt_total) return { error: "invalid debt" };
  const population = wholeNumber(body.population, 0, MAX_POPULATION);
  if (population === null) return { error: "invalid population" };
  const version = typeof body.version === "string" ? body.version : "";
  if (!VERSION_PATTERN.test(version)) return { error: "invalid version" };
  return { entry: { name, colony, planet, difficulty, ending, turn, debt_paid, debt_total, population, version } };
}

/** Negative when `a` ranks above `b` (see the ranking at the top of this file). */
export function compareEntries(a, b) {
  const aFree = a.ending === "free";
  const bFree = b.ending === "free";
  if (aFree !== bFree) return aFree ? -1 : 1;
  if (aFree) {
    if (a.turn !== b.turn) return a.turn - b.turn;
  } else {
    if (a.debt_paid !== b.debt_paid) return b.debt_paid - a.debt_paid;
    if (a.turn !== b.turn) return b.turn - a.turn;
  }
  return String(a.date ?? "").localeCompare(String(b.date ?? ""));
}

/** The same game sent twice (for example a double tap on Submit). */
export function isDuplicate(entries, entry) {
  return entries.some(
    (e) =>
      e.name === entry.name &&
      e.colony === entry.colony &&
      e.planet === entry.planet &&
      (e.difficulty ?? "normal") === (entry.difficulty ?? "normal") &&
      e.ending === entry.ending &&
      e.turn === entry.turn &&
      e.debt_paid === entry.debt_paid &&
      e.population === entry.population,
  );
}

function sortedRows(list) {
  const rows = [];
  for (const item of Array.isArray(list) ? list : []) {
    const checked = validateScore(item);
    if (!checked.entry) continue;
    const date = String(item.date ?? "");
    checked.entry.date = DATE_PATTERN.test(date) ? date : "";
    rows.push(checked.entry);
  }
  rows.sort(compareEntries);
  return rows.slice(0, MAX_ENTRIES);
}

/**
 * Rebuilds the stored board from raw data, dropping anything malformed:
 * { _about, updated, planets: { brume: [rows], ... } }.
 */
export function normalizeBoard(raw) {
  const planets = {};
  const source = raw && typeof raw.planets === "object" && !Array.isArray(raw.planets) ? raw.planets : {};
  for (const [key, list] of Object.entries(source)) {
    if (!BOARD_KEY_PATTERN.test(key) || Object.keys(planets).length >= MAX_PLANETS) continue;
    // Rows sit under their own board only.
    const rows = sortedRows((Array.isArray(list) ? list : []).filter((r) => r && typeof r === "object" && boardKey(r) === key));
    if (rows.length > 0) planets[key] = rows;
  }
  return { _about: ABOUT, updated: typeof raw?.updated === "string" ? raw.updated : "", planets };
}

export function emptyBoard() {
  return { _about: ABOUT, updated: "", planets: {} };
}

/** One board's rows (empty if nobody has played there yet). `key` is from boardKey. */
export function planetEntries(board, key) {
  return board.planets[key] ?? [];
}

/** True when `entry` would make its planet's board (and there's room for its planet). */
export function qualifies(board, entry) {
  const rows = board.planets[boardKey(entry)];
  if (!rows) return Object.keys(board.planets).length < MAX_PLANETS;
  if (rows.length < MAX_ENTRIES) return true;
  return compareEntries(entry, rows[rows.length - 1]) < 0;
}

/** Adds `entry` (with its date); returns { board, rank } (rank 1 = top, 0 = fell off). */
export function addEntry(board, entry, nowIso) {
  const row = { ...entry, date: nowIso };
  const rows = [...planetEntries(board, boardKey(entry)), row];
  rows.sort(compareEntries);
  const kept = rows.slice(0, MAX_ENTRIES);
  const rank = kept.indexOf(row) + 1;
  return {
    board: { _about: ABOUT, updated: nowIso, planets: { ...board.planets, [boardKey(entry)]: kept } },
    rank,
  };
}
