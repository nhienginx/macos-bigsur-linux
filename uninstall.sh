#!/usr/bin/env bash
#
# uninstall.sh — Revert the macOS (WhiteSur) look back to sane XFCE defaults
#                on Debian 13 / XFCE (X11), WITHOUT destroying user files.
#
# This is intentionally conservative. It:
#   1. Resets xfwm4 (window manager) theme, button layout, title alignment/font.
#   2. Resets xsettings GTK theme / icons / cursor / font to reasonable
#      defaults (clearly flagged as GUESSES, since the original is unknown).
#   3. Stops Plank and removes its autostart entry (leaves Plank installed).
#   4. Resets ONLY the top-panel "apple" Whisker button icon; it does NOT
#      tear the panel down — guidance is printed instead.
#   5. Optionally re-enables conky autostart (un-hides it).
#
# What it does NOT do (by design — see the closing notes):
#   * It does not delete the WhiteSur GTK/icon/cursor themes, fonts, wallpaper,
#     Finder/Apple icons, or the Plank theme. Those are shared resources you
#     may want to keep; manual removal instructions are printed at the end.
#
# It is safe to re-run (idempotent). Optional steps are guarded so a single
# failure does not abort the whole run.
#
# Flags:
#   --restore-conky      Re-enable conky autostart (set Hidden=false) without
#                        prompting.
#   --no-restore-conky   Never touch conky autostart (skip the prompt).
#   -y, --yes            Assume "yes" to interactive prompts (non-interactive).
#   -h, --help           Show usage.
#
set -euo pipefail

# ---------------------------------------------------------------------------
# Paths & constants
# ---------------------------------------------------------------------------
AUTOSTART_DIR="${HOME}/.config/autostart"
PLANK_AUTOSTART="${AUTOSTART_DIR}/plank.desktop"
CONKY_AUTOSTART="${AUTOSTART_DIR}/conky.desktop"
ICONS_DIR="${HOME}/.local/share/icons"
FONTS_DIR="${HOME}/.local/share/fonts"
BACKGROUNDS_DIR="${HOME}/.local/share/backgrounds"
PLANK_THEMES_DIR="${HOME}/.local/share/plank/themes"

# Defaults we revert to. These are best-effort "sane defaults", not a capture
# of the user's pre-install state (which we do not have).
DEFAULT_WM_THEME="Default"
DEFAULT_BUTTON_LAYOUT="O|HMC"
DEFAULT_GTK_THEME="Adwaita"
DEFAULT_ICON_THEME="Adwaita"
DEFAULT_CURSOR_THEME="Adwaita"
DEFAULT_FONT_NAME="Sans 10"

RESTORE_CONKY="ask"   # ask | yes | no
ASSUME_YES=0

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
section() { printf '\n\033[1;34m==> %s\033[0m\n' "$*"; }
info()    { printf '    %s\n' "$*"; }
warn()    { printf '\033[1;33m[warn]\033[0m %s\n' "$*" >&2; }
ok()      { printf '\033[1;32m[ ok ]\033[0m %s\n' "$*"; }
guess()   { printf '\033[1;35m[guess]\033[0m %s\n' "$*"; }

have() { command -v "$1" >/dev/null 2>&1; }

# Run a non-critical block but never abort the whole script on failure.
guard() {
  if "$@"; then
    return 0
  else
    warn "step failed (continuing): $*"
    return 0
  fi
}

# xfconf-query wrapper that only runs when the tool exists.
xq() {
  if have xfconf-query; then
    guard xfconf-query "$@"
  else
    warn "xfconf-query not available; cannot run: xfconf-query $*"
  fi
}

# ---------------------------------------------------------------------------
# Argument parsing
# ---------------------------------------------------------------------------
for arg in "$@"; do
  case "$arg" in
    --restore-conky)    RESTORE_CONKY="yes" ;;
    --no-restore-conky) RESTORE_CONKY="no" ;;
    -y|--yes)           ASSUME_YES=1 ;;
    -h|--help)
      cat <<EOF
