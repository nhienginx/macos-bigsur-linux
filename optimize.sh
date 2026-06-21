#!/usr/bin/env bash
#
# optimize.sh — Tối ưu hiệu năng cho bản dựng macOS trên MX Linux 25
#               (XFCE + novabar + Plank), ưu tiên máy RAM ít / chạy trong VM.
#
# Script này:
#   1. Dò môi trường (RAM, swap, có phải máy ảo không) để đưa lời khuyên đúng.
#   2. Tắt các ứng dụng tự khởi động (autostart) thừa — per-user, có sao lưu,
#      KHÔNG cần root. Giữ nguyên fcitx5, Plank, novabar, Ulauncher, mạng…
#   3. Bật zram (nén RAM làm swap) qua gói zram-tools — chạy tốt với sysVinit
#      của MX Linux (không cần systemd).
#   4. Tinh chỉnh sysctl (vm.swappiness, vfs_cache_pressure) cho hợp với zram.
#   5. In hướng dẫn tinh chỉnh phía VirtualBox (host) — phần này không tự động
#      được vì nằm ngoài Linux.
#
# An toàn chạy lại nhiều lần (idempotent). Phần 3 & 4 cần sudo (sẽ hỏi mật khẩu).
#
set -euo pipefail

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
section() { printf '\n\033[1;34m==> %s\033[0m\n' "$*"; }
info()    { printf '    %s\n' "$*"; }
warn()    { printf '\033[1;33m    ! %s\033[0m\n' "$*"; }
die()     { printf '\033[1;31m!! %s\033[0m\n' "$*" >&2; exit 1; }

[ "$(id -u)" -ne 0 ] || die "Đừng chạy bằng root/sudo trực tiếp. Chạy ./optimize.sh — script tự gọi sudo khi cần."

# ---------------------------------------------------------------------------
# 1. Dò môi trường
# ---------------------------------------------------------------------------
section "Dò môi trường"
RAM_MB=$(awk '/MemTotal/{printf "%d", $2/1024}' /proc/meminfo)
PRODUCT=$(cat /sys/class/dmi/id/product_name 2>/dev/null || echo "unknown")
IS_VM=0
case "${PRODUCT}" in
  *VirtualBox*|*VMware*|*KVM*|*QEMU*|*Bochs*) IS_VM=1 ;;
esac
info "RAM: ${RAM_MB} MB"
info "Phần cứng: ${PRODUCT}  $([ "${IS_VM}" -eq 1 ] && echo '(máy ảo)' || echo '(máy thật)')"
if swapon --show >/dev/null 2>&1 && [ -n "$(swapon --show 2>/dev/null)" ]; then
  info "Swap hiện có:"; swapon --show | sed 's/^/      /'
fi

# ---------------------------------------------------------------------------
# 2. Dọn autostart thừa (KHÔNG cần root)
# ---------------------------------------------------------------------------
section "Dọn ứng dụng tự khởi động thừa"

# Các app an toàn để tắt cho cấu hình macOS-theme chạy trong VM / máy RAM ít.
# Mỗi dòng là tên file .desktop (chuẩn XDG) trong /etc/xdg/autostart hoặc
# ~/.config/autostart. Bỏ bớt khỏi mảng nếu bạn thực sự cần tính năng đó.
DISABLE=(
  "orca-autostart"     # trình đọc màn hình (trợ năng cho người khiếm thị)
  "onboard-autostart"  # bàn phím ảo trên màn hình
  "magnus-autostart"   # kính lúp phóng to màn hình
  "blueman"            # Bluetooth applet
  "Blueman-start"      # Bluetooth (khởi động)
  "spice-vdagent"      # guest agent cho QEMU/SPICE — vô dụng trên VirtualBox
  "zstartup-sound"     # âm thanh khi đăng nhập
)

AUTOSTART_DIR="${HOME}/.config/autostart"
mkdir -p "${AUTOSTART_DIR}"
BACKUP_DIR="${HOME}/.config/autostart-backup-$(date +%Y%m%d-%H%M%S)"
cp -a "${AUTOSTART_DIR}/." "${BACKUP_DIR}/" 2>/dev/null && \
  info "Đã sao lưu autostart hiện tại → ${BACKUP_DIR}"

