#!/bin/bash

# 🎨 رنگ‌ها
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[1;34m'
NC='\033[0m'

clear
echo -e "${BLUE}===========================================${NC}"
echo -e "${GREEN}     Rathole Tunnel Watchdog Installer     ${NC}"
echo -e "${BLUE}===========================================${NC}"

# 🔰 تابع ساخت پرچم از کد کشور
get_flag() {
  local CODE=${1^^}
  local FIRST_CHAR=${CODE:0:1}
  local SECOND_CHAR=${CODE:1:1}
  printf "\U$(printf %x $((0x1F1E6 + $(printf '%d' "'$FIRST_CHAR") - 65)))"
  printf "\U$(printf %x $((0x1F1E6 + $(printf '%d' "'$SECOND_CHAR") - 65)))"
}

# 🌍 تشخیص کشور
echo "🌐 در حال شناسایی موقعیت سرور..."
COUNTRY_NAME=$(curl -s https://ip-api.com/line/?fields=country)
FLAG=$(get_flag "$COUNTRY")

if [[ "$COUNTRY" == "IR" ]]; then
    COUNTRY_NAME="IRAN"
    HEADER_COLOR=$RED
else
    COUNTRY_NAME="FOREIGN"
    HEADER_COLOR=$GREEN
fi

# 🎯 نمایش سربرگ کشور با پرچم
echo -e "${HEADER_COLOR}"
echo    "============================"
echo -e "   Country: $COUNTRY_NAME  $FLAG"
echo    "============================"
echo -e "${NC}"

# 📥 گرفتن IP سمت مقابل
if [[ "$COUNTRY" == "IR" ]]; then
    read -p "🌍 لطفاً IP یا دامنه سرور خارجی را وارد کن: " REMOTE_IP
else
    read -p "🏠 لطفاً IP سرور داخل ایران را وارد کن: " REMOTE_IP
fi

# 📥 گرفتن پورت اینباند
read -p "🔌 لطفاً پورت یکی از اینباندها را وارد کن: " REMOTE_PORT

# ✍️ ذخیره تنظیمات
CONFIG_FILE="/etc/rathole-watchdog.conf"
sudo bash -c "cat > $CONFIG_FILE" << EOF
TARGET_IP=$REMOTE_IP
TARGET_PORT=$REMOTE_PORT
EOF
echo -e "${GREEN}✅ تنظیمات در $CONFIG_FILE ذخیره شد.${NC}"

# 🔁 ساخت اسکریپت watchdog
SCRIPT_PATH="/usr/local/bin/rathole-watchdog.sh"
sudo bash -c "cat > $SCRIPT_PATH" << 'EOF'
#!/bin/bash

CONFIG_FILE="/etc/rathole-watchdog.conf"
[ ! -f "$CONFIG_FILE" ] && echo "⚠️ فایل تنظیمات وجود ندارد." && exit 1
source "$CONFIG_FILE"

DATETIME=$(date '+%Y-%m-%d %H:%M:%S')
LOG="/var/log/rathole-watchdog.log"
RATHOLE_DIR="/root/rathole-core"
TOML_FILE=$(find "$RATHOLE_DIR" -maxdepth 1 -type f -name "*.toml" | head -n 1)

if [ -z "$TOML_FILE" ]; then
  echo "[$DATETIME] ⚠️ فایل .toml پیدا نشد! بررسی متوقف شد." >> "$LOG"
  exit 1
fi

if nc -z -w 5 "$TARGET_IP" "$TARGET_PORT"; then
  echo "[$DATETIME] ✅ تونل سالم است: $TARGET_IP:$TARGET_PORT" >> "$LOG"
else
  echo "[$DATETIME] ❌ تونل قطع است. در حال ریستارت..." >> "$LOG"
  pkill -f rathole
  nohup "$RATHOLE_DIR/rathole" "$TOML_FILE" >/dev/null 2>&1 &
  echo "[$DATETIME] 🔁 Rathole با کانفیگ $TOML_FILE اجرا شد." >> "$LOG"
fi
EOF

sudo chmod +x "$SCRIPT_PATH"
echo -e "${GREEN}✅ اسکریپت بررسی ساخته شد: $SCRIPT_PATH${NC}"

# ⚙️ سرویس systemd
SERVICE_FILE="/etc/systemd/system/rathole-watchdog.service"
sudo bash -c "cat > $SERVICE_FILE" << EOF
[Unit]
Description=Rathole Tunnel Watchdog Service
After=network.target

[Service]
Type=oneshot
ExecStart=$SCRIPT_PATH
EOF

# ⏱ تایمر systemd (هر 90 ثانیه)
TIMER_FILE="/etc/systemd/system/rathole-watchdog.timer"
sudo bash -c "cat > $TIMER_FILE" << EOF
[Unit]
Description=بررسی تونل Rathole هر 90 ثانیه

[Timer]
OnBootSec=10sec
OnUnitActiveSec=90sec
Unit=rathole-watchdog.service

[Install]
WantedBy=timers.target
EOF

# 🚀 فعال‌سازی
sudo systemctl daemon-reexec
sudo systemctl daemon-reload
sudo systemctl enable --now rathole-watchdog.timer

# ✅ پایان
echo -e "${BLUE}===========================================${NC}"
echo -e "${GREEN}✅ نصب کامل شد!${NC}"
echo -e "${BLUE}⏱ تایمر هر 90 ثانیه وضعیت تونل را بررسی می‌کند.${NC}"
echo -e "${BLUE}📂 لاگ‌ها: /var/log/rathole-watchdog.log${NC}"
echo -e "${BLUE}🔁 اگر تونل قطع شود، Rathole  ریستارت خواهد شد.${NC}"
echo -e "${BLUE}🎌 پرچم و موقعیت شناسایی‌شده: $COUNTRY_NAME $FLAG${NC}"
echo -e "${BLUE}===========================================${NC}"
