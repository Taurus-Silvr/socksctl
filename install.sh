#!/usr/bin/env bash
set -euo pipefail

SOCKSCTL_REPO="${SOCKSCTL_REPO:-Taurus-Silvr/socksctl}"
SOCKSCTL_BRANCH="${SOCKSCTL_BRANCH:-main}"
INSTALL_BIN="/usr/local/bin/socksctl"
INSTALL_LIB="/usr/local/lib/socksctl"
SCRIPT_DIR=""
SOCKSCTL_TMPDIR=""
RAW_BASE="https://raw.githubusercontent.com/${SOCKSCTL_REPO}/${SOCKSCTL_BRANCH}"
CURL_OPTS=(--connect-timeout 15 --max-time 180 --retry 2 --retry-delay 2)

log() {
    echo "$@" >&2
}

cleanup() {
    if [[ -n "$SOCKSCTL_TMPDIR" && -d "$SOCKSCTL_TMPDIR" ]]; then
        rm -rf "$SOCKSCTL_TMPDIR"
    fi
}

strip_crlf() {
    local target="$1"
    [[ -f "$target" ]] || return 0
    if grep -q $'\r' "$target" 2>/dev/null; then
        sed -i 's/\r$//' "$target"
    fi
}

curl_download() {
    local url="$1"
    local out="$2"
    log "     → $url"
    if ! curl -fsSL "${CURL_OPTS[@]}" "$url" -o "$out"; then
        return 1
    fi
    return 0
}

is_local_install() {
    local src="${1:-}"
    local dir=""

    [[ -n "$src" && "$src" != "-" && "$src" != "bash" ]] || return 1
    [[ -f "$src" ]] || return 1

    dir="$(cd "$(dirname "$src")" && pwd)"
    [[ -f "${dir}/socksctl" && -d "${dir}/lib" ]]
}

download_via_tarball() {
    local tmp="$1"
    local tarball_url="https://github.com/${SOCKSCTL_REPO}/archive/refs/heads/${SOCKSCTL_BRANCH}.tar.gz"

    log "==> Способ 1: архив с github.com ..."
    if curl -fSL "${CURL_OPTS[@]}" "$tarball_url" | tar xz -C "$tmp" --strip-components=1 2>/dev/null; then
        [[ -f "$tmp/socksctl" && -d "$tmp/lib" ]]
        return $?
    fi
    return 1
}

download_via_raw() {
    local tmp="$1"
    local lib

    log "==> Способ 2: файлы с raw.githubusercontent.com ..."
    mkdir -p "$tmp/lib"

    curl_download "${RAW_BASE}/socksctl" "$tmp/socksctl" || return 1
    curl_download "${RAW_BASE}/install.sh" "$tmp/install.sh" || true

    for lib in ui os config deps ssh systemd check; do
        curl_download "${RAW_BASE}/lib/${lib}.sh" "$tmp/lib/${lib}.sh" || return 1
    done

    chmod +x "$tmp/socksctl"
    return 0
}

resolve_source_dir() {
    local src="${BASH_SOURCE[0]:-}"

    if is_local_install "$src"; then
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

    log "==> Скачиваю socksctl (${SOCKSCTL_REPO}@${SOCKSCTL_BRANCH})..."

    if ! command -v curl >/dev/null 2>&1; then
        log "Ошибка: нужен curl."
        log "  apt install -y curl"
        exit 1
    fi

    if download_via_tarball "$tmp" || download_via_raw "$tmp"; then
        log "==> Исходники скачаны."
        echo "$tmp"
        return 0
    fi

    log ""
    log "Ошибка: не удалось скачать socksctl с GitHub."
    log ""
    log "Возможные причины:"
    log "  - GitHub недоступен или заблокирован в вашей сети"
    log "  - нет интернета / DNS"
    log ""
    log "Проверка:"
    log "  curl -I --connect-timeout 10 https://raw.githubusercontent.com/${SOCKSCTL_REPO}/${SOCKSCTL_BRANCH}/install.sh"
    log ""
    log "Альтернатива — git clone:"
    log "  git clone https://github.com/${SOCKSCTL_REPO}.git && cd socksctl && sudo bash install.sh"
    log ""
    log "Или залейте папку socksctl через SFTP и запустите: sudo bash install.sh"
    exit 1
}

install_files() {
    strip_crlf "${SCRIPT_DIR}/socksctl"
    [[ -f "${SCRIPT_DIR}/install.sh" ]] && strip_crlf "${SCRIPT_DIR}/install.sh"
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

log "==> socksctl installer"
log ""

if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
    log "Запустите от root:"
    log "  curl -fsSL ${RAW_BASE}/install.sh | sudo bash"
    exit 1
fi

SCRIPT_DIR="$(resolve_source_dir)"

log "==> Устанавливаю socksctl в ${INSTALL_BIN} ..."
install_files

log "==> socksctl установлен."
log "==> Запускаю мастер установки ..."
log ""

exec "$INSTALL_BIN" install "$@"
