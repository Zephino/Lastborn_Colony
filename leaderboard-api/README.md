# Lastborn Colony online service

A small, free **Cloudflare Worker** (an always-on mini web service) that runs
the game's online features:

- **Leaderboard:** how far each colony got, on which planet.
- **Sign in with Google:** so a player's cloud save can follow them between devices.
- **Cloud save:** one saved colony per Google account.
- **Privacy policy page**, which Google's sign-in screen links to.

```
Game ──POST score──▶ Worker (checks it) ──▶ Workers KV (the board)
                                        └─▶ GitHub data branch (optional copy)
Game ◀──GET board── Worker
Game ──sign in / cloud save──▶ Worker ──▶ Durable Objects (accounts, saves)
```

Addresses:

| What | Address |
| --- | --- |
| The Worker | https://lastborn-colony.thebotcoder.workers.dev |
| The board (all planets) | https://lastborn-colony.thebotcoder.workers.dev/leaderboard |
| Brume's board | https://lastborn-colony.thebotcoder.workers.dev/leaderboard?planet=brume |
| Privacy policy | https://lastborn-colony.thebotcoder.workers.dev/privacy |
| Google redirect URI | https://lastborn-colony.thebotcoder.workers.dev/auth/callback |
| The web game | https://zephino.github.io/Lastborn_Colony/ |

The game itself only knows the Worker's address (in
`scripts/net/online_config.gd`). It never holds a key or password. The game
always works offline; online features just show a short message when they
can't reach the Worker.

**Secrets never go in the repository or in a chat.** They live only in
Cloudflare: `GOOGLE_CLIENT_ID`, `GOOGLE_CLIENT_SECRET`, and (optional)
`GITHUB_TOKEN`. The KV namespace id in `wrangler.toml` is public and safe to
keep there.

---

## Part 1: Deploy the Worker from GitHub (about 10 minutes)

Cloudflare builds and deploys the Worker by itself every time `main` changes.
You need a free Cloudflare account (https://dash.cloudflare.com/sign-up).

### 1a. Check the KV storage exists

The leaderboard is stored in a Workers KV namespace whose id is already in
`wrangler.toml` (`90125d9378f84cd4b05edd98a1b5f9a3`).

1. Go to https://dash.cloudflare.com and sign in.
2. In the left menu click **Storage & Databases** → **Workers KV** (on older
   dashboards: **Workers & Pages** → **KV**).
3. You should see a namespace whose **ID** is `90125d9378f84cd4b05edd98a1b5f9a3`.
   If it's there, go on to 1b.
4. If it isn't (for example it was deleted): click **Create instance** (or
   **Create namespace**), name it `lastborn-colony-data`, click **Create**,
   copy its new **ID**, and ask Claude to put that id into
   `leaderboard-api/wrangler.toml`.

### 1b. Connect the Worker to the GitHub repository

1. In the Cloudflare dashboard, click **Workers & Pages** in the left menu.
2. Click **Create** (or **Create application**) → **Import a repository**
   (on some dashboards: the **Workers** tab → **Connect to Git**).
3. Pick **GitHub**, allow Cloudflare to see `Zephino/Lastborn_Colony` if it
   asks, and select that repository.
4. Fill in the settings exactly like this:
   - **Project name:** `lastborn-colony` (must match `name` in `wrangler.toml`)
   - **Production branch:** `main`
   - **Root directory** (under *Advanced* or *Build settings*): `leaderboard-api`
     (not the repository root)
   - **Build command:** leave blank / None
   - **Deploy command:** `npx wrangler deploy`
5. Click **Save and Deploy** (or **Deploy**).
6. Wait for the build to finish: **Workers & Pages** → **lastborn-colony** →
   **Deployments**. A green tick means it worked. If it's red, click it, copy
   the red error text, and send it to Claude.
   - If it says you need a **workers.dev subdomain**, choose `thebotcoder` on
     the page it offers, then click **Retry deployment**.

`wrangler.toml` already declares the KV binding and the Durable Objects (the
storage for accounts and saves), so there is nothing to click for those.
Durable Objects are part of Cloudflare's free plan.

