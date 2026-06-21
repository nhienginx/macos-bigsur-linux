# Bộ Office giống MS Office (ONLYOFFICE) + icon kiểu macOS

Cài **bộ soạn thảo văn phòng giao diện ribbon giống Microsoft Office** trên
Debian 13 / XFCE, kèm **font Microsoft** (cho văn bản pháp luật) và một **icon
"Microsoft Office" kiểu squircle macOS** trên Dock.

> **Tại sao ONLYOFFICE mà không phải LibreOffice?**
> ONLYOFFICE dùng chính định dạng **OOXML (.docx/.xlsx/.pptx)** làm chuẩn lưu
> trữ → mở file Word của người khác gửi **gần như không vỡ layout, không lệch số
> trang**, điều LibreOffice đôi khi bị. Giao diện cũng là **ribbon giống Office**
> sẵn. Bản Desktop Editors **miễn phí, mã nguồn mở**, không giới hạn tính năng.

---

## 1. Cài đặt nhanh

```bash
./install-office.sh
```

Script **chạy lại được nhiều lần** (idempotent) và sẽ:

1. Kiểm tra phiên XFCE + phụ thuộc.
2. Cài **ONLYOFFICE Desktop Editors** từ `.deb` chính chủ (không có trong apt).
3. Cài **font Microsoft** (`ttf-mscorefonts-installer` → Times New Roman, Arial…)
   + **Carlito/Caladea** (tương thích Calibri/Cambria).
4. Đặt **icon Office kiểu macOS** (`assets/ms-office.svg`) cho launcher qua một
   bản `.desktop` override trong `~/.local/share`.
5. **Ghim vào Dock** (Plank) và khởi động lại Plank.

> ⚠️ Bước cài `.deb` và font **cần `sudo`**. Gói font tải thêm từ SourceForge —
> nếu mirror lỗi, cứ chạy lại script.

### Phụ thuộc cài qua apt
| Gói | Vai trò |
|-----|---------|
| `onlyoffice-desktopeditors` (.deb) | Bộ soạn thảo (Word/Excel/PowerPoint-like) |
| `ttf-mscorefonts-installer` | Times New Roman, Arial, Verdana… (repo `contrib`) |
| `fonts-crosextra-carlito` | Thay Calibri (cùng kích thước chữ) |
| `fonts-crosextra-caladea` | Thay Cambria (cùng kích thước chữ) |

---

## 2. Vì sao cần font Microsoft cho văn bản pháp luật

Văn bản pháp luật VN (theo **Nghị định 30/2020/NĐ-CP**) yêu cầu **Times New
Roman**, khổ **A4**, căn lề chuẩn. Linux **không có sẵn** font Microsoft (font
độc quyền), nếu thiếu thì file sẽ hiển thị font thay thế → **lệch số trang / căn
lề** so với bản gốc. `ttf-mscorefonts-installer` tải đúng font gốc, còn
Carlito/Caladea lo cho file đời mới dùng Calibri/Cambria.

Kiểm tra font đã có:
```bash
fc-list | grep -i "times new roman"
```

---

## 3. Icon "Microsoft Office" kiểu macOS

