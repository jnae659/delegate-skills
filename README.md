# delegate-skills (jnae659 fork)

A fork of `amElnagdy/delegate-skills`, developed in place. Diverged from upstream on 2026-09-22 —
never blind-copy upstream over it.

Fork changes: `nestedDispatch` tripwire in `opencode-delegate/scripts/relay.mjs`, mandatory
`<no_nesting>` brief blocks, `<parallel_plan>` support, destructive-DB-reset ban in brief
templates, plus the `fleet/` config pieces and `setup.sh` installed by this README.

## Install on a new device — one command

```bash
npx skills add jnae659/delegate-skills && \
  curl -fsSL https://raw.githubusercontent.com/jnae659/delegate-skills/main/setup.sh | bash
```

- `npx skills add` installs the four skills (`claude-delegate`, `opencode-delegate`,
  `delegate-setup`, `find-skills`).
- `setup.sh` installs the rest of the fleet and is idempotent (backups, never silent clobber):

| Piece | Lands at |
|---|---|
| Lane→model map | `~/.config/delegate-skills/config.json` |
| OpenCode deny rules + MCP | `~/.config/opencode/opencode.jsonc` |
| Fleet rules (CLAUDE.md) | `~/.claude/CLAUDE.md` |
| `export OPENCODE_DISABLE_CLAUDE_CODE=1` | `~/.zshrc` |

Then finish by hand: `opencode auth login` (each provider) and your Claude Code routing.

## ⚠️ On the dev machine: never `npx skills add` this repo

The dev machine keeps the skills as **real directories** in `~/.claude/skills` (the repo root).
Running `npx skills add jnae659/delegate-skills` there could recreate the `~/.agents/skills`
symlink layout that was deliberately removed. Update the dev machine with:

```bash
git -C ~/.claude/skills pull
```

## Repo layout

The git root **is** `~/.claude/skills`, so every fork edit is a tracked diff — no copy/sync step.
`fleet/`, `setup.sh`, and this README are ignored by the skills CLI (it only installs dirs
containing `SKILL.md`).

No secrets live in this repo: `~/.claude/settings.json` (API token) and OpenCode's `auth.json`
are outside the repo root and are never committed.
