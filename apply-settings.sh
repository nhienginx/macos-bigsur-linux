#!/usr/bin/env bash
#
# apply-settings.sh
#
# Apply ONLY the configuration/settings for the macOS (WhiteSur) look on
# Debian 13 / XFCE (X11). This assumes that the GTK theme, icon theme,
# cursor theme, fonts, the Finder icon, the wallpaper image file, and the
# Plank theme are ALREADY installed/present on disk. This script just wires
# everything together via xfconf-query / gsettings and rebuilds the panel
# and dock.
#
# It is idempotent and safe to re-run.
#
# Meant to be run from inside the user's XFCE session (DISPLAY is inherited,
# never hard-coded).

set -uo pipefail

# ----------------------------------------------------------------------------
# Resolve project dir (this script's own directory) so we can also copy the
# bundled config/* and assets/* into place, making the script standalone.
# ----------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
CONFIG_DIR="${SCRIPT_DIR}/config"
ASSETS_DIR="${SCRIPT_DIR}/assets"

# Source of the Plank theme (sibling clone of the WhiteSur-gtk-theme repo).
# Try a couple of likely locations; only used if the theme is not already
# installed.
PLANK_THEME_SRC=""
for cand in \
    "${HOME}/WhiteSur-gtk-theme/other/plank/theme-Light/dock.theme" \
    "${SCRIPT_DIR}/../WhiteSur-gtk-theme/other/plank/theme-Light/dock.theme" \
    "${SCRIPT_DIR}/other/plank/theme-Light/dock.theme"; do
    if [[ -f "$cand" ]]; then PLANK_THEME_SRC="$cand"; break; fi
done

# Convenience paths
APPLICATIONS_DIR="${HOME}/.local/share/applications"
ICONS_DIR="${HOME}/.local/share/icons"
PLANK_LAUNCHERS_DIR="${HOME}/.config/plank/dock1/launchers"
PLANK_THEMES_DIR="${HOME}/.local/share/plank/themes"
AUTOSTART_DIR="${HOME}/.config/autostart"

section() { printf '\n\033[1;34m==== %s ====\033[0m\n' "$*"; }
info()    { printf '  - %s\n' "$*"; }

# ============================================================================
section "0. Copy bundled assets / desktop files / dockitems into place"
# ============================================================================
mkdir -p "$APPLICATIONS_DIR" "$ICONS_DIR" "$ICONS_DIR/macOS-extra" \
         "$PLANK_LAUNCHERS_DIR" "$PLANK_THEMES_DIR" "$AUTOSTART_DIR"

# --- assets/*.svg -> icons ---
if [[ -f "${ASSETS_DIR}/apple-logo.svg" ]]; then
    install -m 0644 "${ASSETS_DIR}/apple-logo.svg" "${ICONS_DIR}/apple-logo.svg"
    info "installed apple-logo.svg"
fi
if [[ -f "${ASSETS_DIR}/finder.svg" ]]; then
    install -m 0644 "${ASSETS_DIR}/finder.svg" "${ICONS_DIR}/macOS-extra/finder.svg"
    info "installed macOS-extra/finder.svg"
fi

