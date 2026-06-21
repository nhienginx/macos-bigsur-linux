# Launchpad kiểu macOS (rofi)

Một trình mở app **toàn màn hình, nền mờ, lưới icon to** giống Launchpad của macOS —
chạy trên Debian 13 / XFCE (X11), dùng `rofi`.

> **Tại sao là rofi mà không phải `xfce4-appfinder`?**
> `xfce4-appfinder` chỉ hiện được **danh sách app trong cửa sổ nhỏ**, không có chế độ
> lưới full màn hình → trông không giống macOS. `rofi` ở chế độ `drun` cho ra đúng cảm
> giác Launchpad: full màn hình, nền wallpaper mờ, lưới icon lớn, gõ để lọc, lật trang.
> Nhẹ và chạy ổn định trên X11.

---

## 1. Cài đặt nhanh

```bash
./install-launchpad.sh
```

Script này **chạy lại được nhiều lần** (idempotent) và sẽ:

1. Kiểm tra phiên XFCE + cài phụ thuộc (`rofi`, `scrot`, `imagemagick`) qua apt nếu thiếu.
2. Cài theme rofi Launchpad.
3. Cài script khởi chạy (làm mờ màn hình rồi mở rofi).
4. Cài icon Launchpad + file `.desktop`.
5. Ghim vào Dock (Plank), cạnh Finder.
6. Gán phím tắt **Super + R**.
7. Khởi động lại Plank để hiện icon.

### Phụ thuộc
| Gói | Vai trò |
|-----|---------|
| `rofi` | Trình mở app (chế độ `drun`, lưới icon) |
| `scrot` | Chụp màn hình hiện tại để làm nền |
| `imagemagick` (`convert`) | Làm mờ + tối + giảm bão hòa cho nền |

---

## 2. Cách dùng

- Mở: bấm **icon Launchpad dưới Dock** (ô lưới màu cạnh Finder), hoặc nhấn **Super + R**.
- **Gõ** tên app để lọc.
- **Enter** mở app, **Esc** đóng.
- Bấm Super + R lần nữa khi đang mở → đóng (toggle).

---

## 3. Các file được tạo

| Đường dẫn | Nội dung |
|-----------|----------|
| `~/.local/bin/launchpad` | Script: chụp + làm mờ màn hình → mở rofi |
| `~/.config/rofi/launchpad.rasi` | Theme rofi (full màn hình, lưới, cỡ icon, ô search) |
| `~/.local/share/icons/launchpad.svg` | Icon lưới 9 ô màu kiểu macOS |
| `~/.local/share/applications/launchpad.desktop` | Mục app (để Plank/menu dùng) |
| `~/.config/plank/dock1/launchers/launchpad.dockitem` | Mục ghim trong Dock |
| `/tmp/launchpad-bg.png` | Ảnh nền mờ (tạo lại mỗi lần mở) |

Thứ tự icon trong Dock **không** nằm trong file — Plank lưu ở gsettings:
```bash
gsettings get net.launchpad.plank.dock.settings:/net/launchpad/plank/docks/dock1/ dock-items
```

---

## 4. Tùy chỉnh

### 4.1. Số cột / cỡ icon — sửa `~/.config/rofi/launchpad.rasi`

```rasi
listview {
    columns: 7;     /* số cột — giảm xuống 5/6 để icon TO hơn */
    lines:   5;     /* số hàng mỗi trang */
}
element-icon {
    size: 92px;     /* cỡ icon — tăng/giảm theo ý */
}
```

### 4.2. Ô tìm kiếm
```rasi
inputbar {
    margin: 0px 38% 0px 38%;   /* lề 2 bên 38% => ô search hẹp, nằm giữa.
                                  giảm % để ô rộng hơn */
    border-radius: 18px;        /* bo góc */
}
```

### 4.3. Độ tối / độ mờ của nền — sửa dòng `convert` trong `~/.local/bin/launchpad`

