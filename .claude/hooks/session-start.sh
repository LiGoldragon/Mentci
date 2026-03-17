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

# ── Configuration ─────────────────────────────────────────────────────────
IMAGE_REGISTRY="ghcr.io"
IMAGE_NAME="ligoldragon/mentci-devshell"
IMAGE_TAG="latest"
IMAGE_REF="${IMAGE_REGISTRY}/${IMAGE_NAME}:${IMAGE_TAG}"
MARKER="/nix/.mentci-devshell-extracted"

# ── 1. Skip if already extracted (container state is cached) ──────────────
if [ -f "$MARKER" ]; then
  echo "Devshell image already extracted"
else
  echo "Pulling devshell image from ${IMAGE_REF}..."

  # Install skopeo if not present (lightweight OCI puller, no daemon needed)
  if ! command -v skopeo &>/dev/null; then
    apt-get update -qq && apt-get install -y -qq skopeo >/dev/null 2>&1
  fi

  WORKDIR=$(mktemp -d)
  trap "rm -rf $WORKDIR" EXIT

  # Pull as a Docker archive (single tarball, simpler to extract)
  skopeo copy "docker://${IMAGE_REF}" "docker-archive:${WORKDIR}/image.tar" --quiet 2>/dev/null || \
  skopeo copy "docker://${IMAGE_REF}" "docker-archive:${WORKDIR}/image.tar"

  # Unpack the Docker archive (contains manifest.json + layer tars)
  mkdir -p "${WORKDIR}/image"
  tar -xf "${WORKDIR}/image.tar" -C "${WORKDIR}/image"

  # Extract each layer directly to / so /nix/store paths are correct.
  # Nix store paths are absolute — binaries have hardcoded /nix/store/...
  # references, so the store must live at /nix/store, not under a prefix.
  mkdir -p /nix/store
  grep -o '"[^"]*\/layer\.tar"' "${WORKDIR}/image/manifest.json" | tr -d '"' | while read -r layer; do
    tar -xf "${WORKDIR}/image/${layer}" -C / 2>/dev/null || true
  done

  trap - EXIT
  rm -rf "$WORKDIR"

  # Mark as extracted so we don't re-pull on cached container restarts
  touch "$MARKER"
  echo "Devshell image extracted to /nix/store"
fi

# ── 2. Build PATH and environment from the image's /nix/store ─────────────
# Find the fenix Rust toolchain — it must come first in PATH so rustc
# resolves its sysroot (std library) relative to its own bin directory
RUST_TOOLCHAIN=$(find /nix/store -maxdepth 1 -name "*rust-nightly-latest*" -not -name "*.drv" -type d -print -quit 2>/dev/null || true)

NIX_BIN_PATHS=""
# Rust toolchain bin first (sysroot resolution depends on this)
if [ -n "$RUST_TOOLCHAIN" ] && [ -d "${RUST_TOOLCHAIN}/bin" ]; then
  NIX_BIN_PATHS="${RUST_TOOLCHAIN}/bin"
fi
# Then the image's merged /bin profile
NIX_BIN_PATHS="${NIX_BIN_PATHS:+${NIX_BIN_PATHS}:}/bin"
# Then individual store path bins
for bindir in /nix/store/*/bin; do
  [ -d "$bindir" ] && NIX_BIN_PATHS="${NIX_BIN_PATHS}:${bindir}"
done

# ── 3. Export environment into Claude session ─────────────────────────────
if [ -n "${CLAUDE_ENV_FILE:-}" ] && [ -n "$CLAUDE_ENV_FILE" ]; then
  # PATH: Nix store bins first, then system fallbacks
  echo "export PATH=\"${NIX_BIN_PATHS}:\$PATH\"" >> "$CLAUDE_ENV_FILE"

  # Rust sysroot — critical for rustc to find std
  if [ -n "$RUST_TOOLCHAIN" ]; then
    echo "export RUSTUP_TOOLCHAIN=\"${RUST_TOOLCHAIN}\"" >> "$CLAUDE_ENV_FILE"
  fi

  # SSL certs for cargo/curl/gh
  SSL_CERT=$(find /nix/store -path "*/etc/ssl/certs/ca-bundle.crt" -print -quit 2>/dev/null || true)
  if [ -n "$SSL_CERT" ]; then
    echo "export SSL_CERT_FILE=\"${SSL_CERT}\"" >> "$CLAUDE_ENV_FILE"
    echo "export NIX_SSL_CERT_FILE=\"${SSL_CERT}\"" >> "$CLAUDE_ENV_FILE"
  fi

  # Rust src path for rust-analyzer
  RUST_SRC=$(find /nix/store -maxdepth 1 -name "*rust-lib-src*" -print -quit 2>/dev/null || true)
  [ -z "$RUST_SRC" ] && RUST_SRC=$(find /nix/store -maxdepth 1 -name "*rustLibSrc*" -print -quit 2>/dev/null || true)
  [ -n "$RUST_SRC" ] && echo "export RUST_SRC_PATH=\"${RUST_SRC}\"" >> "$CLAUDE_ENV_FILE"

  # pkg-config search path
  PKG_CONFIG_PATHS=""
  for pcdir in /nix/store/*/lib/pkgconfig; do
    [ -d "$pcdir" ] && PKG_CONFIG_PATHS="${PKG_CONFIG_PATHS:+${PKG_CONFIG_PATHS}:}${pcdir}"
  done
  [ -n "$PKG_CONFIG_PATHS" ] && echo "export PKG_CONFIG_PATH=\"${PKG_CONFIG_PATHS}\"" >> "$CLAUDE_ENV_FILE"

  # Library paths for native linking
  LIB_PATHS=""
  for libdir in /nix/store/*/lib; do
    [ -d "$libdir" ] && ls "$libdir"/*.so* &>/dev/null 2>&1 && LIB_PATHS="${LIB_PATHS:+${LIB_PATHS}:}${libdir}"
  done
  if [ -n "$LIB_PATHS" ]; then
    echo "export LIBRARY_PATH=\"${LIB_PATHS}\"" >> "$CLAUDE_ENV_FILE"
    echo "export LD_LIBRARY_PATH=\"${LIB_PATHS}\"" >> "$CLAUDE_ENV_FILE"
  fi

  # C/C++ include paths
  INCLUDE_PATHS=""
  for incdir in /nix/store/*/include; do
    [ -d "$incdir" ] && INCLUDE_PATHS="${INCLUDE_PATHS:+${INCLUDE_PATHS}:}${incdir}"
  done
  if [ -n "$INCLUDE_PATHS" ]; then
    echo "export C_INCLUDE_PATH=\"${INCLUDE_PATHS}\"" >> "$CLAUDE_ENV_FILE"
    echo "export CPLUS_INCLUDE_PATH=\"${INCLUDE_PATHS}\"" >> "$CLAUDE_ENV_FILE"
  fi

  # Project-specific
  echo "export MENTCI_V1_ROOT=\"${PROJECT_DIR}\"" >> "$CLAUDE_ENV_FILE"

  echo "Pure Nix devshell environment exported to CLAUDE_ENV_FILE"
else
  echo "WARNING: CLAUDE_ENV_FILE not set — devshell env will not persist"
fi

echo "Session start hook complete."