# --- config/*.desktop -> applications (rewrite absolute $HOME paths) ---
for d in "${CONFIG_DIR}"/*.desktop; do
    [[ -e "$d" ]] || continue
    base="$(basename "$d")"
    dest="${APPLICATIONS_DIR}/${base}"
    # Rewrite any hard-coded /home/<user> references to the current $HOME so
    # the Icon=/Exec= paths point at this user's tree.
    sed -E "s#/home/[^/]+/#${HOME}/#g" "$d" > "$dest"
    info "installed ${base}"
done

# Ensure finder.desktop points at the freshly-installed finder icon, no matter
# what the bundled file said.
if [[ -f "${APPLICATIONS_DIR}/finder.desktop" ]]; then
    sed -i -E "s#^Icon=.*#Icon=${ICONS_DIR}/macOS-extra/finder.svg#" \
        "${APPLICATIONS_DIR}/finder.desktop"
fi

# --- config/*.dockitem -> plank launchers (rewrite $HOME) ---
for di in "${CONFIG_DIR}"/*.dockitem; do
    [[ -e "$di" ]] || continue
    base="$(basename "$di")"
    dest="${PLANK_LAUNCHERS_DIR}/${base}"
    sed -E "s#/home/[^/]+/#${HOME}/#g" "$di" > "$dest"
    info "installed launcher ${base}"
done

# --- Plank theme (only if not already installed) ---
if [[ ! -f "${PLANK_THEMES_DIR}/WhiteSur-Light/dock.theme" ]]; then
    if [[ -n "$PLANK_THEME_SRC" ]]; then
        mkdir -p "${PLANK_THEMES_DIR}/WhiteSur-Light"
        install -m 0644 "$PLANK_THEME_SRC" \
            "${PLANK_THEMES_DIR}/WhiteSur-Light/dock.theme"
        info "installed Plank WhiteSur-Light theme"
    else
        info "WARN: Plank WhiteSur-Light theme not found and no source available"
    fi
else
    info "Plank WhiteSur-Light theme already present"
fi

# --- Plank macOS theme (custom Big Sur look: glassy, even padding) ---
if [[ -f "${CONFIG_DIR}/plank-macOS-dock.theme" ]]; then
    mkdir -p "${PLANK_THEMES_DIR}/macOS"
    install -m 0644 "${CONFIG_DIR}/plank-macOS-dock.theme" \
        "${PLANK_THEMES_DIR}/macOS/dock.theme"
    info "installed Plank macOS theme"
fi

# --- Plank active-glow / indicator LD_PRELOAD shim ---------------------------
# Plank hardcodes the active-window background glow and a light-blue running
# dot in libplank (no theme/dconf option). This tiny preload library no-ops the
# active glow and forces the running dot to black -> proper macOS look. Built
# locally; loaded via the Plank autostart Exec (see section 5).
PLANK_SHIM="${HOME}/.local/lib/plank-noglow.so"
if [[ -f "${CONFIG_DIR}/plank-noglow.c" ]] && command -v gcc >/dev/null 2>&1; then
    mkdir -p "${HOME}/.local/lib"
    if gcc -shared -fPIC -O2 -o "$PLANK_SHIM" "${CONFIG_DIR}/plank-noglow.c" -ldl; then
        info "built Plank shim ${PLANK_SHIM}"
    else
        info "WARN: failed to build Plank shim; active glow will remain"
    fi
else
    info "WARN: gcc or plank-noglow.c missing; skipping Plank shim"
fi

# ============================================================================
section "1. xfwm4 (window manager)"
# ============================================================================
xfconf-query -c xfwm4 -p /general/theme          -s "WhiteSur-Light"
xfconf-query -c xfwm4 -p /general/button_layout   -s "CHM|O"
xfconf-query -c xfwm4 -p /general/title_font      -s "SF Pro Display Medium 10"
xfconf-query -c xfwm4 -p /general/title_alignment -s "center"
info "theme=WhiteSur-Light, button_layout=CHM|O, centered SF Pro title"

# ============================================================================
section "2. xsettings (GTK theme / icons / cursor / font)"
# ============================================================================
xfconf-query -c xsettings -p /Net/ThemeName        -s "WhiteSur-Light"
xfconf-query -c xsettings -p /Net/IconThemeName     -s "WhiteSur-light"
xfconf-query -c xsettings -p /Gtk/CursorThemeName   -s "WhiteSur-cursors"
xfconf-query -c xsettings -p /Gtk/FontName          -s "SF Pro Text 10"
info "GTK=WhiteSur-Light, icons=WhiteSur-light, cursor=WhiteSur-cursors, font=SF Pro Text 10"

# ============================================================================
section "3. Wallpaper (detect monitors/workspaces)"
# ============================================================================
WALLPAPER="${HOME}/.local/share/backgrounds/WhiteSur-light.jpg"
if [[ ! -f "$WALLPAPER" ]]; then
    info "WARN: wallpaper file not found at ${WALLPAPER} (setting properties anyway)"
fi

# Collect existing last-image properties (one per monitor/workspace).
mapfile -t LAST_IMAGE_PROPS < <(xfconf-query -c xfce4-desktop -l 2>/dev/null | grep -E '/last-image$' || true)

if [[ "${#LAST_IMAGE_PROPS[@]}" -eq 0 ]]; then
    info "No existing last-image properties; deriving monitors from xrandr"
    # Derive connected monitor names from xrandr and create the property tree.
    mapfile -t MONITORS < <(xrandr 2>/dev/null | awk '/ connected/{print $1}')
    if [[ "${#MONITORS[@]}" -eq 0 ]]; then
        # Fallback to the historical name from this machine.
        MONITORS=("Virtual1")
    fi
    for mon in "${MONITORS[@]}"; do
        prop="/backdrop/screen0/monitor${mon}/workspace0/last-image"
        xfconf-query -c xfce4-desktop -p "$prop" -n -t string -s "$WALLPAPER" 2>/dev/null \
            || xfconf-query -c xfce4-desktop -p "$prop" -s "$WALLPAPER"
        LAST_IMAGE_PROPS+=("$prop")
        info "created ${prop}"
    done
fi

# Apply image to every last-image property and set its sibling style props.
for prop in "${LAST_IMAGE_PROPS[@]}"; do
    xfconf-query -c xfce4-desktop -p "$prop" -s "$WALLPAPER" 2>/dev/null \
        || xfconf-query -c xfce4-desktop -p "$prop" -n -t string -s "$WALLPAPER"
    base="${prop%/last-image}"
    # image-style=5 (scaled/zoom), color-style=0
    xfconf-query -c xfce4-desktop -p "${base}/image-style" -n -t int -s 5 2>/dev/null \
        || xfconf-query -c xfce4-desktop -p "${base}/image-style" -s 5
    xfconf-query -c xfce4-desktop -p "${base}/color-style" -n -t int -s 0 2>/dev/null \
        || xfconf-query -c xfce4-desktop -p "${base}/color-style" -s 0
    info "wallpaper set for ${base}"
done

# ============================================================================
section "4. Rebuild top panel-1 (macOS menu bar)"
# ============================================================================
PANEL_C="xfce4-panel"

# Half-screen width from the primary mode width in xrandr (for centered p=2).
SCREEN_W="$(xrandr 2>/dev/null | awk '/\*/{split($1,a,"x"); print a[1]; exit}')"
[[ -z "${SCREEN_W:-}" ]] && SCREEN_W="$(xrandr 2>/dev/null | awk '/ connected/{if(match($0,/[0-9]+x[0-9]+\+/)){s=substr($0,RSTART,RLENGTH-1); split(s,a,"x"); print a[1]; exit}}')"
[[ -z "${SCREEN_W:-}" ]] && SCREEN_W=2560
HALF_W=$(( SCREEN_W / 2 ))
info "screen width=${SCREEN_W}, half=${HALF_W}"