```bash
convert "$BG" -scale 6% -blur 0x2.5 -resize 1666% \
    -modulate 58,35 -fill "#0e0e12" -colorize 28% "$BG"
```

| Tham số | Ý nghĩa | Muốn gì thì chỉnh |
|---------|---------|-------------------|
| `-scale 6% ... -resize 1666%` | thu nhỏ rồi phóng to → tạo mờ | scale nhỏ hơn = mờ nhiều hơn |
| `-blur 0x2.5` | làm mờ thêm | tăng số = mờ hơn |
| `-modulate 58,35` | `độ_sáng,độ_bão_hòa` (%) | giảm số 1 = tối hơn; giảm số 2 = bớt màu |
| `-colorize 28%` | pha màu tối `#0e0e12` lên nền | tăng % = tối/trung tính hơn |

**Muốn nền tối phẳng (bỏ hẳn wallpaper):** xóa phần `scrot` + `convert` trong script,
rồi trong `.rasi` bỏ dòng `background-image` và đổi `window { background-color: #000000cc; }`.

### 4.4. Đổi phím tắt
```bash
# bỏ Super+R cũ rồi gán phím khác, ví dụ F4:
xfconf-query -c xfce4-keyboard-shortcuts -p "/commands/custom/<Super>r" -r
xfconf-query -c xfce4-keyboard-shortcuts -p "/commands/custom/F4" -n -t string -s "$HOME/.local/bin/launchpad"
```

---

## 5. Ghim / bỏ ghim icon trong Dock (Plank)

**Cách thường (bằng chuột):**
1. Mở app → icon hiện tạm trong Plank.
2. **Chuột phải** vào icon → tick **"Keep in Dock"**.
- Bỏ ghim: chuột phải → bỏ tick, hoặc kéo icon ra khỏi Dock.
- Sắp xếp: kéo-thả icon trái/phải.

**Bằng dòng lệnh** (như script đã làm cho Launchpad):
1. Tạo `~/.config/plank/dock1/launchers/<ten>.dockitem` trỏ tới file `.desktop`.
2. Thêm `<ten>.dockitem` vào mảng `dock-items` qua `gsettings`.
3. Khởi động lại Plank: `pkill -x plank; nohup plank &`.

---

## 6. Gỡ cài đặt

```bash
rm -f ~/.local/bin/launchpad \
      ~/.config/rofi/launchpad.rasi \
      ~/.local/share/icons/launchpad.svg \
      ~/.local/share/applications/launchpad.desktop \
      ~/.config/plank/dock1/launchers/launchpad.dockitem
# bỏ khỏi thứ tự Dock: sửa lại danh sách gsettings dock-items (bỏ 'launchpad.dockitem')
# bỏ phím tắt:
xfconf-query -c xfce4-keyboard-shortcuts -p "/commands/custom/<Super>r" -r
pkill -x plank; nohup plank >/dev/null 2>&1 &
```

---

## 7. Khắc phục sự cố

| Hiện tượng | Cách xử lý |
|------------|-----------|
| Bấm icon không lên gì | Chạy thử `~/.local/bin/launchpad` trong terminal xem báo lỗi |
| Lỗi `rofi: command not found` | `sudo apt install -y rofi` |
| Nền không mờ (đen trơn) | Thiếu `scrot`/`imagemagick`: `sudo apt install -y scrot imagemagick` |
| Icon Dock sai/mất | `gtk-update-icon-cache -f ~/.local/share/icons; pkill -x plank; nohup plank &` |
| Super+R không chạy | Kiểm tra: `xfconf-query -c xfce4-keyboard-shortcuts -p "/commands/custom/<Super>r"` |

---

> Liên quan: **Spotlight** (tìm app bằng cách gõ, phím **Super + Space**) cài bằng
> `install-spotlight.sh` (Ulauncher). Launchpad ở đây là phần "lưới icon" bổ sung.
