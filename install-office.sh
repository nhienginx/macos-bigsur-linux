#!/usr/bin/env bash
#
# install-office.sh — Cài bộ soạn thảo văn phòng giống MS Office cho bản dựng
#                     WhiteSur Debian 13 / XFCE (X11), kèm icon kiểu macOS.
#
# Script này:
#   1. Kiểm tra phiên + phụ thuộc.
#   2. Cài ONLYOFFICE Desktop Editors từ .deb chính chủ (không có trong apt).
#   3. Cài font Microsoft (Times New Roman, Arial…) + Carlito/Caladea
#      (tương thích Calibri/Cambria) — cần cho văn bản pháp luật (Nghị định 30).
#   4. Đặt icon "Microsoft Office" kiểu squircle macOS (assets/ms-office.svg)
#      cho launcher, qua một bản .desktop override trong ~/.local/share.
#   5. Ghim vào Dock (Plank) và khởi động lại Plank.
#
# An toàn chạy lại nhiều lần (idempotent).
#
set -euo pipefail

# ---------------------------------------------------------------------------
# Paths & constants
# ---------------------------------------------------------------------------
ONLYOFFICE_DEB_URL="https://download.onlyoffice.com/install/desktop/editors/linux/onlyoffice-desktopeditors_amd64.deb"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ASSETS_DIR="${SCRIPT_DIR}/assets"

BUILD_DIR="${HOME}/.cache/macos-theme-build"
DEB_PATH="${BUILD_DIR}/onlyoffice-desktopeditors_amd64.deb"

SYS_DESKTOP="/usr/share/applications/onlyoffice-desktopeditors.desktop"
USER_DESKTOP="${HOME}/.local/share/applications/onlyoffice-desktopeditors.desktop"
ICON_DST="${HOME}/.local/share/icons/ms-office.svg"

PLANK_LAUNCHERS="${HOME}/.config/plank/dock1/launchers"
DOCKITEM="${PLANK_LAUNCHERS}/onlyoffice-desktopeditors.dockitem"
PLANK_SCHEMA="net.launchpad.plank.dock.settings:/net/launchpad/plank/docks/dock1/"

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
command -v wget >/dev/null || die "wget is required."
command -v gsettings >/dev/null || die "gsettings is required (for Plank)."
info "DISPLAY=${DISPLAY}  OK"
mkdir -p "${BUILD_DIR}" "${PLANK_LAUNCHERS}" \
         "${HOME}/.local/share/applications" "${HOME}/.local/share/icons"

# ---------------------------------------------------------------------------
# 2. Install ONLYOFFICE
# ---------------------------------------------------------------------------
section "Installing ONLYOFFICE Desktop Editors"
if command -v onlyoffice-desktopeditors >/dev/null 2>&1; then
  info "Already installed: $(dpkg -l onlyoffice-desktopeditors 2>/dev/null | awk '/^ii/{print $3}')"
else
  if [ ! -s "${DEB_PATH}" ]; then
    info "Downloading .deb (~350MB)…"
    wget -q -O "${DEB_PATH}" "${ONLYOFFICE_DEB_URL}" \
      || die "Download failed. Check your connection and re-run."
  fi
  info "Installing .deb (needs sudo; apt resolves dependencies)…"
  sudo apt-get install -y "${DEB_PATH}"
fi

# ---------------------------------------------------------------------------
# 3. Microsoft fonts (Times New Roman…) + Calibri/Cambria substitutes
# ---------------------------------------------------------------------------
section "Installing Microsoft-compatible fonts"
if fc-list | grep -qi "Times New Roman"; then
  info "Times New Roman already present."
else
  info "Accepting the msttcorefonts EULA and installing…"
  echo "ttf-mscorefonts-installer msttcorefonts/accepted-mscorefonts-eula select true" \
    | sudo debconf-set-selections
  sudo DEBIAN_FRONTEND=noninteractive apt-get install -y \
    ttf-mscorefonts-installer fonts-crosextra-carlito fonts-crosextra-caladea \
    || warn "Font install hit an issue (often a SourceForge mirror); re-run to retry."
  sudo fc-cache -f
fi

# ---------------------------------------------------------------------------
# 4. macOS-style "Microsoft Office" icon
# ---------------------------------------------------------------------------
section "Applying the macOS-style Office icon"
[ -f "${ASSETS_DIR}/ms-office.svg" ] || die "Missing ${ASSETS_DIR}/ms-office.svg"
[ -f "${SYS_DESKTOP}" ] || die "Missing ${SYS_DESKTOP} (is ONLYOFFICE installed?)"

cp "${ASSETS_DIR}/ms-office.svg" "${ICON_DST}"
info "Icon -> ${ICON_DST}"

# Override .desktop: copy the system one verbatim, swap only the Icon= line.
sed "s|^Icon=.*|Icon=${ICON_DST}|" "${SYS_DESKTOP}" > "${USER_DESKTOP}"
info "Override .desktop -> ${USER_DESKTOP}"

update-desktop-database "${HOME}/.local/share/applications" 2>/dev/null || true
gtk-update-icon-cache -f "${HOME}/.local/share/icons" 2>/dev/null || true

# ---------------------------------------------------------------------------
# 5. Pin to the Plank dock
# ---------------------------------------------------------------------------
section "Pinning to the Plank dock"
cat > "${DOCKITEM}" <<EOF
[PlankDockItemPreferences]
Launcher=file://${USER_DESKTOP}
EOF
info "dockitem -> ${DOCKITEM}"

# Insert into the dock-items array (before trash) only if not already there.
CURRENT="$(gsettings get ${PLANK_SCHEMA} dock-items)"
if printf '%s' "${CURRENT}" | grep -q "onlyoffice-desktopeditors.dockitem"; then
  info "Already in the dock order."
else
  NEW="$(printf '%s' "${CURRENT}" \
    | sed "s/'trash.dockitem'/'onlyoffice-desktopeditors.dockitem', 'trash.dockitem'/")"
  # Fallback: if there's no trash item, just append before the closing bracket.
  if [ "${NEW}" = "${CURRENT}" ]; then
    NEW="$(printf '%s' "${CURRENT}" | sed "s/]$/, 'onlyoffice-desktopeditors.dockitem']/")"
  fi
  gsettings set ${PLANK_SCHEMA} dock-items "${NEW}"
  info "Added to the dock order."
fi

# ---------------------------------------------------------------------------
# 6. Restart Plank
# ---------------------------------------------------------------------------
section "Restarting Plank"
pkill -x plank 2>/dev/null || true
sleep 1
nohup plank >/dev/null 2>&1 &
sleep 2
pgrep -x plank >/dev/null && info "Plank is running (pid $(pgrep -x plank))" \
  || warn "Plank didn't come back up; start it manually with: plank &"

section "Done"
info "Open ONLYOFFICE from the dock (the colorful Office tile) or run:"
info "  onlyoffice-desktopeditors"
info "Tip for legal docs: Times New Roman 13–14pt, A4, save as .docx."
