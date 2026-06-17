#!/usr/bin/env bash
# OS detection and privilege checks

os_require_root() {
    if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
        ui_die "Запустите утилиту от root: sudo socksctl $*" 1
    fi
}

os_detect() {
    OS_ID=""
    OS_VERSION_ID=""
    OS_PRETTY=""

    if [[ -f /etc/os-release ]]; then
        # shellcheck disable=SC1091
        source /etc/os-release
        OS_ID="${ID:-}"
        OS_VERSION_ID="${VERSION_ID:-}"
        OS_PRETTY="${PRETTY_NAME:-$ID $VERSION_ID}"
    else
        ui_die "Не удалось определить операционную систему (/etc/os-release отсутствует)." 1
    fi
}

os_check_supported() {
    os_detect

    local major="${OS_VERSION_ID%%.*}"

    case "$OS_ID" in
        ubuntu)
            case "$major" in
                20|22|24)
                    ui_step_ok "${OS_PRETTY} detected"
                    return 0
                    ;;
            esac
            ;;
        debian)
            if [[ "$major" -ge 11 ]]; then
                ui_step_ok "${OS_PRETTY} detected"
                return 0
            fi
            ;;
    esac

    ui_step_fail "Эта система пока не поддерживается."
    echo
    ui_err "Поддерживаются Ubuntu 20.04/22.04/24.04 и Debian 11+."
    echo "  Обнаружено: ${OS_PRETTY:-unknown}"
    exit 1
}

os_check_port_available() {
    local host="$1"
    local port="$2"

    if command -v ss >/dev/null 2>&1; then
        if ss -ltn "( sport = :$port )" 2>/dev/null | grep -q ":$port"; then
            ui_warn "Порт $port уже занят на системе."
            return 1
        fi
    elif command -v netstat >/dev/null 2>&1; then
        if netstat -ltn 2>/dev/null | grep -q ":$port "; then
            ui_warn "Порт $port уже занят на системе."
            return 1
        fi
    fi

    return 0
}
