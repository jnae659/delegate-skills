#!/usr/bin/env bash
# Fleet setup — installs the non-skill fleet pieces from jnae659/delegate-skills.
# Skills themselves are installed by:  npx skills add jnae659/delegate-skills
# Preferred path is the /fleet-setup skill inside Claude Code; this script is the
# no-Claude alternative. Idempotent: safe to run twice. Respects $HOME.
set -euo pipefail

# Where this script's fleet/ dir is — works whether run from a clone or piped via curl
# (when piped, it re-downloads the three pieces from the repo's main branch).
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
FLEET_DIR="$SCRIPT_DIR/fleet-setup/fleet"
REPO_RAW="https://raw.githubusercontent.com/jnae659/delegate-skills/main"
if [ ! -d "$FLEET_DIR" ]; then
  FLEET_DIR="$(mktemp -d)/fleet"; mkdir -p "$FLEET_DIR"
  for f in delegate-skills.config.json opencode.jsonc CLAUDE.md; do
    curl -fsSL "$REPO_RAW/fleet-setup/fleet/$f" -o "$FLEET_DIR/$f"
  done
fi

stamp="$(date +%Y%m%d-%H%M%S)"

install_piece() { # <src> <dest>  — backup existing, then copy
  local src="$1" dest="$2"
  mkdir -p "$(dirname "$dest")"
  if [ -f "$dest" ]; then
    cp "$dest" "$dest.backup-$stamp"
    echo "backed up: $dest -> $dest.backup-$stamp"
  fi
  cp "$src" "$dest"
  echo "installed: $dest"
}

echo "==> Fleet setup"
install_piece "$FLEET_DIR/delegate-skills.config.json" "$HOME/.config/delegate-skills/config.json"
install_piece "$FLEET_DIR/opencode.jsonc"              "$HOME/.config/opencode/opencode.jsonc"
install_piece "$FLEET_DIR/CLAUDE.md"                   "$HOME/.claude/CLAUDE.md"

# Idempotent .zshrc env var (hides ~/.claude/* from OpenCode sessions)
ZRC="$HOME/.zshrc"
touch "$ZRC"
if ! grep -qs 'OPENCODE_DISABLE_CLAUDE_CODE' "$ZRC"; then
  printf '\nexport OPENCODE_DISABLE_CLAUDE_CODE=1\n' >> "$ZRC"
  echo "appended: export OPENCODE_DISABLE_CLAUDE_CODE=1 -> $ZRC"
else
  echo "ok: OPENCODE_DISABLE_CLAUDE_CODE already in $ZRC"
fi

# Sanity checks — warn, never fail
echo "==> Checks"
command -v opencode >/dev/null 2>&1 \
  || echo "WARN: opencode CLI not found. Install: curl -fsSL https://opencode.ai/install | bash"
[ -n "$(git config --global user.name 2>/dev/null)" ] && [ -n "$(git config --global user.email 2>/dev/null)" ] \
  || echo "WARN: git identity unset. Run: git config --global user.name \"<name>\" && git config --global user.email \"<email>\""

cat <<'EOF'

==> Done. Two things this script cannot do — finish them by hand:
  1. opencode auth login   (log in to each model provider you use: z.ai, minimax, opencode)
  2. Claude Code routing (settings.json / model aliases) — configure manually if this is a new machine.
Restart your terminal (or: source ~/.zshrc) so OPENCODE_DISABLE_CLAUDE_CODE takes effect.
EOF