# Ensure panel-1 is the only panel and define its plugin order.
xfconf-query -c $PANEL_C -p /panels -n -t int -s 1 2>/dev/null || \
    xfconf-query -c $PANEL_C -p /panels -t int -s 1 2>/dev/null || true

# plugin-ids = [20,30,31,32,6,1]
xfconf-query -c $PANEL_C -p /panels/panel-1/plugin-ids \
    -n -t int -s 20 -t int -s 30 -t int -s 31 -t int -s 32 -t int -s 6 -t int -s 1 2>/dev/null || \
xfconf-query -c $PANEL_C -p /panels/panel-1/plugin-ids \
    -t int -s 20 -t int -s 30 -t int -s 31 -t int -s 32 -t int -s 6 -t int -s 1
info "plugin-ids=[20,30,31,32,6,1]"

# Helper to (re)define a plugin's type string.
set_plugin_type() {
    local id="$1" type="$2"
    xfconf-query -c $PANEL_C -p "/plugins/plugin-${id}" -n -t string -s "$type" 2>/dev/null || \
    xfconf-query -c $PANEL_C -p "/plugins/plugin-${id}" -t string -s "$type"
}

# 20 = whiskermenu (Apple logo button)
set_plugin_type 20 whiskermenu
xfconf-query -c $PANEL_C -p /plugins/plugin-20/button-icon \
    -n -t string -s "${ICONS_DIR}/apple-logo.svg" 2>/dev/null || \
xfconf-query -c $PANEL_C -p /plugins/plugin-20/button-icon -s "${ICONS_DIR}/apple-logo.svg"
xfconf-query -c $PANEL_C -p /plugins/plugin-20/show-button-title \
    -n -t bool -s false 2>/dev/null || \
xfconf-query -c $PANEL_C -p /plugins/plugin-20/show-button-title -s false
xfconf-query -c $PANEL_C -p /plugins/plugin-20/button-title \
    -n -t string -s "" 2>/dev/null || \
xfconf-query -c $PANEL_C -p /plugins/plugin-20/button-title -s ""
info "plugin-20 whiskermenu (apple-logo, no title)"

