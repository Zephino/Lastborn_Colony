/**
 * The privacy policy (GET /privacy), linked from Google's sign-in screen
 * (Google Auth Platform → Branding → Application privacy policy link:
 * https://lastborn-colony.thebotcoder.workers.dev/privacy). Plain text about
 * what the game and this Worker keep; update it whenever that changes.
 */

const CONTACT = "thebotcoder@gmail.com";
const GAME_URL = "https://zephino.github.io/Lastborn_Colony/";

const SECTIONS = [
  ["What Lastborn Colony keeps", [
    "<b>Sign in with Google:</b> Google's account id for you, stored scrambled (hashed). Your Google email is passed straight to your own device so the game can show which account you're signed in with; the server doesn't keep it. Lastborn Colony never asks Google for your real name.",
    "<b>Cloud save:</b> your saved colony, stored under your account's private sync code, so you can carry it between devices.",
    "<b>Leaderboard:</b> only if you choose to send a score: the player name you type, your colony's name, the planet, how the game ended, turns played, marks paid, population and the game version. It is shown publicly.",
    "<b>Suggestions:</b> only if you send one: the category, title and text you type, plus the game version, whether you play in a browser or the app, the kind of device (desktop, phone or tablet), the operating system family and the browser family. It is posted publicly as an issue on the game's GitHub repository, without your name or account. To limit spam, a scrambled (hashed) form of your internet address is counted for one day, then forgotten; the address itself is never stored.",
  ]],
  ["What it doesn't do", [
    "No ads, no tracking, no analytics, and nothing is sold or shared with anyone.",
    "Your games are also saved on your own device, and the game works without an account or an internet connection.",
  ]],
  ["Deleting your data", [
    `Signing out in the game stops using the cloud save on that device. To have your cloud save and account deleted from the server, or a leaderboard row removed, email ${CONTACT}.`,
  ]],
  ["Where it's stored", [
    "On Cloudflare (Workers, Workers KV and Durable Objects), which runs the game's online features. A copy of the leaderboard may also be kept on the game's GitHub repository.",
  ]],
];

export function privacyPage() {
  const body = SECTIONS.map(([title, items]) => `<h2>${title}</h2><ul>${items.map((i) => `<li>${i}</li>`).join("")}</ul>`).join("");
  const html = `<!doctype html><html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>Lastborn Colony — Privacy policy</title><style>body{font-family:system-ui,sans-serif;background:#141a22;color:#e6edf3;max-width:720px;
margin:0 auto;padding:16px;line-height:1.5}h1{font-size:1.6em}h2{font-size:1.15em;margin-top:1.5em}a{color:#e0a458}</style></head>
<body><h1>Lastborn Colony — Privacy policy</h1><p>Last updated November 1, 2026. Lastborn Colony is a game made by one developer. This page says what it keeps about you.</p>
${body}<p><a href="${GAME_URL}">Play Lastborn Colony</a></p></body></html>`;
  return new Response(html, { headers: { "Content-Type": "text/html; charset=utf-8", "Cache-Control": "public, max-age=3600" } });
}