**Note:** a green GitHub Pages build of the game does *not* mean the Worker
deployed. Check the Worker's own **Deployments** page.

### 1c. Check it works

1. Open https://lastborn-colony.thebotcoder.workers.dev/leaderboard in your browser.
2. You should see a short line of text like
   `{"updated":"","planets":{}}`. That's JSON, and it means the board works
   (empty until someone sends a score).
3. Open https://lastborn-colony.thebotcoder.workers.dev/privacy: you should
   see the privacy policy page.
4. Sign-in won't work until Part 2 is done; the game will say
   "Sign in with Google isn't set up on the server yet."

---

## Part 2: Sign in with Google (about 15 minutes, free)

You make a "client" in Google Cloud, then give its two values to Cloudflare as
secrets. **The Client ID and Client secret go only into Cloudflare.** Never
paste them into the repository or a chat.

### 2a. Google Cloud console

1. Go to https://console.cloud.google.com and sign in with your Google account.
2. At the top, click the project picker → **New project** → name it
   `Lastborn Colony` → **Create**. Make sure it's selected at the top.
3. In the search bar type **Google Auth Platform** and open it (or menu ☰ →
   **APIs & Services** → **OAuth consent screen**) → **Get started**:
   - **App name:** `Lastborn Colony`; **User support email:** your email → **Next**.
   - **Audience:** **External** → **Next**.
   - **Contact information:** your email → **Next**.
   - Tick the agreement → **Continue** → **Create**.
   - Don't upload a logo (that starts a slow review, and the game doesn't need one).
4. In Google Auth Platform click **Clients** → **Create client**:
   - **Application type:** **Web application**
   - **Name:** `Lastborn Colony Worker`
   - Under **Authorized redirect URIs** click **Add URI** and paste exactly:
     `https://lastborn-colony.thebotcoder.workers.dev/auth/callback`
   - Click **Create**. A box shows the **Client ID** and **Client secret**.
     Keep this tab open (or click **Download JSON**) for step 2b.
5. Click **Branding** and fill in:
   - **Application home page:** `https://zephino.github.io/Lastborn_Colony/`
   - **Application privacy policy link:** `https://lastborn-colony.thebotcoder.workers.dev/privacy`
   - **Authorized domains:** click **Add domain** twice and enter
     `thebotcoder.workers.dev` and `zephino.github.io`
   - Click **Save**.
6. Click **Audience** → **Publish app** → **Confirm**. (Until you do, only
   "test users" listed on that page can sign in.) The game only asks Google
   for basic sign-in and the email address, so Google doesn't need to review it.

### 2b. Put the two values into Cloudflare

1. Cloudflare dashboard → **Workers & Pages** → **lastborn-colony** →
   **Settings** → **Variables and Secrets** → **Add**.
2. **Type:** Secret, **Variable name:** `GOOGLE_CLIENT_ID`, **Value:** the
   Client ID from Google → **Save** (or add another).
3. **Add** again: **Type:** Secret, **Variable name:** `GOOGLE_CLIENT_SECRET`,
   **Value:** the Client secret → **Save**.
4. Click **Deploy** if it asks. Secrets stay in place when the Worker updates
   from GitHub.

### 2c. Test sign-in

1. Open the game and press **Sign in with Google**.
2. A Google page opens in your browser. Pick your account.
3. The page says **Signed in!** Switch back to the game: it shows your email.
4. Try the same on another device (for example your phone in the web game):
   both now share one cloud save.

---

## Part 3 (optional): a public copy of the board on GitHub

The board works from Cloudflare alone. If you also want a copy at
`leaderboard.json` on the repository's `data` branch, so anyone can browse it
on GitHub:

1. Create the branch: on GitHub open `Zephino/Lastborn_Colony` → click the
   branch button (says **main**) → type `data` → **Create branch: data from main**.
2. Make a token: https://github.com/settings/personal-access-tokens/new
   - **Token name:** `lastborn-leaderboard`; **Expiration:** 1 year (set a reminder).
   - **Repository access:** **Only select repositories** → `Zephino/Lastborn_Colony`.
   - **Repository permissions** → **Contents:** **Read and write**. Nothing else.
   - **Generate token**, and copy it.
