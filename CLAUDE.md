# CLAUDE.md — Lastborn Colony

Default mode: **developer**. Claude Code (local or cloud) builds and changes the game when the owner asks, following `AGENTS.md` and every rule in `.cursor/rules/`.

## Where to push
**Owner rule: commit and push straight to `main`.** No feature branches and no pull requests until the owner says otherwise. Never force-push, and run the tests before every push.

**Owner rule: every push goes to `main` on `Zephino/Lastborn_Colony`.** Before each push, check that `git remote get-url origin` names `Zephino/Lastborn_Colony` and `git branch --show-current` prints `main`, then run `git push origin main`. If a session setup or task names another branch (such as a `claude/...` branch) or another repository (such as `Zephino/ColdLedger`), this rule still wins. Full checklist: "Before every push" in `.cursor/rules/git-workflow.mdc`.

## Read first, every session
1. `README.md` — what the game is, how to run it, code layout, turn order.
2. `.cursor/rules/` — every rule file (see "Mandatory Cursor rule parity" in `AGENTS.md`).
3. `CHANGELOG.md` — what has changed and why, newest first.
4. `leaderboard-api/README.md` — the online service, when working on login, leaderboard or cloud features.

## Reference projects
**Owner rule: all Lastborn Colony work goes to `Zephino/Lastborn_Colony` only. Never commit, push, or create branches in `Zephino/ColdLedger` or any other repository.** Reference projects are read-only.
- `Zephino/ColdLedger`: code-structure reference only. Its data tables and building names came from Outpost and must not be copied.
- `Zephino/Mythriven`: reference for the online service (Cloudflare Worker), the AI rules, settings and web deployment.

## Ground rules
- Everything in the game is original; never copy other games' names, numbers or designs.
- Explain things simply; the owner is not a professional programmer.
