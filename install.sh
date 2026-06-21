#!/usr/bin/env bash
#
# install.sh — One-command installer that reproduces a macOS (WhiteSur) look
#              on Debian 13 / XFCE (X11).
#
# This installer:
#   1. Sanity-checks the session and required commands.
#   2. Installs apt dependencies (needs sudo).
#   3. Clones & installs the vinceliuice WhiteSur GTK / icon / cursor themes.
#   4. Installs the SF Pro fonts.
#   5. Installs the Finder + Apple-logo icons.
#   6. Installs the WhiteSur wallpaper.
#   7. Installs the WhiteSur-Light Plank theme.
#   8. Calls the sibling apply-settings.sh to apply every XFCE/Plank setting.
#
# It is safe to re-run (idempotent). Optional steps are guarded so a single
# failure does not abort the whole run.
#
# Optional flag:
#   --with-global-menu   Also install a global (macOS-style) menu bar plugin.
#
set -euo pipefail

# ---------------------------------------------------------------------------
# Paths & constants
# ---------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD_DIR="${HOME}/.cache/macos-theme-build"

FONTS_DIR="${HOME}/.local/share/fonts"
ICONS_DIR="${HOME}/.local/share/icons"
BACKGROUNDS_DIR="${HOME}/.local/share/backgrounds"
PLANK_THEMES_DIR="${HOME}/.local/share/plank/themes"

WHITESUR_GTK_REPO="https://github.com/vinceliuice/WhiteSur-gtk-theme"
WHITESUR_ICON_REPO="https://github.com/vinceliuice/WhiteSur-icon-theme"
WHITESUR_CURSOR_REPO="https://github.com/vinceliuice/WhiteSur-cursors"
WHITESUR_WALLPAPER_REPO="https://github.com/vinceliuice/WhiteSur-wallpapers"

WHITESUR_GTK_DIR="${BUILD_DIR}/WhiteSur-gtk-theme"
WHITESUR_ICON_DIR="${BUILD_DIR}/WhiteSur-icon-theme"
WHITESUR_CURSOR_DIR="${BUILD_DIR}/WhiteSur-cursors"
WHITESUR_WALLPAPER_DIR="${BUILD_DIR}/WhiteSur-wallpapers"

SF_FONT_BASE="https://github.com/sahibjotsaggu/San-Francisco-Pro-Fonts/raw/master"
SF_FONTS=(
  "SF-Pro-Display-Regular"
  "SF-Pro-Display-Medium"
  "SF-Pro-Display-Semibold"
  "SF-Pro-Text-Regular"
  "SF-Pro-Text-Medium"
)

WITH_GLOBAL_MENU=0

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
section() { printf '\n\033[1;34m==> %s\033[0m\n' "$*"; }
info()    { printf '    %s\n' "$*"; }
warn()    { printf '\033[1;33m[warn]\033[0m %s\n' "$*" >&2; }
ok()      { printf '\033[1;32m[ ok ]\033[0m %s\n' "$*"; }

have() { command -v "$1" >/dev/null 2>&1; }

# Run a non-critical block but never abort the whole installer on failure.
guard() {
  if "$@"; then
    return 0
  else
    warn "step failed (continuing): $*"
    return 0
  fi
}

# ---------------------------------------------------------------------------
# Argument parsing
# ---------------------------------------------------------------------------
for arg in "$@"; do
  case "$arg" in
    --with-global-menu) WITH_GLOBAL_MENU=1 ;;
    -h|--help)
      cat <<EOF
Usage: ${0##*/} [--with-global-menu]

  --with-global-menu   Additionally install the XFCE appmenu plugin and a
                       global macOS-style menu bar in the top panel.
                       NOTE: Chrome/Chromium/Electron apps do NOT export
                       their menus on Linux; GTK apps & Firefox do.
EOF
      exit 0
      ;;
    *) warn "unknown argument: $arg" ;;
  esac
done

# ---------------------------------------------------------------------------
# 1. Sanity checks
# ---------------------------------------------------------------------------
section "Sanity checks"

if [[ "${XDG_CURRENT_DESKTOP:-}" != *XFCE* ]]; then
  warn "XDG_CURRENT_DESKTOP is '${XDG_CURRENT_DESKTOP:-unset}', expected to contain 'XFCE'."
  warn "This installer targets XFCE on X11. Continuing anyway, but results may differ."
else
  ok "XFCE session detected."
fi

if [[ "${XDG_SESSION_TYPE:-}" == "wayland" ]]; then
  warn "Wayland session detected; this installer targets X11. xrandr/xfconf behaviour may differ."
fi