Usage: ${0##*/} [options]

Revert the macOS (WhiteSur) look back to sane XFCE defaults without deleting
any installed themes, icons, fonts or wallpapers.

Options:
  --restore-conky      Re-enable conky autostart (Hidden=false) without asking.
  --no-restore-conky   Do not touch conky autostart; skip the prompt.
  -y, --yes            Assume "yes" to any interactive prompt.
  -h, --help           Show this help and exit.
EOF
      exit 0
      ;;
    *) warn "unknown argument: $arg" ;;
  esac
done

# ---------------------------------------------------------------------------
# 0. Sanity checks
# ---------------------------------------------------------------------------
section "Sanity checks"

if [[ "${XDG_CURRENT_DESKTOP:-}" != *XFCE* ]]; then
  warn "XDG_CURRENT_DESKTOP is '${XDG_CURRENT_DESKTOP:-unset}', expected to contain 'XFCE'."
  warn "This uninstaller targets XFCE on X11. Continuing anyway."
else
  ok "XFCE session detected."
fi

have xfconf-query || warn "xfconf-query not found — xfwm4/xsettings resets will be skipped."

info "This will revert window-manager + GTK look to defaults. It will NOT"
info "delete any installed themes, icons, fonts, wallpapers or Plank itself."

# ---------------------------------------------------------------------------
# 1. Reset xfwm4 (window manager) decorations
# ---------------------------------------------------------------------------
section "Reverting xfwm4 (window decorations) to defaults"

info "theme            -> ${DEFAULT_WM_THEME}"
xq -c xfwm4 -p /general/theme -s "$DEFAULT_WM_THEME"

info "button_layout    -> ${DEFAULT_BUTTON_LAYOUT}  (close on right, menu/min/max on right)"
xq -c xfwm4 -p /general/button_layout -s "$DEFAULT_BUTTON_LAYOUT"

# Title alignment: default XFCE value is "center". Reset to that.
info "title_alignment  -> center (XFCE default)"
xq -c xfwm4 -p /general/title_alignment -s "center"

# Clear the custom title font so xfwm4 falls back to the xsettings/default font.
# Resetting (removing) the property is the cleanest "back to default".
info "title_font       -> cleared (fall back to default)"
if have xfconf-query; then
  if xfconf-query -c xfwm4 -p /general/title_font >/dev/null 2>&1; then
    guard xfconf-query -c xfwm4 -p /general/title_font -r
  else
    info "title_font was not set; nothing to clear."
  fi
fi

ok "xfwm4 reverted."

# ---------------------------------------------------------------------------
# 2. Reset xsettings (GTK theme / icons / cursor / font)
# ---------------------------------------------------------------------------
section "Reverting xsettings (GTK theme / icons / cursor / font)"

warn "The values below are GUESSES at 'sane defaults'. We do not have a record"
warn "of your pre-install settings, so adjust them in:"
warn "  Settings Manager -> Appearance / Window Manager / Mouse and Touchpad."

if have xfconf-query; then
  # GTK theme: prefer Adwaita; warn if it does not appear installed.
  if [[ -d /usr/share/themes/Adwaita || -d "${HOME}/.themes/Adwaita" ]]; then
    guess "ThemeName        -> ${DEFAULT_GTK_THEME}"
  else
    warn "Adwaita theme dir not found under /usr/share/themes; setting it anyway."
    guess "ThemeName        -> ${DEFAULT_GTK_THEME} (may not be installed)"
  fi
  xq -c xsettings -p /Net/ThemeName -s "$DEFAULT_GTK_THEME"

  guess "IconThemeName    -> ${DEFAULT_ICON_THEME}"
  xq -c xsettings -p /Net/IconThemeName -s "$DEFAULT_ICON_THEME"

  guess "CursorThemeName  -> ${DEFAULT_CURSOR_THEME}"
  xq -c xsettings -p /Gtk/CursorThemeName -s "$DEFAULT_CURSOR_THEME"

  guess "FontName         -> ${DEFAULT_FONT_NAME}"
  xq -c xsettings -p /Gtk/FontName -s "$DEFAULT_FONT_NAME"

  ok "xsettings reverted (these are guesses — fine-tune in Appearance settings)."