# 30 = separator (expand=true, style=0)  -> pushes the rest to the right
set_plugin_type 30 separator
xfconf-query -c $PANEL_C -p /plugins/plugin-30/expand -n -t bool -s true 2>/dev/null || \
xfconf-query -c $PANEL_C -p /plugins/plugin-30/expand -s true
xfconf-query -c $PANEL_C -p /plugins/plugin-30/style  -n -t int  -s 0 2>/dev/null || \
xfconf-query -c $PANEL_C -p /plugins/plugin-30/style  -s 0
info "plugin-30 separator (expand)"

# 31 = pulseaudio
set_plugin_type 31 pulseaudio
# 32 = power-manager-plugin
set_plugin_type 32 power-manager-plugin
# 6 = systray
set_plugin_type 6 systray
info "plugin-31 pulseaudio, plugin-32 power-manager, plugin-6 systray"

# 1 = clock (digital, macOS style)
set_plugin_type 1 clock
xfconf-query -c $PANEL_C -p /plugins/plugin-1/mode -n -t int -s 2 2>/dev/null || \
xfconf-query -c $PANEL_C -p /plugins/plugin-1/mode -s 2
xfconf-query -c $PANEL_C -p /plugins/plugin-1/digital-layout -n -t int -s 3 2>/dev/null || \
xfconf-query -c $PANEL_C -p /plugins/plugin-1/digital-layout -s 3
xfconf-query -c $PANEL_C -p /plugins/plugin-1/digital-time-format \
    -n -t string -s "%a %b %-d   %-l:%M %p" 2>/dev/null || \
xfconf-query -c $PANEL_C -p /plugins/plugin-1/digital-time-format -s "%a %b %-d   %-l:%M %p"
info "plugin-1 clock (digital, '%a %b %-d   %-l:%M %p')"

# --- panel-1 geometry / appearance ---
panel_set() {  # name n-type value
    local key="$1" typ="$2" val="$3"
    xfconf-query -c $PANEL_C -p "/panels/panel-1/${key}" -n -t "$typ" -s "$val" 2>/dev/null || \
    xfconf-query -c $PANEL_C -p "/panels/panel-1/${key}" -s "$val"
}
panel_set mode             int  0
panel_set size             int  28
panel_set length           int  100
panel_set nrows            int  1
panel_set background-style int  0
panel_set enable-struts    bool true

# IMPORTANT: avoid the "position-locked=true before move" bug.
# Order: unlock -> move -> restart panel -> lock.
panel_set position-locked  bool false
panel_set position         string "p=2;x=${HALF_W};y=0"
info "panel-1 mode=0 size=28 length=100 position=p=2;x=${HALF_W};y=0"

# Restart the panel so the rebuilt layout + move take effect, THEN lock.
section "4b. Restart xfce4-panel"
xfce4-panel -r >/dev/null 2>&1 || true
# Give the panel a moment to come back before locking position.
for _ in 1 2 3 4 5; do
    pgrep -x xfce4-panel >/dev/null 2>&1 && break
    sleep 1
done
panel_set position-locked  bool true
info "panel restarted and position locked"

# ============================================================================
section "5. Plank dock"
# ============================================================================
PLANK_DCONF_PATH="net.launchpad.plank.dock.settings:/net/launchpad/plank/docks/dock1/"

# Plank must run at least once before the dock1 dconf path is usable.
if ! pgrep -x plank >/dev/null 2>&1; then
    info "starting Plank (first run, needed for dock1 dconf path)"
    nohup plank >/dev/null 2>&1 &
    for _ in 1 2 3 4 5 6 7 8; do
        pgrep -x plank >/dev/null 2>&1 && break
        sleep 1
    done
fi

