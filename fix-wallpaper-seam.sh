#!/usr/bin/env bash
# fix-wallpaper-seam.sh
# ---------------------------------------------------------------------------
# Khắc phục "vệt ngang" / wallpaper bị ngắt đoạn trên XFCE (hay gặp trong VM).
# Fix the horizontal seam / cut-off wallpaper on XFCE (common inside a VM).
#
# Nguyên nhân / Cause: KHÔNG phải lỗi ảnh. Đó là compositor xfwm4 để lại
# vùng desktop chưa vẽ lại (stale region) khi có cửa sổ — thường xảy ra khi
# đổi hình nền lúc máy tải nặng, hoặc trên màn hình ảo (Virtual1) trong VM.
# It is NOT an image problem; the xfwm4 compositor leaves a stale desktop
# region behind windows — typical in a VM / under heavy load.
#
# Cách fix / Fix: tắt-bật lại compositor để vẽ lại toàn bộ, rồi reload xfdesktop.
# Toggle the compositor off→on to force a full recomposite, then reload xfdesktop.
# (Chỉ `xfdesktop --reload` là KHÔNG đủ / `xfdesktop --reload` alone is NOT enough.)
# ---------------------------------------------------------------------------
set -u
export DISPLAY="${DISPLAY:-:0.0}"

echo "==> Restarting xfwm4 compositor (off -> on)…"
if [ "$(xfconf-query -c xfwm4 -p /general/use_compositing 2>/dev/null)" = "true" ]; then
  xfconf-query -c xfwm4 -p /general/use_compositing -s false; sleep 2
  xfconf-query -c xfwm4 -p /general/use_compositing -s true;  sleep 1
else
  # compositing was off; turn it on (xfdesktop draws directly, no seam)
  xfconf-query -c xfwm4 -p /general/use_compositing -n -t bool -s true 2>/dev/null \
    || xfconf-query -c xfwm4 -p /general/use_compositing -s true
fi

echo "==> Reloading xfdesktop…"
xfdesktop --reload 2>/dev/null || { pkill -x xfdesktop 2>/dev/null; sleep 1; setsid xfdesktop >/dev/null 2>&1 </dev/null & disown; }

echo "==> Done. Nếu vẫn còn / if it persists, đăng xuất rồi đăng nhập lại / log out and back in."