3. Cloudflare → **Workers & Pages** → **lastborn-colony** → **Settings** →
   **Variables and Secrets** → **Add**: **Type** Secret, **Name**
   `GITHUB_TOKEN`, **Value** the token → **Save**.

From the next score on, the Worker also commits `leaderboard.json` to the
`data` branch (never to `main`). If the token expires, make a new one and
replace the secret; nothing in the game changes.

---

## How the leaderboard works

Each score keeps: player name (up to 16 letters, numbers, spaces, `-`, `_`),
colony name (up to 24 of the same), planet (today always `brume`), ending
(`free`, `receivership`, `silent`, or `retired` for a game the player left),
turns played, marks paid off, the starting debt, population, game version,
and the date (set by the Worker).

Each planet has its own board of the best 100:

1. Colonies that bought out the Charter (`free`) come first, fewest turns first.
2. Everyone else follows, most marks paid first, then most turns survived.
3. Ties go to whoever sent first.

The Worker checks everything again, whatever the game sends: allowed
characters, turns 1–5,000, marks paid 0 up to the debt, debt up to 1,000,000,
population 0–100,000. It refuses a score sent twice, and more than 3 scores a
minute from one address. Reading the board writes nothing, so it doesn't use
up Cloudflare's free daily write allowance (about 1,000 KV writes a day).

**Honest limits:** scores come from players' devices, so a determined cheater
could fake a believable one. To remove a bad score, ask Claude.

## How sign-in and cloud saves work

- The game asks the Worker to start a sign-in, opens the Google page in the
  browser, and asks the Worker every 2 seconds until the player has signed in
  (up to 10 minutes).
- The Worker keeps only a scrambled (hashed) form of Google's id for each
  player, plus that account's private cloud-save code. The email is passed to
  the player's own device (to show who is signed in) and not kept on the
  server. The real name is never asked for.
- Each cloud save sits in its own Durable Object, named by a scrambled form of
  the code. The game stores the code in `user://account.json` on the device.
- A device can write its cloud save at most once every 5 seconds.
- Free plan: about 100,000 Durable Object requests a day, which covers a lot of
  players.

## For developers

| File | What it does |
| --- | --- |
| `src/index.js` | The service: routes, `/leaderboard` GET/POST, rate limits, optional GitHub copy. |
| `src/board.js` | Leaderboard rules: what a score must look like, ranking, 100 per planet. |
| `src/accounts.js` | Sign in with Google (`/auth/*`, the `AccountVault` Durable Object). |
| `src/cloud.js` | Cloud saves (`/cloud/save`, the `SaveVault` Durable Object). |
| `src/cors.js` | Which web pages may call the Worker (the web game's address). |
| `src/privacy.js` | The privacy policy page (`/privacy`). |
| `test/*.test.js` | Tests with pretend storage: `node --test test/*.test.js` (or `npm test`). |
| `.gdignore` | Keeps Godot from importing this folder. |

- API: `GET /leaderboard?planet=brume` → `{planet, updated, entries}`;
  `GET /leaderboard` → `{updated, planets: {brume: [...]}}`;
  `POST /leaderboard` (JSON score) → `{accepted, rank, planet, entries}`.
- Cloud: `GET /cloud/save` → `{save: "<save file text>" | null, updated}`;
  `PUT /cloud/save` with the save file's text. Both need
  `Authorization: Bearer <code>`.
- To host the web game at another address, add it to `ALLOWED_ORIGINS` in
  `src/cors.js` (PC and phone builds don't need this).
- Test the game against a Worker on your own computer: `npx wrangler dev` in
  this folder, then start Godot with `-- --api=http://127.0.0.1:8787`.
  `-- --api=` (empty) turns the online features off.
- The game's side is `scripts/net/` (`online.gd`, `online_config.gd`,
  `score_entry.gd`) with its text in `data/online.json`; those rules mirror
  `src/board.js`, so change both together.
