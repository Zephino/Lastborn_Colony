# CLAUDE.md — Lastborn Colony

Default mode: **developer**. Claude Code (local or cloud) builds and changes the game when the owner asks, following `AGENTS.md` and every rule in `.cursor/rules/`.

## Where to push
**Owner rule: commit and push straight to `main`.** No feature branches and no pull requests until the owner says otherwise. Never force-push, and run the tests before every push.

## Read first, every session
1. `README.md` — what the game is, how to run it, code layout, turn order.
2. `.cursor/rules/` — every rule file (see "Mandatory Cursor rule parity" in `AGENTS.md`).
3. `CHANGELOG.md` — what has changed and why, newest first.
4. `leaderboard-api/README.md` — the online service, when working on login, leaderboard or cloud features.

## Reference projects
- `Zephino/ColdLedger`: code-structure reference only. Its data tables and building names came from Outpost and must not be copied.
- `Zephino/Mythriven`: reference for the online service (Cloudflare Worker), the AI rules, settings and web deployment.

## Ground rules
- Everything in the game is original; never copy other games' names, numbers or designs.
- Explain things simply; the owner is not a professional programmer.
