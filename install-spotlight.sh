#!/usr/bin/env bash
#
# install-spotlight.sh — Add a macOS "Spotlight"-style search launcher to the
#                        WhiteSur Debian 13 / XFCE (X11) setup.
#
# This installer:
#   1. Sanity-checks the session.
#   2. Installs Ulauncher from the upstream .deb (not in Debian apt).
#   3. Installs a custom "Spotlight" Ulauncher theme (translucent, rounded,
#      SF Pro font) that matches the WhiteSur look.
#   4. Configures Ulauncher: theme + Ctrl+Space hotkey (like real Spotlight).
#   5. Enables autostart and (re)starts Ulauncher.
#
# Safe to re-run (idempotent).
#
set -euo pipefail

# ---------------------------------------------------------------------------
# Paths & constants
# ---------------------------------------------------------------------------
ULAUNCHER_VERSION="5.15.15"
ULAUNCHER_DEB_URL="https://github.com/Ulauncher/Ulauncher/releases/download/${ULAUNCHER_VERSION}/ulauncher_${ULAUNCHER_VERSION}_all.deb"

BUILD_DIR="${HOME}/.cache/macos-theme-build"
DEB_PATH="${BUILD_DIR}/ulauncher_${ULAUNCHER_VERSION}_all.deb"

CONFIG_DIR="${HOME}/.config/ulauncher"
THEMES_DIR="${CONFIG_DIR}/user-themes"
THEME_DIR="${THEMES_DIR}/spotlight"
AUTOSTART_DIR="${HOME}/.config/autostart"

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
section() { printf '\n\033[1;34m==> %s\033[0m\n' "$*"; }
info()    { printf '    %s\n' "$*"; }
warn()    { printf '\033[1;33m    ! %s\033[0m\n' "$*"; }
die()     { printf '\033[1;31m!! %s\033[0m\n' "$*" >&2; exit 1; }

# ---------------------------------------------------------------------------
# 1. Sanity checks
# ---------------------------------------------------------------------------
section "Checking session"
[ -n "${DISPLAY:-}" ] || die "No \$DISPLAY. Run this from inside your XFCE session."
command -v curl >/dev/null || die "curl is required."
info "DISPLAY=${DISPLAY}  OK"

mkdir -p "${BUILD_DIR}" "${THEME_DIR}" "${AUTOSTART_DIR}"

# ---------------------------------------------------------------------------
# 2. Install Ulauncher
# ---------------------------------------------------------------------------
section "Installing Ulauncher ${ULAUNCHER_VERSION}"
if command -v ulauncher >/dev/null 2>&1; then
  info "Ulauncher already installed: $(ulauncher --version 2>/dev/null || echo present)"
else
  info "Downloading ${ULAUNCHER_DEB_URL}"
  curl -fsSL -o "${DEB_PATH}" "${ULAUNCHER_DEB_URL}"
  info "Installing .deb (needs sudo; apt resolves dependencies)…"
  sudo apt-get update -qq || warn "apt update failed, continuing"
  sudo apt-get install -y "${DEB_PATH}"
fi

# ---------------------------------------------------------------------------
# 3. Install the Spotlight theme
# ---------------------------------------------------------------------------
section "Installing the Spotlight theme"

cat > "${THEME_DIR}/manifest.json" <<'JSON'
{
  "manifest_version": "1",
  "name": "spotlight",
  "display_name": "Spotlight (WhiteSur)",
  "extend_theme": "light",
  "css_file": "theme.css",
  "css_file_gtk_3.20+": "theme.css",
  "matched_text_hl_colors": {
    "when_selected": "#ffffff",
    "when_not_selected": "#0a82ff"
  }
}
JSON

cat > "${THEME_DIR}/theme.css" <<'CSS'
/* macOS Spotlight look for Ulauncher — matches the WhiteSur theme. */

* {
    font-family: "SF Pro Display", "SF Pro Text", "Inter", sans-serif;
}

/* The whole popup: translucent rounded panel like Spotlight. */
.app {
    background-color: rgba(245, 245, 247, 0.92);
    border-radius: 18px;
    border: 1px solid rgba(0, 0, 0, 0.10);
    box-shadow: 0 18px 50px rgba(0, 0, 0, 0.35);
}

/* Search input row. */
#input {
    color: #1d1d1f;
    font-size: 26px;
    font-weight: 300;
    padding: 14px 16px;
    background-color: transparent;
    caret-color: #0a82ff;
    border: none;
    box-shadow: none;
}

/* Thin separator under the input. */
#input-wrapper {
    border-bottom: 1px solid rgba(0, 0, 0, 0.08);
}

#prefs-btn {
    opacity: 0.45;
}

/* Result rows. */
.item-box {
    border-radius: 10px;
    padding: 6px 8px;
}

.selected.item-box {
    background-color: #0a82ff;
}

#item-name {
    color: #1d1d1f;
    font-size: 16px;
    font-weight: 400;
}
.selected #item-name { color: #ffffff; }

#item-descr {
    color: rgba(0, 0, 0, 0.5);
    font-size: 12px;
}
.selected #item-descr { color: rgba(255, 255, 255, 0.85); }

#item-shortcut,
.selected #item-shortcut {
    color: rgba(0, 0, 0, 0.45);
    font-size: 12px;
}
.selected #item-shortcut { color: rgba(255, 255, 255, 0.85); }
CSS

info "Theme written to ${THEME_DIR}"

# ---------------------------------------------------------------------------
# 4. Configure Ulauncher (theme + Ctrl+Space hotkey)
# ---------------------------------------------------------------------------
section "Configuring Ulauncher"

# Stop a running instance so it picks up new settings on relaunch.
pkill -f 'ulauncher' 2>/dev/null || true
sleep 1

mkdir -p "${CONFIG_DIR}"
cat > "${CONFIG_DIR}/settings.json" <<'JSON'
{
  "clear-previous-query": true,
  "disable-desktop-filters": false,
  "grab-mouse-pointer": false,
  "hotkey-show-app": "<Primary>space",
  "render-on-screen": "mouse-pointer-monitor",
  "show-indicator-icon": true,
  "show-recent-apps": "3",
  "terminal-command": "",
  "theme-name": "spotlight"
}
JSON
info "Set theme=spotlight, hotkey=Ctrl+Space"

# ---------------------------------------------------------------------------
# 5. Autostart + launch
# ---------------------------------------------------------------------------
section "Enabling autostart and launching"

cat > "${AUTOSTART_DIR}/ulauncher.desktop" <<'DESKTOP'
[Desktop Entry]
Type=Application
Name=Ulauncher (Spotlight)
Comment=macOS Spotlight-style launcher
Exec=ulauncher --hide-window --no-window-shadow
Icon=ulauncher
Terminal=false
X-GNOME-Autostart-enabled=true
DESKTOP

# Launch in the background, hidden, ready for the hotkey.
nohup ulauncher --hide-window --no-window-shadow >/dev/null 2>&1 &
sleep 3

section "Done"
info "Press Ctrl+Space to open Spotlight."
info "If Ctrl+Space is taken, change it in Ulauncher Preferences > General."