else
  warn "Skipping xsettings reset (xfconf-query missing)."
fi

# ---------------------------------------------------------------------------
# 3. Stop Plank and remove its autostart
# ---------------------------------------------------------------------------
section "Stopping Plank and removing its autostart"

if have pkill && pgrep -x plank >/dev/null 2>&1; then
  info "Stopping running Plank instance ..."
  guard pkill -x plank
  ok "Plank stopped."
else
  info "Plank does not appear to be running."
fi

if [[ -f "$PLANK_AUTOSTART" ]]; then
  info "Removing autostart entry: ${PLANK_AUTOSTART}"
  guard rm -f "$PLANK_AUTOSTART"
  ok "Plank autostart removed (Plank itself is left installed)."
else
  info "No Plank autostart entry found at ${PLANK_AUTOSTART}."
fi

info "Note: Plank's own config (${HOME}/.config/plank) and the WhiteSur-Light"
info "Plank theme were left in place. Remove them manually if you wish."

# ---------------------------------------------------------------------------
# 4. Reset ONLY the top-panel apple button icon (non-destructive)
# ---------------------------------------------------------------------------
section "Resetting the top-panel 'apple' menu button icon"

# We deliberately do NOT rebuild or remove panel-1. Tearing the panel down is
# destructive and easy to get wrong; instead we only clear the custom Whisker
# button icon so it stops showing the Apple logo, and we print guidance.
if have xfconf-query; then
  # Find any whiskermenu plugin instances and reset their button icon/title.
  mapfile -t WHISKER_PLUGINS < <(
    xfconf-query -c xfce4-panel -l 2>/dev/null \
      | grep -E '/plugins/plugin-[0-9]+$' || true
  )
  RESET_ANY=0
  for prop in "${WHISKER_PLUGINS[@]}"; do
    ptype="$(xfconf-query -c xfce4-panel -p "$prop" 2>/dev/null || true)"
    if [[ "$ptype" == "whiskermenu" ]]; then
      id="${prop##*-}"
      info "Resetting whiskermenu plugin ${id} button icon/title ..."
      # Restore a normal menu icon and re-enable the button title.
      guard xfconf-query -c xfce4-panel -p "/plugins/plugin-${id}/button-icon" \
        -s "org.xfce.panel.whiskermenu"
      # button-title: clear back to default by resetting if present.
      if xfconf-query -c xfce4-panel -p "/plugins/plugin-${id}/show-button-title" >/dev/null 2>&1; then
        guard xfconf-query -c xfce4-panel -p "/plugins/plugin-${id}/show-button-title" -s true
      fi
      RESET_ANY=1
    fi
  done
  if ((RESET_ANY)); then
    ok "Whisker menu button icon reset to a default icon."
    if have xfce4-panel; then
      info "Restarting panel to apply the icon change ..."
      guard xfce4-panel -r
    fi
  else
    info "No whiskermenu plugin found in the panel; nothing to reset."
  fi
else
  warn "Skipping panel button reset (xfconf-query missing)."
fi

info ""
info "The top panel layout itself was left intact (this uninstaller does not"
info "rebuild or delete panels). To return to a stock XFCE panel you can run:"
info "    xfce4-panel --quit ; pkill xfconfd"
info "    rm -rf ${HOME}/.config/xfce4/panel ${HOME}/.config/xfce4/xfconf/xfce-perchannel-xml/xfce4-panel.xml"
info "    xfce4-panel &"
info "  (Only do that if you want a full panel reset — it is destructive to"
info "   the current panel configuration.)"

