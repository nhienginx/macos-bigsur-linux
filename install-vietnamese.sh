#!/usr/bin/env bash
#
# install-vietnamese.sh — Install a Vietnamese input method (fcitx5-unikey)
#                         for Debian 13 / XFCE (X11), tuned to coexist with
#                         the macOS Spotlight launcher.
#
# Why fcitx5-unikey:
#   * Actively maintained (2026), best app compatibility (Chrome/Electron/Qt).
#   * In Debian apt (ibus-bamboo is not, and is unmaintained).
#
# This installer:
#   1. Installs fcitx5 + unikey + GTK/Qt frontends (needs sudo).
#   2. Sets the session input-method env vars in ~/.xprofile (X11).
#   3. Writes a fcitx5 profile: English (US) + Unikey/Telex, toggle Ctrl+Space.
#   4. Moves the Spotlight (Ulauncher) hotkey to Super+Space to avoid the
#      Ctrl+Space clash (and to match macOS Cmd+Space).
#   5. Starts fcitx5 for the current session.
#
# NOTE: input-method env vars only fully apply to apps started AFTER you log
#       out and back in. Do that once after running this.
#
# Safe to re-run (idempotent).
#
set -euo pipefail

section() { printf '\n\033[1;34m==> %s\033[0m\n' "$*"; }
info()    { printf '    %s\n' "$*"; }
warn()    { printf '\033[1;33m    ! %s\033[0m\n' "$*"; }
die()     { printf '\033[1;31m!! %s\033[0m\n' "$*" >&2; exit 1; }

[ -n "${DISPLAY:-}" ] || die "No \$DISPLAY. Run this from inside your XFCE session."

