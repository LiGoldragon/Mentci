#!/bin/bash
set -euo pipefail

# Only run in Claude Code on the web
if [ "${CLAUDE_CODE_REMOTE:-}" != "true" ]; then
  exit 0
fi

# Parse source from stdin — only run full setup on startup
INPUT=$(cat)
SOURCE=$(echo "$INPUT" | grep -o '"source":"[^"]*"' | cut -d'"' -f4 || true)
if [ "$SOURCE" != "startup" ]; then
  exit 0
fi

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-/home/user/Mentci}"

# ── 1. Install Nix (single-user, no daemon) ──────────────────────────────
# Pre-configure Nix: disable build-users-group (sandbox runs as root
# without the nixbld group) and enable flakes
mkdir -p /etc/nix "$HOME/.config/nix"
cat > /etc/nix/nix.conf <<'NIXCONF'
build-users-group =
experimental-features = nix-command flakes
NIXCONF
cp /etc/nix/nix.conf "$HOME/.config/nix/nix.conf"

# Ensure Nix is on PATH before the install check — the profile sourcing
# script requires $USER which may be absent in the sandbox's minimal init
export PATH="$HOME/.nix-profile/bin:/nix/var/nix/profiles/default/bin:$PATH"

if ! command -v nix &>/dev/null; then
  echo "Installing Nix (single-user)..."
  # Ensure $USER is set for the install script
  export USER="${USER:-root}"
  curl -fsSL https://nixos.org/nix/install | sh -s -- --no-daemon
  # Re-add to PATH after install
  export PATH="$HOME/.nix-profile/bin:/nix/var/nix/profiles/default/bin:$PATH"
fi

echo "Nix $(nix --version) ready"

# ── 2. Build the dev shell and capture its environment ────────────────────
echo "Building pure Nix dev shell (this fetches all dependencies)..."
cd "$PROJECT_DIR"

# nix print-dev-env evaluates the devShell and prints bash that reproduces
# the environment — this is the non-interactive equivalent of `nix develop --pure`
NIX_ENV=$(nix print-dev-env --accept-flake-config 2>&1)

# ── 3. Export Nix shell environment into the Claude session ───────────────
if [ -n "${CLAUDE_ENV_FILE:-}" ] && [ -n "$CLAUDE_ENV_FILE" ]; then
  # Extract export lines from the dev env, filtering out shell internals.
  # We want PATH, RUST_SRC_PATH, PKG_CONFIG_PATH, etc.
  echo "$NIX_ENV" | grep '^export ' | while IFS= read -r line; do
    varname=$(echo "$line" | sed 's/^export \([^=]*\)=.*/\1/')
    case "$varname" in
      BASH_*|FUNCNAME|GROUPS|PIPESTATUS|RANDOM|SECONDS|SHELLOPTS|UID|EUID|PPID|_|HOME|USER|LOGNAME|TERM|SHELL)
        continue
        ;;
      *)
        echo "$line" >> "$CLAUDE_ENV_FILE"
        ;;
    esac
  done

  # Project-specific vars
  echo "export MENTCI_V1_ROOT=\"$PROJECT_DIR\"" >> "$CLAUDE_ENV_FILE"

  echo "Pure Nix dev shell environment written to CLAUDE_ENV_FILE"
else
  echo "WARNING: CLAUDE_ENV_FILE not set — Nix env will not persist to session"
fi

echo "Session start hook complete."