# ---------------------------------------------------------------------------
# 5. Optionally re-enable conky autostart
# ---------------------------------------------------------------------------
section "Conky autostart"

unhide_conky() {
  if [[ ! -f "$CONKY_AUTOSTART" ]]; then
    info "No conky autostart entry found at ${CONKY_AUTOSTART}; nothing to do."
    return 0
  fi
  if grep -qi '^Hidden=true' "$CONKY_AUTOSTART" 2>/dev/null; then
    info "Re-enabling conky autostart (Hidden=true -> false) ..."
    guard sed -i 's/^Hidden=true/Hidden=false/I' "$CONKY_AUTOSTART"
    ok "Conky autostart re-enabled."
  else
    info "Conky autostart is not disabled (no 'Hidden=true'); leaving as-is."
  fi
}

case "$RESTORE_CONKY" in
  yes)
    unhide_conky
    ;;
  no)
    info "Skipping conky autostart (per --no-restore-conky)."
    ;;
  ask)
    if [[ ! -f "$CONKY_AUTOSTART" ]]; then
      info "No conky autostart entry found; nothing to ask about."
    elif ((ASSUME_YES)); then
      unhide_conky
    elif [[ -t 0 ]]; then
      printf '    Re-enable conky autostart now? [y/N] '
      read -r reply || reply=""
      case "$reply" in
        [yY]|[yY][eE][sS]) unhide_conky ;;
        *) info "Leaving conky autostart unchanged." ;;
      esac
    else
      info "Non-interactive shell; not changing conky autostart."
      info "Re-run with --restore-conky to re-enable it."
    fi
    ;;
esac

# ---------------------------------------------------------------------------
# 6. Final summary / manual-removal guidance
# ---------------------------------------------------------------------------
section "Done — reverted to XFCE defaults (non-destructively)"

cat <<EOF
Reverted:
  - xfwm4 theme/button-layout/title-alignment/title-font -> defaults
  - xsettings GTK theme / icons / cursor / font          -> GUESSED defaults
  - Plank stopped + autostart removed (Plank still installed)
  - Top-panel apple button icon reset (panel layout left intact)

NOT removed (kept on purpose — delete manually if you want them gone):
  - WhiteSur GTK theme:     ${HOME}/.themes/WhiteSur*           (and /usr/share/themes/WhiteSur*)
  - WhiteSur icon theme:    ${ICONS_DIR}/WhiteSur*
  - WhiteSur cursors:       ${ICONS_DIR}/WhiteSur-cursors  (and /usr/share/icons/WhiteSur-cursors)
  - SF Pro fonts:           ${FONTS_DIR}/SF-Pro-*.otf      (then: fc-cache -f)
  - Finder / Apple icons:   ${ICONS_DIR}/macOS-extra/finder.svg , ${ICONS_DIR}/apple-logo.svg
  - Wallpaper:              ${BACKGROUNDS_DIR}/WhiteSur-light.jpg
  - Plank theme:            ${PLANK_THEMES_DIR}/WhiteSur-Light
  - Build/cache:            ${HOME}/.cache/macos-theme-build

Example manual cleanup (review before running!):
  rm -rf ${HOME}/.themes/WhiteSur* ${ICONS_DIR}/WhiteSur* "${ICONS_DIR}/macOS-extra"
  rm -f  ${ICONS_DIR}/apple-logo.svg ${BACKGROUNDS_DIR}/WhiteSur-light.jpg
  rm -rf "${PLANK_THEMES_DIR}/WhiteSur-Light" ${HOME}/.cache/macos-theme-build
  fc-cache -f

Notes:
  * The xsettings values restored above are GUESSES. Open
    Settings Manager -> Appearance to pick the theme/icons/font you want.
  * Log out and back in to fully clear the old cursor theme from running apps.
EOF

ok "macOS (WhiteSur) look reverted."
