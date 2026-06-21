#!/usr/bin/env bash
#
# install-launchpad.sh — Add a macOS "Launchpad"-style fullscreen app grid to the
#                        WhiteSur Debian 13 / XFCE (X11) setup.
#
# Why rofi (and not xfce4-appfinder)?
#   xfce4-appfinder can only show a small windowed *list* of apps — it cannot do a
#   fullscreen icon grid, so it looks nothing like macOS. rofi, themed in drun mode,
#   gives a true Launchpad feel: fullscreen, blurred wallpaper, big icon grid,
#   type-to-filter, pagination. It is lightweight and reliable on X11.
#
# This installer:
#   1. Sanity-checks the session and dependencies (rofi, scrot, imagemagick).
#   2. Installs the rofi Launchpad theme (~/.config/rofi/launchpad.rasi).
#   3. Installs the launcher script (~/.local/bin/launchpad) that blurs the screen
#      and opens rofi.
#   4. Installs a custom Launchpad icon and .desktop entry.
#   5. Pins it to the Plank dock (next to Finder).
#   6. Binds Super+R to it (XFCE keyboard shortcut).
#
# Safe to re-run (idempotent).
#
set -euo pipefail

# ---------------------------------------------------------------------------
# Paths & constants
# ---------------------------------------------------------------------------
BIN_DIR="${HOME}/.local/bin"
SCRIPT_PATH="${BIN_DIR}/launchpad"

ROFI_DIR="${HOME}/.config/rofi"
RASI_PATH="${ROFI_DIR}/launchpad.rasi"

ICON_DIR="${HOME}/.local/share/icons"
ICON_PATH="${ICON_DIR}/launchpad.svg"

APPS_DIR="${HOME}/.local/share/applications"
DESKTOP_PATH="${APPS_DIR}/launchpad.desktop"

PLANK_LAUNCHERS="${HOME}/.config/plank/dock1/launchers"
DOCKITEM_PATH="${PLANK_LAUNCHERS}/launchpad.dockitem"
PLANK_SCHEMA="net.launchpad.plank.dock.settings:/net/launchpad/plank/docks/dock1/"

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
section() { printf '\n\033[1;34m==> %s\033[0m\n' "$*"; }
info()    { printf '    %s\n' "$*"; }
warn()    { printf '\033[1;33m    ! %s\033[0m\n' "$*"; }
die()     { printf '\033[1;31m!! %s\033[0m\n' "$*" >&2; exit 1; }

# ---------------------------------------------------------------------------
# 1. Sanity checks + dependencies
# ---------------------------------------------------------------------------
section "Checking session and dependencies"
[ -n "${DISPLAY:-}" ] || die "No \$DISPLAY. Run this from inside your XFCE session."
info "DISPLAY=${DISPLAY}  OK"

# rofi is the launcher; scrot + imagemagick produce the blurred background.
need_pkgs=()
command -v rofi    >/dev/null || need_pkgs+=("rofi")
command -v scrot   >/dev/null || need_pkgs+=("scrot")
command -v convert >/dev/null || need_pkgs+=("imagemagick")
if [ "${#need_pkgs[@]}" -gt 0 ]; then
  info "Installing: ${need_pkgs[*]} (needs sudo)"
  sudo apt-get update -qq || warn "apt update failed, continuing"
  sudo apt-get install -y "${need_pkgs[@]}"
else
  info "rofi, scrot, imagemagick already present."
fi

mkdir -p "${BIN_DIR}" "${ROFI_DIR}" "${ICON_DIR}" "${APPS_DIR}" "${PLANK_LAUNCHERS}"

# ---------------------------------------------------------------------------
# 2. rofi Launchpad theme
# ---------------------------------------------------------------------------
section "Installing the rofi Launchpad theme"
cat > "${RASI_PATH}" <<'RASI'
/* macOS Launchpad style for rofi */
configuration {
    show-icons:          true;
    drun-display-format: "{name}";
    disable-history:     false;
    drun-match-fields:   "name,generic,exec,categories";
}

* {
    fg:       #ffffffff;
    bg:       #00000000;
    selbg:    #ffffff2e;
    entrybg:  #ffffff26;
    placehld: #ffffffbb;
}

window {
    fullscreen:       true;
    background-color:  @bg;
    background-image:  url("/tmp/launchpad-bg.png", both);
    padding:          70px 6% 70px 6%;
}

mainbox {
    background-color: transparent;
    children:        [ inputbar, listview ];
    spacing:         45px;
}

inputbar {
    background-color: @entrybg;
    text-color:       @fg;
    border-radius:    18px;
    padding:          12px 22px;
    margin:           0px 38% 0px 38%;
    children:         [ entry ];
}

entry {
    background-color:    transparent;
    text-color:          @fg;
    placeholder:         "Search";
    placeholder-color:   @placehld;
    horizontal-align:    0.5;
}

listview {
    columns:          7;
    lines:            5;
    spacing:          28px;
    cycle:            true;
    dynamic:          true;
    layout:           vertical;
    background-color: transparent;
    flow:             horizontal;
}

element {
    orientation:      vertical;
    padding:          16px;
    border-radius:    20px;
    spacing:          10px;
    background-color: transparent;
    children:         [ element-icon, element-text ];
}

element selected {
    background-color: @selbg;
}

element-icon {
    size:             92px;
    horizontal-align: 0.5;
    background-color: transparent;
}

element-text {
    text-color:       @fg;
    horizontal-align: 0.5;
    background-color: transparent;
}
RASI
info "Theme written to ${RASI_PATH}"

