#!/usr/bin/env bash

# curl | bash: stdin занят скриптом → re-exec из файла, чтобы работали read/prompt
SOCKSCTL_INSTALL_URL="${SOCKSCTL_INSTALL_URL:-https://raw.githubusercontent.com/Taurus-Silvr/socksctl/main/install.sh}"

if [[ "${SOCKSCTL_FROM_FILE:-}" != "1" ]]; then
    _src="${BASH_SOURCE[0]:-}"
    if [[ "$_src" == "bash" || "$_src" == "/bin/bash" || "$_src" == "/usr/bin/bash" || "$_src" == "-" ]] \
        || [[ -z "$_src" ]] || [[ ! -f "$_src" ]]; then
        _tmp="$(mktemp /tmp/socksctl-bootstrap.XXXXXX.sh)"
        echo "==> Загружаю установщик..." >&2
        if ! curl -fsSL --connect-timeout 15 --max-time 120 "$SOCKSCTL_INSTALL_URL" -o "$_tmp"; then
            echo "Ошибка: не удалось скачать ${SOCKSCTL_INSTALL_URL}" >&2
            rm -f "$_tmp"
            exit 1
        fi
        sed -i 's/\r$//' "$_tmp"
        chmod +x "$_tmp"
        export SOCKSCTL_FROM_FILE=1
        exec bash "$_tmp" "$@"
    fi
fi

set -euo pipefail

SOCKSCTL_INSTALLER_REV="2026-06-17e"
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

strip_crlf() {
    local target="$1"
    [[ -f "$target" ]] || return 0
    if grep -q $'\r' "$target" 2>/dev/null; then
        sed -i 's/\r$//' "$target"
    fi
}

is_local_install() {
    local src="${1:-}"
    local dir=""

    [[ -n "$src" && "$src" != "-" && "$src" != "bash" ]] || return 1
    [[ -f "$src" ]] || return 1

    dir="$(cd "$(dirname "$src")" && pwd)"
    [[ -f "${dir}/socksctl" && -d "${dir}/lib" ]]
}

verify_source_tree() {
    local dir="$1"

    if [[ -f "${dir}/socksctl" && -d "${dir}/lib" ]]; then
        return 0
    fi

    log "Ошибка: после загрузки нет socksctl или lib/ в ${dir}"
    log "Содержимое каталога:"
    ls -la "$dir" >&2 || true
    [[ -d "${dir}/lib" ]] && ls -la "${dir}/lib" >&2 || true
    return 1
}

download_file() {
    local url="$1"
    local out="$2"
    curl -fsSL "${CURL_OPTS[@]}" "$url" -o "$out"
}

download_from_github() {
    local tmp="$1"
    local lib

    mkdir -p "${tmp}/lib"

    log "     socksctl"
    download_file "${RAW_BASE}/socksctl" "${tmp}/socksctl"

    for lib in ui os config deps ssh systemd check; do
        log "     lib/${lib}.sh"
        download_file "${RAW_BASE}/lib/${lib}.sh" "${tmp}/lib/${lib}.sh"
    done

    chmod +x "${tmp}/socksctl"
    verify_source_tree "$tmp"
}

resolve_source_dir() {
    local src="${BASH_SOURCE[0]:-}"

    if is_local_install "$src"; then
        SCRIPT_DIR="$(cd "$(dirname "$src")" && pwd)"
        return 0
    fi

    if [[ -n "${SOCKSCTL_SOURCE_DIR:-}" && -d "$SOCKSCTL_SOURCE_DIR" ]]; then
        SCRIPT_DIR="$(cd "$SOCKSCTL_SOURCE_DIR" && pwd)"
        return 0
    fi

    if ! command -v curl >/dev/null 2>&1; then
        log "Ошибка: нужен curl (apt install -y curl)"
        exit 1
    fi

    SOCKSCTL_TMPDIR="$(mktemp -d /tmp/socksctl-install.XXXXXX)"
    log "==> Скачиваю файлы в ${SOCKSCTL_TMPDIR} ..."

    if ! download_from_github "$SOCKSCTL_TMPDIR"; then
        log ""
        log "Не удалось скачать socksctl с GitHub."
        log "Попробуйте: git clone https://github.com/${SOCKSCTL_REPO}.git && cd socksctl && sudo bash install.sh"
        rm -rf "$SOCKSCTL_TMPDIR"
        exit 1
    fi

    SCRIPT_DIR="$SOCKSCTL_TMPDIR"
    log "==> Файлы на месте."
}

install_files() {
    verify_source_tree "$SCRIPT_DIR"

    strip_crlf "${SCRIPT_DIR}/socksctl"
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

log "==> socksctl installer ${SOCKSCTL_INSTALLER_REV}"
log ""

if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
    log "Запустите от root:"
    log "  curl -fsSL ${RAW_BASE}/install.sh | sudo bash"
    exit 1
fi

resolve_source_di

log "==> Устанавливаю в ${INSTALL_BIN} ..."
install_files

if [[ -n "$SOCKSCTL_TMPDIR" && -d "$SOCKSCTL_TMPDIR" ]]; then
    rm -rf "$SOCKSCTL_TMPDIR"
    SOCKSCTL_TMPDIR=""
fi

log "==> socksctl установлен."
log "==> Запускаю мастер установки ..."
log ""

exec "$INSTALL_BIN" install "$@"