# ---------------------------------------------------------------------------
# 1. Install packages
# ---------------------------------------------------------------------------
section "Installing fcitx5 + Unikey"
if command -v fcitx5 >/dev/null 2>&1 && [ -e /usr/lib/*/fcitx5/libunikey.so ] 2>/dev/null; then
  info "fcitx5 + unikey already present."
else
  sudo apt-get update -qq || warn "apt update failed, continuing"
  sudo apt-get install -y \
    fcitx5 \
    fcitx5-unikey \
    fcitx5-config-qt \
    fcitx5-frontend-gtk3 \
    fcitx5-frontend-gtk4 \
    fcitx5-frontend-qt5
fi

# ---------------------------------------------------------------------------
# 2. Session env vars (X11) — make GTK/Qt/X apps talk to fcitx5
# ---------------------------------------------------------------------------
# IMPORTANT: Debian/MX's Xsession sources ~/.xsessionrc (via
# /etc/X11/Xsession.d/40x11-common_xsessionrc) on login — it does NOT source
# ~/.xprofile (only GDM-style DMs do). LightDM on MX uses Xsession, so the env
# vars MUST go in ~/.xsessionrc or apps never learn to use fcitx. We write both
# for portability across desktops.
section "Configuring session env (~/.xsessionrc)"
IM_BLOCK='# fcitx — Vietnamese input method (added by macos-theme-setup)
export GTK_IM_MODULE=fcitx
export QT_IM_MODULE=fcitx
export XMODIFIERS=@im=fcitx
export SDL_IM_MODULE=fcitx
export GLFW_IM_MODULE=ibus'
for f in "${HOME}/.xsessionrc" "${HOME}/.xprofile"; do
  touch "$f"
  if ! grep -q 'fcitx — Vietnamese input' "$f" 2>/dev/null; then
    printf '\n%s\n' "$IM_BLOCK" >> "$f"
    info "Added IM env vars to $f"
  else
    info "IM env vars already in $f"
  fi
done

# ---------------------------------------------------------------------------
# 3. fcitx5 input-method profile: English (US) + Unikey (Telex)
# ---------------------------------------------------------------------------
section "Configuring fcitx5 profile (Telex, toggle Ctrl+Space)"
FCITX_CFG="${HOME}/.config/fcitx5"
mkdir -p "$FCITX_CFG/conf"

# Input groups: start in English, toggle to Vietnamese with Ctrl+Space.
cat > "$FCITX_CFG/profile" <<'EOF'
[Groups/0]
Name=Default
Default Layout=us
DefaultIM=keyboard-us

[Groups/0/Items/0]
Name=keyboard-us
Layout=

[Groups/0/Items/1]
Name=unikey
Layout=

[GroupOrder]
0=Default
EOF

# Global toggle key = Ctrl+Space (Vietnamese muscle memory).
cat > "$FCITX_CFG/config" <<'EOF'
[Hotkey]
TriggerKeys=Control+space
EnumerateWithTriggerKeys=True
EnumerateForwardKeys=
EnumerateBackwardKeys=
EnumerateSkipFirst=False

[Hotkey/AltTriggerKeys]
0=Super+space

[Behavior]
ActiveByDefault=False
ShareInputState=All
PreeditEnabledByDefault=True
EOF

# Unikey engine: Telex method, Unicode encoding, spell-check + macro on.
cat > "$FCITX_CFG/conf/unikey.conf" <<'EOF'
InputMethod=Telex
OutputCharset=Unicode
Macro=True
SpellCheck=True
AutoNonVnRestore=True
ModernStyle=False
EOF
info "Profile written: keyboard-us + unikey (Telex), toggle Ctrl+Space"

# ---------------------------------------------------------------------------
# 4. Move Spotlight (Ulauncher) hotkey off Ctrl+Space -> Super+Space
# ---------------------------------------------------------------------------
section "Moving Spotlight hotkey to Super+Space"
UL_SETTINGS="${HOME}/.config/ulauncher/settings.json"
if [ -f "$UL_SETTINGS" ]; then
  # Replace the hotkey value; tolerant of <Primary>space or any prior value.
  sed -i 's/"hotkey-show-app": *"[^"]*"/"hotkey-show-app": "<Super>space"/' "$UL_SETTINGS"
  info "Ulauncher hotkey set to Super+Space (was Ctrl+Space)."
  pkill -f 'bin/ulauncher' 2>/dev/null || true
  sleep 1
  (nohup ulauncher --hide-window --no-window-shadow >/dev/null 2>&1 &) || true
else
  warn "Ulauncher settings not found — run ./install-spotlight.sh first."
fi

# ---------------------------------------------------------------------------
# 5. Autostart fcitx5 on login
# ---------------------------------------------------------------------------
# The Debian/MX fcitx5 package does NOT ship an XDG autostart entry, so without
# this fcitx5 won't run after a reboot (Vietnamese typing silently stops).
section "Enabling fcitx5 autostart"
mkdir -p "${HOME}/.config/autostart"
cat > "${HOME}/.config/autostart/fcitx5.desktop" <<'EOF'
[Desktop Entry]
Type=Application
Name=Fcitx 5
Comment=Vietnamese input method (added by macos-theme-setup)
Exec=fcitx5
Icon=fcitx
Terminal=false
X-GNOME-Autostart-enabled=true
EOF
info "Autostart entry written to ~/.config/autostart/fcitx5.desktop"

# ---------------------------------------------------------------------------
# 6. Start fcitx5 now
# ---------------------------------------------------------------------------
section "Starting fcitx5"
pkill -x fcitx5 2>/dev/null || true
sleep 1
(nohup fcitx5 -d --replace >/dev/null 2>&1 &) || true
sleep 2

section "Done"
info "Toggle Vietnamese:  Ctrl + Space"
info "Open Spotlight:     Super + Space (the Windows/Cmd key)"
info ""
info "IMPORTANT: log out and back in once so every app picks up the input"
info "method. After that, Ctrl+Space toggles Vietnamese everywhere."
info "Configure further with:  fcitx5-configtool"