# Commands we rely on directly in this script. (Theme installers pull the rest.)
REQUIRED_CMDS=(git curl)
MISSING=()
for c in "${REQUIRED_CMDS[@]}"; do
  have "$c" || MISSING+=("$c")
done
if ((${#MISSING[@]})); then
  info "Missing required commands (will try to apt-install): ${MISSING[*]}"
fi

if ! have sudo; then
  warn "sudo not found — apt dependency installation will be skipped."
  warn "Make sure git, plank, libglib2.0-bin, libgtk-3-bin and sassc are installed."
fi

mkdir -p "$BUILD_DIR" "$FONTS_DIR" "$ICONS_DIR" "$BACKGROUNDS_DIR" "$PLANK_THEMES_DIR"

# ---------------------------------------------------------------------------
# 2. apt dependencies
# ---------------------------------------------------------------------------
section "Installing apt dependencies (requires sudo / root)"

APT_PACKAGES=(git plank libglib2.0-bin libgtk-3-bin sassc curl)

if ((WITH_GLOBAL_MENU)); then
  APT_PACKAGES+=(xfce4-appmenu-plugin appmenu-gtk3-module appmenu-gtk-module-common)
fi

if have sudo && have apt-get; then
  info "Packages: ${APT_PACKAGES[*]}"
  info "These require root; you may be prompted for your password."
  guard sudo apt-get update
  # Install all at once; --no-install-recommends keeps it lean but we keep
  # recommends off only for the menu extras to avoid surprises. Continue on error.
  guard sudo apt-get install -y "${APT_PACKAGES[@]}"
  ok "apt dependencies processed."
else
  warn "Skipping apt step (need both sudo and apt-get)."
fi

# ---------------------------------------------------------------------------
# 3. Clone & install vinceliuice themes
# ---------------------------------------------------------------------------
section "Installing WhiteSur GTK / icon / cursor themes"

clone_or_update() {
  local repo="$1" dir="$2"
  if [[ -d "$dir/.git" ]]; then
    info "Updating $(basename "$dir") ..."
    guard git -C "$dir" pull --ff-only
  else
    info "Cloning $(basename "$dir") ..."
    guard git clone --depth=1 "$repo" "$dir"
  fi
}

# --- GTK theme (keep the clone; we need other/plank/theme-Light/dock.theme) ---
clone_or_update "$WHITESUR_GTK_REPO" "$WHITESUR_GTK_DIR"
if [[ -x "$WHITESUR_GTK_DIR/install.sh" ]]; then
  info "Running WhiteSur GTK install.sh (Light, normal opacity, normal alt) ..."
  guard "$WHITESUR_GTK_DIR/install.sh" -c light -o normal -a normal
  ok "WhiteSur GTK theme installed."
else
  warn "WhiteSur GTK install.sh not found/executable; skipping GTK theme install."
fi

# --- Icon theme ---
clone_or_update "$WHITESUR_ICON_REPO" "$WHITESUR_ICON_DIR"
if [[ -x "$WHITESUR_ICON_DIR/install.sh" ]]; then
  info "Running WhiteSur icon install.sh ..."
  guard "$WHITESUR_ICON_DIR/install.sh"
  ok "WhiteSur icon theme installed."
else
  warn "WhiteSur icon install.sh not found/executable; skipping icon theme install."
fi

# --- Cursors ---
clone_or_update "$WHITESUR_CURSOR_REPO" "$WHITESUR_CURSOR_DIR"
if [[ -x "$WHITESUR_CURSOR_DIR/install.sh" ]]; then
  info "Running WhiteSur cursors install.sh ..."
  guard "$WHITESUR_CURSOR_DIR/install.sh"
  ok "WhiteSur cursors installed (full effect after logout/login)."
else
  warn "WhiteSur cursors install.sh not found/executable; skipping cursors install."
fi

# ---------------------------------------------------------------------------
# 4. Fonts: SF Pro
# ---------------------------------------------------------------------------
section "Installing SF Pro fonts"

mkdir -p "$FONTS_DIR"
FONT_DOWNLOADED=0
for name in "${SF_FONTS[@]}"; do
  dest="${FONTS_DIR}/${name}.otf"
  if [[ -s "$dest" ]]; then
    info "Already present: ${name}.otf"
    continue
  fi
  info "Downloading ${name}.otf ..."
  if curl -fsSL "${SF_FONT_BASE}/${name}.otf" -o "$dest"; then
    FONT_DOWNLOADED=1
    ok "Fetched ${name}.otf"
  else
    warn "Failed to download ${name}.otf (continuing)."
    rm -f "$dest"
  fi
done

if ((FONT_DOWNLOADED)) && have fc-cache; then
  guard fc-cache -f "$FONTS_DIR"
  ok "Font cache refreshed."
fi

# ---------------------------------------------------------------------------
# 5. Finder + Apple-logo icons
# ---------------------------------------------------------------------------
section "Installing Finder and Apple-logo icons"

install_asset() {
  local src="$1" dest="$2"
  if [[ -f "$src" ]]; then
    mkdir -p "$(dirname "$dest")"
    cp -f "$src" "$dest"
    ok "Installed $(basename "$dest")"
  else
    warn "Bundled asset missing: $src (skipping)."
  fi
}

install_asset "${SCRIPT_DIR}/assets/finder.svg"     "${ICONS_DIR}/macOS-extra/finder.svg"
install_asset "${SCRIPT_DIR}/assets/apple-logo.svg" "${ICONS_DIR}/apple-logo.svg"

# ---------------------------------------------------------------------------
# 6. Wallpaper
# ---------------------------------------------------------------------------
section "Installing WhiteSur wallpaper"

clone_or_update "$WHITESUR_WALLPAPER_REPO" "$WHITESUR_WALLPAPER_DIR"
WALL_SRC="${WHITESUR_WALLPAPER_DIR}/4k/WhiteSur-light.jpg"
WALL_DEST="${BACKGROUNDS_DIR}/WhiteSur-light.jpg"
if [[ -f "$WALL_SRC" ]]; then
  mkdir -p "$BACKGROUNDS_DIR"
  cp -f "$WALL_SRC" "$WALL_DEST"
  ok "Wallpaper installed to ${WALL_DEST}"
else
  warn "Wallpaper source not found at ${WALL_SRC} (skipping)."
fi

# ---------------------------------------------------------------------------
# 7. WhiteSur-Light Plank theme
# ---------------------------------------------------------------------------
section "Installing WhiteSur-Light Plank theme"

PLANK_THEME_SRC="${WHITESUR_GTK_DIR}/other/plank/theme-Light/dock.theme"
PLANK_THEME_DEST_DIR="${PLANK_THEMES_DIR}/WhiteSur-Light"
PLANK_THEME_DEST="${PLANK_THEME_DEST_DIR}/dock.theme"
if [[ -f "$PLANK_THEME_SRC" ]]; then
  mkdir -p "$PLANK_THEME_DEST_DIR"
  cp -f "$PLANK_THEME_SRC" "$PLANK_THEME_DEST"
  ok "Plank theme installed to ${PLANK_THEME_DEST}"
else
  warn "Plank theme source not found at ${PLANK_THEME_SRC} (skipping)."
fi

# ---------------------------------------------------------------------------
# 8. Apply all settings via the sibling script
# ---------------------------------------------------------------------------
section "Applying XFCE / Plank settings"

APPLY="${SCRIPT_DIR}/apply-settings.sh"
APPLY_ARGS=()
((WITH_GLOBAL_MENU)) && APPLY_ARGS+=(--with-global-menu)

if [[ -f "$APPLY" ]]; then
  chmod +x "$APPLY" 2>/dev/null || true
  info "Running apply-settings.sh ${APPLY_ARGS[*]:-}"
  # Let apply-settings.sh decide its own exit behaviour; do not let a failure
  # here mask the rest of the summary.
  guard bash "$APPLY" "${APPLY_ARGS[@]}"
else
  warn "apply-settings.sh not found next to this script (${APPLY})."
  warn "Settings were NOT applied. Run apply-settings.sh manually once it exists."
fi

# ---------------------------------------------------------------------------
# 9. Final summary
# ---------------------------------------------------------------------------
section "Done"
cat <<EOF
Installed:
  - WhiteSur GTK theme (Light), icon theme, and cursors
  - SF Pro fonts            -> ${FONTS_DIR}
  - Finder/Apple icons      -> ${ICONS_DIR}
  - Wallpaper               -> ${WALL_DEST}
  - Plank theme             -> ${PLANK_THEME_DEST}
  - Build/cache dir         -> ${BUILD_DIR}

Next steps:
  * Log out and back in to finalize the cursor theme and let some apps pick
    up the new GTK theme and fonts.
  * Optional: run ./optimize.sh to make things lighter & smoother (trims
    autostart, enables zram, tunes memory) — recommended on low-RAM machines
    or inside VirtualBox. See docs/optimization.md.
EOF

if ((WITH_GLOBAL_MENU)); then
  cat <<EOF

Global menu:
  The --with-global-menu option installed the appmenu plugin and added a
  global menu bar to the top panel.
  WARNING: Chrome/Chromium/Electron apps do NOT export their menus on Linux
           (a platform limitation). GTK applications and Firefox DO export
           their menus and will work with the global menu bar.
EOF
fi

ok "macOS (WhiteSur) look installed."
