# Guiding principles: calledtoconstruct/omarchy-backup-actions

## Purpose and scope
An Omarchy bar plugin: a `job` button that opens `menu.sh` for borgmatic backup now, list archives, restore, and installing a user timer.

## Stack and layout
Omarchy plugin `manifest.json`, `ActionsWidget.qml`, Bash `menu.sh`, systemd user units in `units/`, test script `test/menu.sh`.

## Commands
| Check | Command | Evidence |
|---|---|---|
| Build | Not applicable | - |
| Lint | None configured; `shellcheck` is the natural check for the Bash scripts but is not wired up | - |
| Tests | `test/menu.sh` (uses `BACKUP_SYSTEMCTL`/`BACKUP_BORGMATIC` stand-ins, so it does not touch real backups) | test/menu.sh, README.md |
| CI | None | repository tree |

Commands marked as not written down come from the build files, not from project docs; confirm them before relying on them.

## Before every push
Before every push: run the build and type-check/lint that exist here, plus only the tests for the files or feature you changed (team rule, ideas #14 note 6797). Do not run the full suite locally as a routine gate; this repository has no CI that runs the full suite, so run the full suite only when the change is broad, and say in the PR that CI coverage is missing. Merge needs a positive review. Explain any new failure your change caused. Never weaken a valid test to make it pass, and never invent a command this file does not list.

## Project rules
- The menu asks before writing anything and never prunes, deletes or compacts archives. Keep it that way.
- Restore refuses `/`, the home directory and non-empty destinations; do not loosen those checks.
- Tests must use the stand-in commands, never the live user manager or a real repository.

## What to avoid
- Committing to the default branch; work on a branch and open a pull request.
- Deleting files, branches or history, or changing repository settings.
- Adding tooling, CI or dependencies that the change does not need.
- Rules copied from other projects (file-size limits, clocks, quotas) that this repository never adopted.

## Delivery and safety
- Installed with Omarchy's plugin command; nothing is published automatically.

## Open questions
- No CI.

## Sources
Read from the `main` branch on 2026-11-08 ET: `README.md`, `manifest.json`, `test/menu.sh`.

## Instruction updates
Check `guiding-principles.version` at the start of each turn and when you enter this project; reload this file when the version changes. Change this file, its version and date, and `PRINCIPLES_HISTORY.md` in the same commit. Team-wide role instructions are versioned separately in the team-process repository.
