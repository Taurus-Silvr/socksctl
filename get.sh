#!/usr/bin/env sh
# One-liner: один архив с github.com (без raw.githubusercontent.com)
set -e

SOCKSCTL_REPO="${SOCKSCTL_REPO:-Taurus-Silvr/socksctl}"
SOCKSCTL_BRANCH="${SOCKSCTL_BRANCH:-main}"
SOCKSCTL_TMPDIR="${SOCKSCTL_TMPDIR:-$(mktemp -d /tmp/socksctl-get.XXXXXX)}"
TARBALL_URL="https://github.com/${SOCKSCTL_REPO}/archive/refs/heads/${SOCKSCTL_BRANCH}.tar.gz"

echo "==> Скачиваю socksctl (архив)..." >&2

if ! curl -fsSL \
    --connect-timeout 30 \
    --max-time 300 \
    --retry 5 \
    --retry-delay 3 \
    "$TARBALL_URL" | tar xz -C "$SOCKSCTL_TMPDIR" --strip-components=1; then
    echo "Ошибка: не удалось скачать ${TARBALL_URL}" >&2
    rm -rf "$SOCKSCTL_TMPDIR"
    exit 1
fi

if [[ ! -f "${SOCKSCTL_TMPDIR}/install.sh" || ! -f "${SOCKSCTL_TMPDIR}/socksctl" ]]; then
    echo "Ошибка: архив повреждён или неполный" >&2
    rm -rf "$SOCKSCTL_TMPDIR"
    exit 1
fi

sed -i 's/\r$//' "${SOCKSCTL_TMPDIR}/install.sh" "${SOCKSCTL_TMPDIR}/socksctl" 2>/dev/null || true
for f in "${SOCKSCTL_TMPDIR}"/lib/*.sh; do
    [[ -f "$f" ]] && sed -i 's/\r$//' "$f" 2>/dev/null || true
done

echo "==> Запускаю установку..." >&2
exec bash "${SOCKSCTL_TMPDIR}/install.sh" "$@"
