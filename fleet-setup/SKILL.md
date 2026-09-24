---
name: fleet-setup
description: >-
  Install or refresh this machine's delegate-fleet configuration: the lane map
  (~/.config/delegate-skills/config.json), the OpenCode permission deny rules and MCP config
  (~/.config/opencode/opencode.jsonc), the delegation rules (~/.claude/CLAUDE.md), and the
  OPENCODE_DISABLE_CLAUDE_CODE env var in ~/.zshrc. Use after `npx skills add
  jnae659/delegate-skills` on a new device, or to re-sync this machine's fleet config to the
  repo's version. Not for dispatching work or changing lanes (that's delegate-setup).
license: MIT
compatibility: macOS/Linux. Claude Code with file-write and bash access.
metadata:
  version: 1.0.0
---

# Fleet Setup

You install the fleet's **non-skill pieces** from this skill's bundled payload into the user's
home directory. The skills themselves arrived via `npx skills add jnae659/delegate-skills` — this
skill completes the installation.

(`<skill-dir>` is this skill's install directory — the folder containing this `SKILL.md`. The
payload is `<skill-dir>/fleet/`.)

## What gets installed

| Payload file | Destination |
| --- | --- |
| `fleet/delegate-skills.config.json` | `~/.config/delegate-skills/config.json` (lane map) |
| `fleet/opencode.jsonc` | `~/.config/opencode/opencode.jsonc` (deny rules + MCP) |
| `fleet/CLAUDE.md` | `~/.claude/CLAUDE.md` (delegation rules) |
| — | `export OPENCODE_DISABLE_CLAUDE_CODE=1` appended to `~/.zshrc` if absent |

## Flow

1. **Show first.** List the table above with resolved absolute paths, note which destinations
   already exist, and ask for a go-ahead if any destination already has content.
2. **Back up, never clobber.** For each destination that already exists, copy it to
   `<destination>.backup-<YYYYMMDD-HHMMSS>` before writing.
3. **Write** the three payload files (create parent dirs as needed) and append the env var line
   to `~/.zshrc` only if `OPENCODE_DISABLE_CLAUDE_CODE` is not already present there.
4. **Verify** each piece and show the results:
   - lane map: JSON parses and contains the five lanes (`feature`, `complex`, `tests`, `fast`, `e2e`)
   - opencode.jsonc: all six `deny` patterns present (`*relay.mjs*`, `opencode run*`, `opencode run`,
     `*migrate:fresh*`, `*migrate:refresh*`, `*db:wipe*`)
   - CLAUDE.md: contains the `HARD RULE — gates before landing` and
     `HARD RULE — no destructive DB resets` headings
   - `~/.zshrc`: exactly one `OPENCODE_DISABLE_CLAUDE_CODE` line
5. **Close** with the two steps you cannot do for the user, and no more:
   - `opencode auth login` (each provider they use)
   - Claude Code model routing (`~/.claude/settings.json`) — configured manually, never by this skill
   - restart the terminal (or `source ~/.zshrc`) for the env var

## Hard rules

- **Never write `~/.claude/settings.json`** — it holds live secrets and the user's own routing.
- Idempotent: running this twice must leave exactly one env-var line and fresh backups, never
  duplicated content.
- Do not modify the payload files, the other skills, or anything outside the four destinations.
- This skill never dispatches work and never edits lane contents — changing lanes is
  `delegate-setup`'s job.
