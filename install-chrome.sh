#!/usr/bin/env bash
#
# install-chrome.sh — Install Google Chrome (stable) on Debian 13 / XFCE.
#
# Google Chrome is NOT in the Debian apt repos, so this downloads the
# official .deb from Google. The package's own postinst registers Google's
# apt repository, so future `apt upgrade` keeps Chrome up to date.
#
# This installer:
#   1. Downloads the official google-chrome-stable .deb (amd64).
#   2. Installs it with apt (needs sudo; apt resolves dependencies).
#   3. Pins Chrome to the Plank dock.
#   4. Verifies the install.
#
# Safe to re-run (idempotent).
#
set -euo pipefail

DEB_URL="https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb"
BUILD_DIR="${HOME}/.cache/macos-theme-build"
DEB_PATH="${BUILD_DIR}/google-chrome-stable_current_amd64.deb"

section() { printf '\n\033[1;34m==> %s\033[0m\n' "$*"; }
info()    { printf '    %s\n' "$*"; }
warn()    { printf '\033[1;33m    ! %s\033[0m\n' "$*"; }
die()     { printf '\033[1;31m!! %s\033[0m\n' "$*" >&2; exit 1; }

command -v curl >/dev/null || die "curl is required."
[ "$(dpkg --print-architecture)" = "amd64" ] || die "Google Chrome .deb is amd64-only."

# ---------------------------------------------------------------------------
# 1. Already installed?
# ---------------------------------------------------------------------------
section "Installing Google Chrome"
if command -v google-chrome-stable >/dev/null 2>&1; then
  info "Already installed: $(google-chrome-stable --version 2>/dev/null || echo present)"
  exit 0
fi

# ---------------------------------------------------------------------------
# 2. Download (skip if a valid .deb is already cached)
# ---------------------------------------------------------------------------
mkdir -p "$BUILD_DIR"
if dpkg-deb -f "$DEB_PATH" Package >/dev/null 2>&1; then
  info "Using cached .deb: $DEB_PATH"
else
  info "Downloading $DEB_URL"
  curl -fsSL -o "$DEB_PATH" "$DEB_URL"
fi

# ---------------------------------------------------------------------------
# 3. Install (sudo; apt pulls in dependencies and the Google repo)
# ---------------------------------------------------------------------------
info "Installing .deb (needs sudo)…"
sudo apt-get update -qq || warn "apt update failed, continuing"
sudo apt-get install -y "$DEB_PATH"

# ---------------------------------------------------------------------------
# 4. Pin Chrome to the Plank dock
# ---------------------------------------------------------------------------
section "Pinning Chrome to the dock"
LDIR="${HOME}/.config/plank/dock1/launchers"
DOCK_KEY="/net/launchpad/plank/docks/dock1/dock-items"
if command -v dconf >/dev/null 2>&1 && [ -d "$LDIR" ]; then
  cat > "$LDIR/google-chrome.dockitem" <<'EOF'
[PlankDockItemPreferences]
Launcher=file:///usr/share/applications/google-chrome.desktop
EOF
  CUR=$(dconf read "$DOCK_KEY" 2>/dev/null || echo "")
  if [ -n "$CUR" ] && ! printf '%s' "$CUR" | grep -q 'google-chrome.dockitem'; then
    # Append before the closing bracket so it joins the dock list.
    NEW=$(printf '%s' "$CUR" | sed "s/]\s*$/, 'google-chrome.dockitem']/")
    dconf write "$DOCK_KEY" "$NEW"
    pkill -x plank 2>/dev/null || true
    sleep 1
    (nohup plank >/dev/null 2>&1 &) || true
    info "Added Chrome to the dock."
  else
    info "Chrome already on the dock (or Plank not configured) — skipped."
  fi
else
  warn "Plank not set up — skipping dock pin. Run ./install.sh first, then re-run."
fi

# ---------------------------------------------------------------------------
# 5. Verify
# ---------------------------------------------------------------------------
section "Done"
if command -v google-chrome-stable >/dev/null 2>&1; then
  info "$(google-chrome-stable --version)"
  info "Launch from the app menu / Spotlight, or run: google-chrome-stable"
  info "To pin to the macOS dock: open Chrome, right-click its Plank icon"
  info "  > 'Keep in Dock'."
else
  die "Install finished but google-chrome-stable not found."
fi