Theme WhiteSur **không có** icon app cho cả bộ Office (chỉ có icon mime cho từng
loại file). Nên dự án tự ghép một **squircle macOS** chứa 4 logo app **thật**
(Word · Excel · PowerPoint · OneNote) tải từ bộ
[`sempostma/office365-icons`](https://github.com/sempostma/office365-icons).

| File | Nội dung |
|------|----------|
| `assets/ms-office.svg` | Icon ghép cuối (squircle trắng + 4 logo) — dùng cho Dock |
| `assets/office-app-logos/{word,excel,powerpoint,onenote}.svg` | 4 logo gốc, để tái tạo |

### Cách icon được gắn vào launcher
Plank lấy icon từ dòng `Icon=` của file `.desktop` mà dockitem trỏ tới. Để
**không bị `apt upgrade` ghi đè**, ta **không** sửa file hệ thống mà tạo bản
override trong `~/.local/share/applications/`:

```bash
# copy nguyên bản .desktop hệ thống, chỉ đổi dòng Icon= sang icon macOS
sed "s|^Icon=.*|Icon=$HOME/.local/share/icons/ms-office.svg|" \
  /usr/share/applications/onlyoffice-desktopeditors.desktop \
  > ~/.local/share/applications/onlyoffice-desktopeditors.desktop
```

> `StartupWMClass=ONLYOFFICE` được giữ nguyên trong bản copy → Plank vẫn **gộp
> đúng cửa sổ** đang chạy vào icon đã ghim (không hiện icon trùng).

### Đổi sang icon khác
Thay file `assets/ms-office.svg` (hoặc trỏ `Icon=` tới SVG/PNG khác), rồi:
```bash
gtk-update-icon-cache -f ~/.local/share/icons; pkill -x plank; nohup plank &
```

---

## 4. Các file được tạo

| Đường dẫn | Nội dung |
|-----------|----------|
| `~/.local/share/icons/ms-office.svg` | Icon Office kiểu macOS |
| `~/.local/share/applications/onlyoffice-desktopeditors.desktop` | Bản `.desktop` override (đổi `Icon=`) |
| `~/.config/plank/dock1/launchers/onlyoffice-desktopeditors.dockitem` | Mục ghim trong Dock |
| `~/.cache/macos-theme-build/onlyoffice-*.deb` | File cài tải về (cache) |

Thứ tự icon trong Dock **không** nằm trong file — Plank lưu ở gsettings:
```bash
gsettings get net.launchpad.plank.dock.settings:/net/launchpad/plank/docks/dock1/ dock-items
```

---

## 5. Chỉnh ONLYOFFICE cho giống MS Office hơn

Mặc định đã là ribbon giống Office. Tinh chỉnh thêm trong app:

- **Theme sáng kiểu Office:** trang Start → ⚙ (Settings) → **Interface theme** →
  **Classic Light** (giống Office 2016) hoặc **Light** (giống Office 365).
- **Giao diện Tiếng Việt:** cùng chỗ đó → **Interface language → Tiếng Việt**.
- **Ribbon đầy đủ:** mở 1 file → mũi tên ▲/▼ ở mép phải thanh tab để bỏ chế độ
  thu gọn.
- **Thước + thanh trạng thái:** tab **View** → bật **Ruler** và **Status bar**.

### Gợi ý mặc định cho văn bản pháp luật (Nghị định 30)
- Font **Times New Roman 13–14pt**, khổ **A4**.
- Lề: trên 2cm · dưới 2cm · trái 3cm · phải 1.5–2cm.
- Lưu dạng **.docx** (mặc định của ONLYOFFICE) để gửi qua Word chuẩn nhất.

---

## 6. Gỡ cài đặt

```bash
# bỏ ghim + override icon
rm -f ~/.config/plank/dock1/launchers/onlyoffice-desktopeditors.dockitem \
      ~/.local/share/applications/onlyoffice-desktopeditors.desktop \
      ~/.local/share/icons/ms-office.svg
# bỏ 'onlyoffice-desktopeditors.dockitem' khỏi mảng dock-items (sửa gsettings), rồi:
pkill -x plank; nohup plank >/dev/null 2>&1 &
# gỡ phần mềm + font (tùy chọn)
sudo apt-get remove -y onlyoffice-desktopeditors
# (giữ font Microsoft lại thì bỏ qua dòng dưới)
sudo apt-get remove -y ttf-mscorefonts-installer
```

---

## 7. Khắc phục sự cố

| Hiện tượng | Cách xử lý |
|------------|-----------|
| `Invalid archive member header` khi cài | File `.deb` tải **chưa xong** — xóa `~/.cache/macos-theme-build/onlyoffice-*.deb` rồi chạy lại |
| Mở file Word bị **lệch số trang** | Thiếu font gốc — kiểm tra `fc-list \| grep -i "times new roman"`, chạy lại bước font |
| Icon Dock vẫn là icon cũ | `gtk-update-icon-cache -f ~/.local/share/icons; pkill -x plank; nohup plank &` |
| Icon Office bị **trùng** khi mở app | Bản `.desktop` override mất `StartupWMClass=ONLYOFFICE` — tạo lại bằng lệnh `sed` ở mục 3 |
| Bảng EULA font hiện ra (chạy tay) | Bấm **Tab → `<Ok>` → Enter**, rồi `<Yes>` → Enter để đồng ý |

---

> Liên quan: cách ghim app vào Dock nói chung xem README mục **"Ghim ứng dụng vào
> dock"**; icon Launchpad/Finder xem [`docs/launchpad.md`](launchpad.md).
