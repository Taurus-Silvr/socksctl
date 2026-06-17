#!/usr/bin/env bash

# curl | bash → скачать архив и re-exec (stdin освобождается для ввода)
SOCKSCTL_REPO="${SOCKSCTL_REPO:-Taurus-Silvr/socksctl}"
SOCKSCTL_BRANCH="${SOCKSCTL_BRANCH:-main}"
TARBALL_URL="https://github.com/${SOCKSCTL_REPO}/archive/refs/heads/${SOCKSCTL_BRANCH}.tar.gz"
CURL_OPTS=(--connect-timeout 30 --max-time 300 --retry 5 --retry-delay 3)

if [[ "${SOCKSCTL_FROM_FILE:-}" != "1" ]]; then
    _src="${BASH_SOURCE[0]:-}"
    if [[ "$_src" == "bash" || "$_src" == "/bin/bash" || "$_src" == "/usr/bin/bash" || "$_src" == "-" ]] \
        || [[ -z "$_src" ]] || [[ ! -f "$_src" ]]; then
        _tmp="$(mktemp -d /tmp/socksctl-bootstrap.XXXXXX)"
        echo "==> Скачиваю socksctl (архив)..." >&2
        if ! curl -fsSL "${CURL_OPTS[@]}" "$TARBALL_URL" | tar xz -C "$_tmp" --strip-components=1; then
            echo "Ошибка: не удалось скачать ${TARBALL_URL}" >&2
            rm -rf "$_tmp"
            exit 1
        fi
        if [[ ! -f "${_tmp}/install.sh" ]]; then
            echo "Ошибка: в архиве нет install.sh" >&2
            rm -rf "$_tmp"
            exit 1
        fi
        sed -i 's/\r$//' "${_tmp}/install.sh" "${_tmp}/socksctl" 2>/dev/null || true
        export SOCKSCTL_FROM_FILE=1
        exec bash "${_tmp}/install.sh" "$@"
    fi
fi

set -euo pipefail

SOCKSCTL_INSTALLER_REV="2026-06-17h"
INSTALL_BIN="/usr/local/bin/socksctl"
INSTALL_LIB="/usr/local/lib/socksctl"
SCRIPT_DIR=""
SOCKSCTL_TMPDIR=""
RAW_BASE="https://raw.githubusercontent.com/${SOCKSCTL_REPO}/${SOCKSCTL_BRANCH}"

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
    local lib

    if [[ ! -f "${dir}/socksctl" || ! -d "${dir}/lib" ]]; then
        log "Ошибка: нет socksctl или lib/ в ${dir}"
        ls -la "$dir" >&2 || true
        return 1
    fi

    for lib in ui os config deps ssh systemd check; do
        if [[ ! -f "${dir}/lib/${lib}.sh" ]]; then
            log "Ошибка: нет lib/${lib}.sh"
            return 1
        fi
    done

    return 0
}

download_from_tarball() {
    local tmp="$1"

    log "==> Скачиваю архив с github.com ..."
    if ! curl -fsSL "${CURL_OPTS[@]}" "$TARBALL_URL" | tar xz -C "$tmp" --strip-components=1; then
        return 1
    fi

    verify_source_tree "$tmp"
}

fetch_install_source() {
    local src="${BASH_SOURCE[0]:-}"

    if is_local_install "$src"; then
        SCRIPT_DIR="$(cd "$(dirname "$src")" && pwd)"
        log "==> Локальные файлы: ${SCRIPT_DIR}"
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
    log "==> Скачиваю в ${SOCKSCTL_TMPDIR} ..."

    if ! download_from_tarball "$SOCKSCTL_TMPDIR"; then
        log ""
        log "Не удалось скачать архив с GitHub."
        log "Попробуйте:"
        log "  curl -fsSL ${RAW_BASE}/get.sh | sh"
        log "  git clone https://github.com/${SOCKSCTL_REPO}.git && cd socksctl && bash install.sh"
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
    log "  curl -fsSL ${RAW_BASE}/get.sh | sh"
    log "  sudo sh -c 'curl -fsSL ${RAW_BASE}/get.sh | sh'"
    exit 1
fi

fetch_install_source

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
