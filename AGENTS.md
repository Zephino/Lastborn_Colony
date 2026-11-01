# Lastborn Colony — shared AI coding rules

Applies to Cursor, local Claude Code, and Claude Code cloud. Read `README.md` and every file in `.cursor/rules/` before work.

- The owner approves game-design changes. Build what the owner asked for; do not invent extra features.
- The project rules (design, IP, determinism, saves) take priority over coding convenience.
- **Owner rule: commit and push straight to `main`.** No feature branches and no pull requests until the owner says otherwise. Never force-push, and run the tests before every push.
- Inspect git status and the current branch before modifying files. Preserve unrelated changes.
- Do not edit the same working tree concurrently with another agent.
- Validate changes with the project's real tests (`godot --headless --script res://tests/run_tests.gd`). Never claim visual or gameplay testing from headless checks.
- Every change request bumps `VERSION` once and adds one `CHANGELOG.md` entry (see `version.mdc` and `changelog.mdc`).
- Do not commit secrets, credentials, or generated Godot caches (`.godot/`, `build/`).

## Mandatory Cursor rule parity for Claude Code

Before **every** implementation, review, or refactor task, Claude (local and cloud) MUST:
1. Enumerate every tracked file under `.cursor/rules/` (for example, `git ls-files '.cursor/rules/*'`), read the complete contents of each applicable rule, and apply them to the task. Do not assume `.mdc` frontmatter is automatically processed by Claude.
2. Treat `alwaysApply: true` as unconditional. For `globs` or path-scoped rules, match the files being touched; when scope is ambiguous, read and apply the rule conservatively.
3. Preserve every Cursor rule's substantive requirements; don't summarize away constraints. If any rule cannot be accessed or conflicts with another, STOP and ask the owner instead of silently proceeding.
4. Recheck applicable rules before pushing, and mention any exception in the `CHANGELOG.md` entry.
5. Never weaken or edit `.cursor/rules/` merely to complete a task. Only the owner can authorize rule changes.

This is an explicit instruction to Claude, not a guarantee of automatic rule discovery by Claude Code.