# ---------------------------------------------------------------------------
# 3. Launcher script (blur screen -> rofi)
# ---------------------------------------------------------------------------
section "Installing the launcher script"
cat > "${SCRIPT_PATH}" <<'SH'
#!/usr/bin/env bash
# macOS-style Launchpad: blur current screen, then show rofi app grid.
BG=/tmp/launchpad-bg.png

# If rofi already open, toggle off
if pgrep -x rofi >/dev/null; then
    pkill -x rofi
    exit 0
fi

# Capture + blur + darken + desaturate the current screen as the background
if command -v scrot >/dev/null && command -v convert >/dev/null; then
    scrot -o "$BG" 2>/dev/null
    convert "$BG" -scale 6% -blur 0x2.5 -resize 1666% \
        -modulate 58,35 -fill "#0e0e12" -colorize 28% "$BG" 2>/dev/null
fi

exec rofi -show drun -theme "$HOME/.config/rofi/launchpad.rasi"
SH
chmod +x "${SCRIPT_PATH}"
info "Script written to ${SCRIPT_PATH}"

# ---------------------------------------------------------------------------
# 4. Launchpad icon + .desktop entry
# ---------------------------------------------------------------------------
section "Installing the Launchpad icon and .desktop entry"
cat > "${ICON_PATH}" <<'SVG'
<?xml version="1.0" encoding="UTF-8"?>
<svg width="1024" height="1024" viewBox="0 0 1024 1024" xmlns="http://www.w3.org/2000/svg">
  <defs>
    <linearGradient id="bg" x1="0" y1="0" x2="0" y2="1">
      <stop offset="0" stop-color="#6e7787"/>
      <stop offset="1" stop-color="#4a525f"/>
    </linearGradient>
  </defs>
  <rect x="64" y="64" width="896" height="896" rx="200" fill="url(#bg)"/>
  <g>
    <rect x="232" y="232" width="160" height="160" rx="36" fill="#ff5f57"/>
    <rect x="432" y="232" width="160" height="160" rx="36" fill="#febc2e"/>
    <rect x="632" y="232" width="160" height="160" rx="36" fill="#28c840"/>
    <rect x="232" y="432" width="160" height="160" rx="36" fill="#1e9bff"/>
    <rect x="432" y="432" width="160" height="160" rx="36" fill="#a55eea"/>
    <rect x="632" y="432" width="160" height="160" rx="36" fill="#ff8a3d"/>
    <rect x="232" y="632" width="160" height="160" rx="36" fill="#26d0ce"/>
    <rect x="432" y="632" width="160" height="160" rx="36" fill="#ff5fa2"/>
    <rect x="632" y="632" width="160" height="160" rx="36" fill="#c8d0dc"/>
  </g>
</svg>
SVG

cat > "${DESKTOP_PATH}" <<DESKTOP
[Desktop Entry]
Version=1.0
Type=Application
Name=Launchpad
Comment=Hien thi tat ca ung dung
Exec=${SCRIPT_PATH}
Icon=${ICON_PATH}
Terminal=false
Categories=Utility;
Keywords=apps;applications;launchpad;all;
StartupNotify=false
DESKTOP

update-desktop-database "${APPS_DIR}" 2>/dev/null || true
gtk-update-icon-cache -f "${ICON_DIR}" 2>/dev/null || true
info "Icon + .desktop installed."

# ---------------------------------------------------------------------------
# 5. Pin to Plank (next to Finder)
# ---------------------------------------------------------------------------
section "Pinning to the Plank dock"
cat > "${DOCKITEM_PATH}" <<DOCK
[PlankDockItemPreferences]
Launcher=file://${DESKTOP_PATH}
DOCK

# Plank stores the dock order in gsettings (NOT a file). Insert launchpad after
# finder if it isn't already in the list.
if command -v gsettings >/dev/null; then
  current="$(gsettings get "${PLANK_SCHEMA}" dock-items 2>/dev/null || echo "")"
  if [ -n "${current}" ] && ! echo "${current}" | grep -q "launchpad.dockitem"; then
    if echo "${current}" | grep -q "finder.dockitem"; then
      new="$(echo "${current}" | sed "s/'finder.dockitem',/'finder.dockitem', 'launchpad.dockitem',/")"
    else
      # no finder -> prepend
      new="$(echo "${current}" | sed "s/^\[/['launchpad.dockitem', /")"
    fi
    gsettings set "${PLANK_SCHEMA}" dock-items "${new}"
    info "Added launchpad.dockitem to dock order."
  else
    info "Already in dock order (or gsettings list empty)."
  fi
else
  warn "gsettings not found; .dockitem written but order not updated."
fi

# ---------------------------------------------------------------------------
# 6. Bind Super+R
# ---------------------------------------------------------------------------
section "Binding Super+R"
if command -v xfconf-query >/dev/null; then
  xfconf-query -c xfce4-keyboard-shortcuts -p "/commands/custom/<Super>r" \
    -n -t string -s "${SCRIPT_PATH}" 2>/dev/null \
    || xfconf-query -c xfce4-keyboard-shortcuts -p "/commands/custom/<Super>r" \
         -s "${SCRIPT_PATH}"
  info "Super+R -> ${SCRIPT_PATH}"
else
  warn "xfconf-query not found; set the shortcut manually in XFCE settings."
fi

# ---------------------------------------------------------------------------
# 7. Restart Plank so the new icon appears
# ---------------------------------------------------------------------------
section "Restarting Plank"
pkill -x plank 2>/dev/null || true
sleep 1
nohup plank >/dev/null 2>&1 &
sleep 2

section "Done"
info "Open Launchpad via the Dock icon (next to Finder) or Super+R."
info "Type to filter, Enter to launch, Esc to close."
