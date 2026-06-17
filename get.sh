#!/bin/sh
# POSIX sh. Работает через: curl -fsSL .../get.sh | sh
# Скачивает архив только с github.com (не raw.githubusercontent.com)
set -e

SOCKSCTL_REPO="${SOCKSCTL_REPO:-Taurus-Silvr/socksctl}"
SOCKSCTL_BRANCH="${SOCKSCTL_BRANCH:-main}"
TARBALL="https://github.com/${SOCKSCTL_REPO}/archive/refs/heads/${SOCKSCTL_BRANCH}.tar.gz"

echo "==> socksctl: скачиваю архив..." >&2

SOCKSCTL_SRC=$(mktemp -d /tmp/socksctl-get.XXXXXX)

if ! curl -fsSL \
    --connect-timeout 30 \
    --max-time 300 \
    --retry 5 \
    --retry-delay 3 \
    "$TARBALL" | tar xz -C "$SOCKSCTL_SRC" --strip-components=1; then
    echo "Ошибка: не удалось скачать $TARBALL" >&2
    rm -rf "$SOCKSCTL_SRC"
    exit 1
fi

if [ ! -f "$SOCKSCTL_SRC/install.sh" ] || [ ! -f "$SOCKSCTL_SRC/socksctl" ]; then
    echo "Ошибка: архив неполный" >&2
    rm -rf "$SOCKSCTL_SRC"
    exit 1
fi

echo "==> socksctl: запускаю установку..." >&2
exec bash "$SOCKSCTL_SRC/install.sh" "$@"