for name in "${DISABLE[@]}"; do
  f="${AUTOSTART_DIR}/${name}.desktop"
  if grep -qs "X-MX-Disabled-By=optimize-script" "${f}" 2>/dev/null; then
    info "đã tắt sẵn: ${name}"
    continue
  fi
  printf '[Desktop Entry]\nType=Application\nName=%s\nHidden=true\nX-MX-Disabled-By=optimize-script\n' \
    "${name}" > "${f}"
  info "✗ tắt: ${name}"
done
info "Khôi phục bất cứ lúc nào: xoá file tương ứng trong ${AUTOSTART_DIR}"
info "hoặc chép lại từ thư mục sao lưu ở trên."

# ---------------------------------------------------------------------------
# 3. Bật zram (nén RAM làm swap) — cần root
# ---------------------------------------------------------------------------
section "Bật zram (nén RAM làm swap)"
if ! command -v sudo >/dev/null; then
  warn "Không có sudo — bỏ qua zram. Cài thủ công gói 'zram-tools' với quyền root."
else
  if ! dpkg -l zram-tools 2>/dev/null | grep -q '^ii'; then
    info "Cài gói zram-tools (tương thích sysVinit của MX)…"
    sudo apt-get update -qq
    sudo apt-get install -y zram-tools || warn "Cài zram-tools thất bại — kiểm tra mạng/kho phần mềm."
  else
    info "zram-tools đã được cài."
  fi

  # Cấu hình: nén ~50% RAM bằng zstd, ưu tiên cao hơn swap trên đĩa.
  if dpkg -l zram-tools 2>/dev/null | grep -q '^ii'; then
    info "Ghi cấu hình /etc/default/zramswap (zstd, 50% RAM, priority 100)…"
    sudo tee /etc/default/zramswap >/dev/null <<'EOF'
# Cấu hình bởi optimize.sh (macos-bigsur-linux)
ALGO=zstd
PERCENT=50
PRIORITY=100
EOF
    # MX dùng sysVinit → dùng 'service', không phải 'systemctl'.
    sudo service zramswap restart 2>/dev/null || sudo service zramswap start 2>/dev/null || \
      warn "Không khởi động được dịch vụ zramswap — kiểm tra: sudo service zramswap status"
    info "zram đang chạy:"; zramctl 2>/dev/null | sed 's/^/      /' || true
  fi
fi

# ---------------------------------------------------------------------------
# 4. Tinh chỉnh sysctl cho hợp với zram — cần root
# ---------------------------------------------------------------------------
section "Tinh chỉnh bộ nhớ (sysctl)"
if command -v sudo >/dev/null; then
  info "Ghi /etc/sysctl.d/99-macos-optimize.conf…"
  sudo tee /etc/sysctl.d/99-macos-optimize.conf >/dev/null <<'EOF'
# Cấu hình bởi optimize.sh (macos-bigsur-linux)
# Có zram (swap RAM nhanh) nên swap mạnh tay hơn được — ưu tiên nhả RAM.
vm.swappiness = 100
# Giữ lại cache thư mục/inode lâu hơn → mở lại app/thư mục nhanh hơn.
vm.vfs_cache_pressure = 50
EOF
  sudo sysctl -p /etc/sysctl.d/99-macos-optimize.conf >/dev/null && \
    info "Đã áp dụng: swappiness=100, vfs_cache_pressure=50"
else
  warn "Không có sudo — bỏ qua sysctl."
fi

# ---------------------------------------------------------------------------
# 5. Lời khuyên phía VirtualBox (host) — không tự động được
# ---------------------------------------------------------------------------
if [ "${IS_VM}" -eq 1 ]; then
  section "Tinh chỉnh phía VirtualBox (làm trên máy host, KHÔNG tự động được)"
  warn "Đây là việc có tác động LỚN NHẤT tới độ mượt. Tắt máy ảo rồi vào Settings:"
  info "• System → Motherboard: RAM 6144–8192 MB (hiện ${RAM_MB} MB là hơi ít)"
  info "• System → Processor:   tăng số nhân CPU (vd 4 nhân)"
  info "• Display → Screen:     Video Memory 128 MB + tick 'Enable 3D Acceleration'"
  info "                        Graphics Controller: VMSVGA"
  info "• Storage:              tick 'Solid-state Drive' nếu ổ host là SSD"
fi

# ---------------------------------------------------------------------------
# 6. Tổng kết
# ---------------------------------------------------------------------------
section "Hoàn tất"
info "Đăng xuất rồi đăng nhập lại (hoặc khởi động lại) để autostart có hiệu lực."
info "Kiểm tra RAM/zram sau khi vào lại:  free -h ; zramctl"
