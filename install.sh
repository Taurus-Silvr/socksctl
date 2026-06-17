#!/usr/bin/env bash
set -euo pipefail

SOCKSCTL_REPO="${SOCKSCTL_REPO:-Taurus-Silvr/socksctl}"
SOCKSCTL_BRANCH="${SOCKSCTL_BRANCH:-main}"
INSTALL_BIN="/usr/local/bin/socksctl"
INSTALL_LIB="/usr/local/lib/socksctl"
SCRIPT_DIR=""
SOCKSCTL_TMPDIR=""

cleanup() {
    if [[ -n "$SOCKSCTL_TMPDIR" && -d "$SOCKSCTL_TMPDIR" ]]; then
        rm -rf "$SOCKSCTL_TMPDIR"
    fi
}

strip_crlf() {
    local target="$1"
    if grep -q $'\r' "$target" 2>/dev/null; then
        sed -i 's/\r$//' "$target"
    fi
}

resolve_source_dir() {
    local src="${BASH_SOURCE[0]:-}"

    if [[ -n "$src" && "$src" != "-" && -f "$src" ]]; then
        cd "$(dirname "$src")" && pwd
        return 0
    fi

    if [[ -n "${SOCKSCTL_SOURCE_DIR:-}" && -d "$SOCKSCTL_SOURCE_DIR" ]]; then
        cd "$SOCKSCTL_SOURCE_DIR" && pwd
        return 0
    fi

    local tmp
    tmp="$(mktemp -d /tmp/socksctl-install.XXXXXX)"
    SOCKSCTL_TMPDIR="$tmp"
    trap cleanup EXIT

    echo "==> Скачиваю socksctl с GitHub (${SOCKSCTL_REPO})..." >&2

    if ! command -v curl >/dev/null 2>&1 && ! command -v wget >/dev/null 2>&1; then
        echo "Ошибка: нужен curl или wget для установки." >&2
        exit 1
    fi

    local tarball_url="https://github.com/${SOCKSCTL_REPO}/archive/refs/heads/${SOCKSCTL_BRANCH}.tar.gz"

    if command -v curl >/dev/null 2>&1; then
        curl -fsSL "$tarball_url" | tar xz -C "$tmp" --strip-components=1
    else
        wget -qO- "$tarball_url" | tar xz -C "$tmp" --strip-components=1
    fi

    if [[ ! -f "$tmp/socksctl" || ! -d "$tmp/lib" ]]; then
        echo "Ошибка: не удалось скачать файлы socksctl." >&2
        exit 1
    fi

    echo "$tmp"
}

install_files() {
    strip_crlf "${SCRIPT_DIR}/socksctl"
    strip_crlf "${SCRIPT_DIR}/install.sh"
    for libfile in "${SCRIPT_DIR}"/lib/*.sh; do
        [[ -f "$libfile" ]] && strip_crlf "$libfile"
    done

    install -m 755 "${SCRIPT_DIR}/socksctl" "$INSTALL_BIN"
    mkdir -p "$INSTALL_LIB"
    rm -rf "${INSTALL_LIB:?}/"*
    cp -a "${SCRIPT_DIR}/lib/." "$INSTALL_LIB/"

    while IFS= read -r -d '' installed; do
        strip_crlf "$installed"
    done < <(find "$INSTALL_LIB" -type f -print0)
    strip_crlf "$INSTALL_BIN"
}

if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
    echo "Запустите от root:" >&2
    echo "  curl -fsSL https://raw.githubusercontent.com/${SOCKSCTL_REPO}/${SOCKSCTL_BRANCH}/install.sh | sudo bash" >&2
    exit 1
fi

SCRIPT_DIR="$(resolve_source_dir)"

echo "==> Устанавливаю socksctl..."
install_files

echo "==> socksctl установлен в $INSTALL_BIN"
echo "==> Запускаю мастер установки..."
echo

exec "$INSTALL_BIN" install "$@"
