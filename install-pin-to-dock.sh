#!/usr/bin/env bash
#
# install-pin-to-dock.sh — Cài công cụ "Pin to Dock": một picker (rofi, kiểu
#   Spotlight) để chọn app từ danh sách rồi PIN/UNPIN vào Plank dock.
#
# Script này:
#   1. Kiểm tra phiên + cài rofi nếu thiếu.
#   2. Cài script picker (~/.local/bin/pin-to-dock) + theme rofi.
#   3. Tạo file .desktop (hiện trong Launchpad/Spotlight).
#   4. Gán phím tắt Super+P.
#
# An toàn chạy lại nhiều lần (idempotent).
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

BIN_DST="${HOME}/.local/bin/pin-to-dock"
THEME_DST="${HOME}/.config/rofi/pin-to-dock.rasi"
DESKTOP_DST="${HOME}/.local/share/applications/pin-to-dock.desktop"
HOTKEY="<Super>p"

section() { printf '\n\033[1;34m==> %s\033[0m\n' "$*"; }
info()    { printf '    %s\n' "$*"; }
warn()    { printf '\033[1;33m    ! %s\033[0m\n' "$*"; }
die()     { printf '\033[1;31m!! %s\033[0m\n' "$*" >&2; exit 1; }

# ---------------------------------------------------------------------------
# 1. Sanity checks + dependency
# ---------------------------------------------------------------------------
section "Checking session"
[ -n "${DISPLAY:-}" ] || die "No \$DISPLAY. Run this from inside your XFCE session."
info "DISPLAY=${DISPLAY}  OK"

if ! command -v rofi >/dev/null 2>&1; then
  info "Installing rofi (needs sudo)…"
  sudo apt-get update -qq || warn "apt update failed, continuing"
  sudo apt-get install -y rofi
fi

mkdir -p "${HOME}/.local/bin" "${HOME}/.config/rofi" \
         "${HOME}/.local/share/applications"

# ---------------------------------------------------------------------------
# 2. Install the picker script + theme
# ---------------------------------------------------------------------------
section "Installing the picker + theme"
install -m 0755 "${SCRIPT_DIR}/bin/pin-to-dock" "${BIN_DST}"
install -m 0644 "${SCRIPT_DIR}/config/pin-to-dock.rasi" "${THEME_DST}"
info "Script -> ${BIN_DST}"
info "Theme  -> ${THEME_DST}"

# ---------------------------------------------------------------------------
# 3. Desktop entry (so it shows in Launchpad / Spotlight)
# ---------------------------------------------------------------------------
section "Creating the application entry"
cat > "${DESKTOP_DST}" <<EOF
[Desktop Entry]
Type=Application
Name=Pin to Dock
GenericName=Dock pinner
Comment=Chọn app từ danh sách để pin/unpin vào Plank dock
Exec=${BIN_DST}
Icon=list-add
Terminal=false
Categories=Utility;
EOF
update-desktop-database "${HOME}/.local/share/applications" 2>/dev/null || true
info "Entry -> ${DESKTOP_DST}"

# ---------------------------------------------------------------------------
# 4. Bind Super+P
# ---------------------------------------------------------------------------
section "Binding ${HOTKEY}"
EXISTING="$(xfconf-query -c xfce4-keyboard-shortcuts -p "/commands/custom/${HOTKEY}" 2>/dev/null || true)"
if [ -n "${EXISTING}" ] && [ "${EXISTING}" != "${BIN_DST}" ]; then
  warn "${HOTKEY} đang là: ${EXISTING} — sẽ ghi đè bằng pin-to-dock."
fi
xfconf-query -c xfce4-keyboard-shortcuts -p "/commands/custom/${HOTKEY}" -r 2>/dev/null || true
xfconf-query -c xfce4-keyboard-shortcuts -p "/commands/custom/${HOTKEY}" -n -t string -s "${BIN_DST}"
info "${HOTKEY} -> pin-to-dock"

section "Done"
info "Mở: Super+P, hoặc gõ 'Pin to Dock' trong Launchpad/Spotlight."
info "App đã pin có dấu ✓; chọn lại để gỡ."
