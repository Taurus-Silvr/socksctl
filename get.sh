#!/usr/bin/env sh
# Мини-обёртка для one-liner. Не используйте: curl ... | sudo bash
set -e
SOCKSCTL_INSTALL_URL="${SOCKSCTL_INSTALL_URL:-https://raw.githubusercontent.com/Taurus-Silvr/socksctl/main/install.sh}"
SOCKSCTL_INSTALL_FILE="${SOCKSCTL_INSTALL_FILE:-/tmp/socksctl-install.sh}"

echo "==> Скачиваю socksctl..." >&2
curl -fsSL --connect-timeout 15 --max-time 120 "$SOCKSCTL_INSTALL_URL" -o "$SOCKSCTL_INSTALL_FILE"
sed -i 's/\r$//' "$SOCKSCTL_INSTALL_FILE" 2>/dev/null || sed -i '' 's/\r$//' "$SOCKSCTL_INSTALL_FILE" 2>/dev/null || true
chmod +x "$SOCKSCTL_INSTALL_FILE"
exec bash "$SOCKSCTL_INSTALL_FILE" "$@"