if command -v gsettings >/dev/null 2>&1; then
    gsettings set "$PLANK_DCONF_PATH" theme        'macOS'           || true
    gsettings set "$PLANK_DCONF_PATH" position      'bottom'          || true
    gsettings set "$PLANK_DCONF_PATH" alignment     'center'          || true
    gsettings set "$PLANK_DCONF_PATH" icon-size     48                || true
    # hide-mode 'none' = dock always visible (like macOS). 'intelligent'
    # auto-hides when a window overlaps it, which makes the dock vanish
    # the moment you maximize an app like Chrome.
    gsettings set "$PLANK_DCONF_PATH" hide-mode     'none'            || true
    gsettings set "$PLANK_DCONF_PATH" zoom-enabled  true              || true
    gsettings set "$PLANK_DCONF_PATH" zoom-percent  175               || true
    info "theme=macOS bottom/center icon-size=48 zoom=175 hide=none"

    # Build dock-items = finder + trash + any present app dockitems.
    # Always include finder first and trash last; insert present apps between.
    declare -a ITEMS=("finder.dockitem")
    # Candidate app dockitems whose target .desktop must exist to be added.
    declare -A APP_DESKTOP=(
        ["org.xfce.orage.dockitem"]="/usr/share/applications/org.xfce.orage.desktop"
        ["xfce4-web-browser.dockitem"]="/usr/share/applications/xfce4-web-browser.desktop"
        ["vlc.dockitem"]="/usr/share/applications/vlc.desktop"
        ["xfce4-mail-reader.dockitem"]="/usr/share/applications/xfce4-mail-reader.desktop"
        ["org.strawberrymusicplayer.strawberry.dockitem"]="/usr/share/applications/org.strawberrymusicplayer.strawberry.desktop"
        ["org.nomacs.ImageLounge.dockitem"]="/usr/share/applications/org.nomacs.ImageLounge.desktop"
    )
    # Preserve a stable, macOS-like order.
    for di in \
        org.xfce.orage.dockitem \
        xfce4-web-browser.dockitem \
        vlc.dockitem \
        xfce4-mail-reader.dockitem \
        org.strawberrymusicplayer.strawberry.dockitem \
        org.nomacs.ImageLounge.dockitem; do
        target="${APP_DESKTOP[$di]}"
        if [[ -n "$target" && -e "$target" ]]; then
            # Make sure a launcher file exists for this app dockitem.
            launcher="${PLANK_LAUNCHERS_DIR}/${di}"
            if [[ ! -f "$launcher" ]]; then
                printf '[PlankDockItemPreferences]\nLauncher=file://%s\n' "$target" > "$launcher"
            fi
            ITEMS+=("$di")
            info "dock includes ${di}"
        fi
    done
    ITEMS+=("trash.dockitem")

    # Compose a GVariant string array: ['a.dockitem', 'b.dockitem', ...]
    gv="["
    for i in "${!ITEMS[@]}"; do
        [[ "$i" -gt 0 ]] && gv+=", "
        gv+="'${ITEMS[$i]}'"
    done
    gv+="]"
    gsettings set "$PLANK_DCONF_PATH" dock-items "$gv" || true
    info "dock-items=${gv}"
else
    info "WARN: gsettings not available; skipping Plank settings"
fi

# Autostart Plank on login. Load the macOS shim (no active glow, black dot)
# via LD_PRELOAD when the shim was built; otherwise fall back to plain plank.
if [[ -f "$PLANK_SHIM" ]]; then
    PLANK_EXEC="env LD_PRELOAD=${PLANK_SHIM} plank"
else
    PLANK_EXEC="plank"
fi
cat > "${AUTOSTART_DIR}/plank.desktop" <<EOF
[Desktop Entry]
Type=Application
Version=1.0
Name=Plank
Comment=Plank dock
Exec=${PLANK_EXEC}
Terminal=false
X-GNOME-Autostart-enabled=true
Hidden=false
EOF
info "wrote ${AUTOSTART_DIR}/plank.desktop (Exec=${PLANK_EXEC})"

# ============================================================================
section "6. Disable MX conky autostart (if present)"
# ============================================================================
CONKY_AUTOSTART="${AUTOSTART_DIR}/conky.desktop"
if [[ -f "$CONKY_AUTOSTART" ]]; then
    if grep -q '^Hidden=' "$CONKY_AUTOSTART"; then
        sed -i -E 's/^Hidden=.*/Hidden=true/' "$CONKY_AUTOSTART"
    else
        printf 'Hidden=true\n' >> "$CONKY_AUTOSTART"
    fi
    if grep -q '^X-GNOME-Autostart-enabled=' "$CONKY_AUTOSTART"; then
        sed -i -E 's/^X-GNOME-Autostart-enabled=.*/X-GNOME-Autostart-enabled=false/' "$CONKY_AUTOSTART"
    else
        printf 'X-GNOME-Autostart-enabled=false\n' >> "$CONKY_AUTOSTART"
    fi
    info "disabled conky autostart"
else
    info "no conky autostart found (nothing to disable)"
fi

section "Done"
printf '\nAll settings applied. Log out/in if any change did not take effect.\n'
