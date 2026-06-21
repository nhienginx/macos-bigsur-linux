# Tối ưu hiệu năng (máy RAM ít / chạy trong máy ảo)

Tối ưu cho bản dựng **macOS trên MX Linux 25** (XFCE + novabar + Plank) sao cho
**nhẹ, mượt** mà vẫn giữ giao diện đẹp và phục vụ tốt việc soạn thảo văn bản.
Đặc biệt hữu ích khi RAM ít (≤ 4–8 GB) hoặc đang chạy trong **VirtualBox**.

> **MX Linux dùng sysVinit, không phải systemd.** Vì vậy ở đây dùng `service`
> (không phải `systemctl`) và zram được bật qua gói `zram-tools` thay cho
> `systemd-zram-generator`.

---

## 1. Chạy nhanh

```bash
./optimize.sh
```

Script **chạy lại được nhiều lần** (idempotent) và sẽ:

1. **Dò môi trường** (RAM, swap, có phải máy ảo) để đưa lời khuyên đúng.
2. **Dọn autostart thừa** — per-user, có sao lưu, **không cần root**.
3. **Bật zram** (nén RAM làm swap) qua `zram-tools` — cần `sudo`.
4. **Tinh chỉnh sysctl** (`vm.swappiness`, `vm.vfs_cache_pressure`) — cần `sudo`.
5. **In hướng dẫn tinh chỉnh VirtualBox** (phần này phải tự làm trên host).

---

## 2. Việc có tác động lớn nhất: tăng tài nguyên VM (nếu chạy trong VirtualBox)

Nếu máy là máy ảo, nút thắt **gần như luôn** là tài nguyên cấp cho VM, chứ không
phải Linux nặng. **Tắt máy ảo**, rồi trong VirtualBox → chọn máy → **Settings**:

| Mục | Đặt thành | Ghi chú |
|-----|-----------|---------|
| System → Motherboard → Base Memory | **6144–8192 MB** | RAM 3–4 GB là quá ít cho theme + OnlyOffice |
| System → Processor → Processors | **4 nhân** (hoặc hơn) | Host thường còn dư rất nhiều |
| Display → Screen → Video Memory | **128 MB** | Cần cho hiệu ứng/animation mượt |
| Display → Screen → Enable 3D Acceleration | **Bật** | Tăng tốc đồ họa cho compositor |
| Display → Graphics Controller | **VMSVGA** | Lựa chọn tốt nhất cho Linux hiện đại |
| Storage → (ổ đĩa ảo) → Solid-state Drive | **Bật** (nếu host SSD) | Giảm độ trễ khi swap/đọc ghi |

> Cần **Guest Additions** đã cài trong máy ảo để 3D acceleration có tác dụng
> (bản dựng này đã cài sẵn).

---

## 3. Dọn ứng dụng tự khởi động (autostart)

Bản MX mặc định bật nhiều thứ không cần cho cấu hình macOS-theme trong VM.
Script tắt các mục **an toàn** sau (per-user, qua file override `Hidden=true`):

| App | Là gì | Vì sao tắt được |
|-----|-------|-----------------|
| `orca` | Trình đọc màn hình (trợ năng) | Không dùng nếu mắt bình thường |
| `onboard` | Bàn phím ảo trên màn hình | Có bàn phím vật lý rồi |
| `magnus` | Kính lúp phóng to | Tính năng trợ năng, ít dùng |
| `blueman` | Applet Bluetooth | Máy ảo thường không có Bluetooth |
| `spice-vdagent` | Guest agent QEMU/SPICE | **Vô dụng trên VirtualBox** |
| `zstartup-sound` | Âm thanh khi đăng nhập | Chỉ là âm thanh |

**Giữ nguyên**: `fcitx5` (gõ tiếng Việt), `plank`, `novabar`, `ulauncher`,
`conky`, `nm-applet` (mạng), `xfce4-power-manager`, `print-applet` (in ấn),
`pipewire` (âm thanh).

### Bật lại / tuỳ chỉnh

- Script tự sao lưu sang `~/.config/autostart-backup-<ngày-giờ>/` trước khi đổi.
- Bật lại một app: xoá file của nó trong `~/.config/autostart/`, ví dụ:
  ```bash
  rm ~/.config/autostart/blueman.desktop
  ```
- Muốn tắt thêm / bớt: sửa mảng `DISABLE=( … )` trong `optimize.sh`.
- Xem app nào đang bị tắt:
  ```bash
  grep -l "Hidden=true" ~/.config/autostart/*.desktop
  ```

---

## 4. zram — nén RAM làm swap

Khi RAM ít, kernel buộc phải đẩy bớt ra **swap**. Swap trên đĩa (nhất là file
swap trong VM) **rất chậm** → giật. **zram** tạo một vùng swap nằm trong RAM
nhưng **được nén** (zstd), nên:

- Truy cập nhanh hơn swap đĩa hàng chục lần.
- ~50% RAM được nén lại, thường đạt tỉ lệ nén 2–3× → như có thêm RAM.
- Ưu tiên (priority 100) cao hơn swap đĩa → kernel dùng zram trước.

Cấu hình script ghi vào `/etc/default/zramswap`:

```ini
ALGO=zstd      # thuật toán nén nhanh, tỉ lệ tốt
PERCENT=50     # dùng 50% RAM làm zram
PRIORITY=100   # ưu tiên cao hơn swap đĩa
```

Kiểm tra sau khi bật:

```bash
zramctl              # xem thiết bị zram + tỉ lệ nén
swapon --show        # zram phải có PRIO cao hơn swap đĩa
```

Quản lý dịch vụ (sysVinit):

```bash
sudo service zramswap status
sudo service zramswap restart
```

---

## 5. Tinh chỉnh bộ nhớ (sysctl)

Script ghi `/etc/sysctl.d/99-macos-optimize.conf`:

```ini
vm.swappiness = 100        # đã có zram nhanh → cứ swap mạnh tay, nhả RAM sớm
vm.vfs_cache_pressure = 50 # giữ cache thư mục/inode lâu hơn → mở lại nhanh
```

> **Vì sao `swappiness = 100`?** Khi swap nằm trên đĩa chậm, ta để số thấp
> (MX mặc định 15) để **tránh** swap. Nhưng khi swap là **zram trong RAM**,
> swap lại *rẻ* → đặt cao để kernel nhả các trang ít dùng sang zram, dành RAM
> thật cho việc đang làm.

Áp dụng lại thủ công nếu cần:

```bash
sudo sysctl -p /etc/sysctl.d/99-macos-optimize.conf
```

Hoàn tác: xoá file đó rồi khởi động lại.

---

## 6. Sau khi chạy

- **Đăng xuất rồi đăng nhập lại** (hoặc khởi động lại) để autostart có hiệu lực.
- Kiểm tra kết quả:
  ```bash
  free -h      # xem RAM/swap còn trống
  zramctl      # xem zram hoạt động + tỉ lệ nén
  ```

---

## 7. Gỡ bỏ tối ưu

| Phần | Cách hoàn tác |
|------|---------------|
| Autostart | Xoá các file `Hidden=true` trong `~/.config/autostart/`, hoặc khôi phục từ thư mục sao lưu |
| sysctl | `sudo rm /etc/sysctl.d/99-macos-optimize.conf` rồi khởi động lại |
| zram | `sudo apt-get remove --purge zram-tools` |
