# NovaBar — macOS Big Sur global menu bar for XFCE

> 🇻🇳 Thanh menu trên cùng kiểu macOS thật: logo Apple + menu ứng dụng **mở rộng, sát trái** (File/Edit/View…) + indicators (WiFi/Sound/Bluetooth) + Control Center + đồng hồ.
> 🇬🇧 A real macOS-style top menu bar: Apple logo + the focused app's menu **expanded and left-aligned** + WiFi/Sound/Bluetooth indicators + Control Center + clock.

NovaBar replaces the XFCE top panel **and** the `vala-panel-appmenu` plugin. We switched to it because `vala-panel-appmenu` on XFCE 4.20 **forces the menu to center** (a known bug, GitLab issue #395) — it can't be left-aligned. NovaBar shows the menu expanded **and** hard-left like macOS.

Repo: https://github.com/novik133/NovaBar — supports GTK (`org.gtk.Menus`) + Qt/Electron (`dbusmenu`). Chrome/Chromium still won't export menus (Linux limitation).

---

## 1. Build & install / Cài đặt

```bash
# build deps (Debian 13)
sudo apt install -y valac meson ninja-build pkg-config gettext \
    libgtk-3-dev libglib2.0-dev libwnck-3-dev libx11-dev libnm-dev \
    libsoup-3.0-dev appmenu-gtk3-module

git clone https://github.com/novik133/NovaBar.git ~/NovaBar
cd ~/NovaBar
meson setup build -Dwayland=false      # X11
ninja -C build
sudo ninja -C build install            # -> /usr/local/bin/novabar, /usr/local/share/novaos
```

## 2. Make NovaBar the only top bar / Để NovaBar là thanh top duy nhất

NovaBar must own the `com.canonical.AppMenu.Registrar` D-Bus name, so the old XFCE panel (with its appmenu plugin) must NOT run.

```bash
# stop the XFCE top panel now
xfce4-panel --quit
# stop it from auto-starting on login (replace it with a no-op in the Failsafe session)
xfconf-query -c xfce4-session -p /sessions/Failsafe/Client2_Command -t string -s "true"
#   (to restore the old XFCE panel later: set that value back to "xfce4-panel")
```

## 3. Autostart / Tự khởi động

```bash
cp /usr/local/etc/xdg/autostart/novabar-autostart.desktop ~/.config/autostart/
```

---

## 4. Customizations applied / Các tùy chỉnh đã làm

These are the tweaks that make NovaBar actually look like macOS Big Sur **light**. The customized files live next to this doc (`novaos-light.css`, `theme`, `logo_icon`, `apple-logo-black.svg`).

### 4a. Light theme + Apple logo
NovaBar config is plain text files in `~/.config/novabar/`:
```bash
mkdir -p ~/.config/novabar
echo -n light > ~/.config/novabar/theme                                   # light, not dark
echo -n "$HOME/.local/share/icons/apple-logo-black.svg" > ~/.config/novabar/logo_icon
cp apple-logo-black.svg ~/.local/share/icons/apple-logo-black.svg          # black Apple (for the LIGHT bar)
```

### 4b. Bigger Apple logo (source patch + rebuild)
The logo is hard-coded to 16×16 px (too small). Bump it:
```bash
sed -i 's/from_file_at_scale(logo_value, 16, 16/from_file_at_scale(logo_value, 20, 20/' \
    ~/NovaBar/src/logomenu/logomenu.vala
ninja -C ~/NovaBar/build
```

### 4c. Fix dark popup backgrounds (calendar / Control Center / WiFi were black-on-black)
**Root cause (non-obvious):** the popup backgrounds are **NOT** from CSS — they are hard-coded with cairo in 11 source files (e.g. `cr.set_source_rgba(0.24, 0.24, 0.24, 0.95)`). In light mode the CSS turned the **text** dark, but the cairo background stayed dark → black text on black. Patch every popup to a light background + a dark hairline border:
```bash
find ~/NovaBar/src -name '*.vala' -exec sed -i \
  -e 's/set_source_rgba(0\.24, 0\.24, 0\.24, 0\.95)/set_source_rgba(0.96, 0.96, 0.97, 0.985)/g' \
  -e 's/set_source_rgba(0\.22, 0\.22, 0\.22, 0\.96)/set_source_rgba(0.96, 0.96, 0.97, 0.985)/g' \
  -e 's/set_source_rgba(0\.2, 0\.2, 0\.2, 0\.95)/set_source_rgba(0.96, 0.96, 0.97, 0.985)/g' \
  -e 's/set_source_rgba(1, 1, 1, 0\.15)/set_source_rgba(0, 0, 0, 0.12)/g' \
  -e 's/set_source_rgba(1, 1, 1, 0\.12)/set_source_rgba(0, 0, 0, 0.10)/g' \
  -e 's/set_source_rgba(1, 1, 1, 0\.1)/set_source_rgba(0, 0, 0, 0.10)/g' {} +
ninja -C ~/NovaBar/build
```

### 4d. Refined CSS (SF Pro font, vibrancy background, logo/text alignment)
Copy the customized light CSS into the location NovaBar loads from:
```bash
cp novaos-light.css ~/NovaBar/data/novaos-light.css
```
Key changes vs upstream: SF Pro font; whiter, more translucent background `rgba(252,252,254,0.70)` (Big Sur vibrancy); vertically-centered Apple-logo/app-name/menu; bold app name; tighter spacing.

### 4e. CSS path bug — run NovaBar from its repo dir
**Gotcha:** the binary looks for CSS in `/usr/share/novaos/` but `ninja install` (prefix `/usr/local`) puts it in `/usr/local/share/novaos/`. The fallback path is `<cwd>/data/`, so launch NovaBar from `~/NovaBar` so it finds `data/novaos-light.css`. The autostart `Exec` is patched to `cd "$HOME/NovaBar"; exec "$HOME/NovaBar/build/novabar"` and use the **rebuilt** binary (which has the bigger logo + light popups).
Permanent alternative (needs sudo): `sudo ln -s /usr/local/share/novaos /usr/share/novaos && sudo ninja -C ~/NovaBar/build install`.

---

## 5. Apply everything at once / Áp dụng nhanh

After cloning + building NovaBar, from this `novabar/` folder:
```bash
mkdir -p ~/.config/novabar ~/.local/share/icons
cp apple-logo-black.svg ~/.local/share/icons/
cp theme logo_icon ~/.config/novabar/
cp novaos-light.css ~/NovaBar/data/novaos-light.css
# (apply the source patches in 4b + 4c, then) rebuild:
ninja -C ~/NovaBar/build
# relaunch from the repo dir:
pkill -x novabar; cd ~/NovaBar; GTK_MODULES=appmenu-gtk-module ~/NovaBar/build/novabar &
```

## Troubleshooting
- **Menu in the middle, not left** → that's the old `vala-panel-appmenu`; use NovaBar (this doc).
- **Calendar / Control Center black-on-black** → popup colors are hard-coded in source; apply patch 4c and rebuild.
- **Bar is dark even with `theme=light`** → CSS not found; run NovaBar from `~/NovaBar` (4e).
- **Apple logo too small** → patch 4b (16→20) and rebuild.
- **Two top bars / global menu not working** → xfce4-panel still running; do step 2.
