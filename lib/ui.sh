#!/usr/bin/env bash
# shellcheck disable=SC2034
# UI helpers: colors, logo, spinner, progress steps

UI_NO_COLOR="${UI_NO_COLOR:-0}"
UI_TOTAL_STEPS=8
UI_CURRENT_STEP=0
UI_SPINNER_PID=""

ui_init() {
    if [[ "${NO_COLOR:-}" == "1" ]] || [[ "${UI_NO_COLOR}" == "1" ]]; then
        UI_NO_COLOR=1
    fi
    if [[ ! -t 1 ]]; then
        UI_NO_COLOR=1
    fi
}

ui_tty() {
    if [[ -r /dev/tty ]]; then
        echo /dev/tty
    else
        echo /dev/stdin
    fi
}

ui_color() {
    local code="$1"
    if [[ "${UI_NO_COLOR}" == "1" ]]; then
        return 0
    fi
    printf '\033[%sm' "$code"
}

ui_reset() {
    if [[ "${UI_NO_COLOR}" == "1" ]]; then
        return 0
    fi
    printf '\033[0m'
}

ui_cyan()    { ui_color "1;36"; }
ui_green()   { ui_color "1;32"; }
ui_yellow()  { ui_color "1;33"; }
ui_red()     { ui_color "1;31"; }
ui_dim()     { ui_color "2"; }
ui_bold()    { ui_color "1"; }

ui_print_logo() {
    ui_cyan
    cat <<'EOF'
   ____             _             _   _
  / ___|  ___   ___| | _____  ___| |_| |
  \___ \ / _ \ / __| |/ / __|/ __| __| |
   ___) | (_) | (__|   <\__ \ (__| |_| |
  |____/ \___/ \___|_|\_\___/\___|\__|_|

       SSH SOCKS5 tunnel in one command
EOF
    ui_reset
    echo
}

ui_header() {
    echo
    ui_cyan
    echo "=============================================================="
    printf " %s\n" "$1"
    echo "=============================================================="
    ui_reset
    echo
}

ui_ok() {
    ui_green
    printf '[OK] '
    ui_reset
    printf '%s\n' "$1"
}

ui_warn() {
    ui_yellow
    printf '[!!] '
    ui_reset
    printf '%s\n' "$1"
}

ui_err() {
    ui_red
    printf '[ERR] '
    ui_reset
    printf '%s\n' "$1" >&2
}

ui_info() {
    ui_dim
    printf '     %s\n' "$1"
    ui_reset
}

ui_step_begin() {
    local title="$1"
    UI_CURRENT_STEP=$((UI_CURRENT_STEP + 1))
    ui_bold
    printf '[%d/%d] %s' "$UI_CURRENT_STEP" "$UI_TOTAL_STEPS" "$title"
    ui_reset
    echo
}

ui_step_ok() {
    local detail="${1:-}"
    ui_ok "$detail"
}

ui_step_fail() {
    local detail="$1"
    ui_err "$detail"
}

ui_spinner_start() {
    local msg="$1"
    if [[ ! -t 2 ]] && [[ ! -t 1 ]]; then
        ui_dim
        printf '     [..] %s\n' "$msg" >&2
        ui_reset
        return 0
    fi

    local -a frames=(⠋ ⠙ ⠹ ⠸ ⠼ ⠴ ⠦ ⠧ ⠇ ⠏)
    local i=0 len=${#frames[@]}
    (
        while true; do
            printf '\r\033[K     %s %s' "${frames[$i]}" "$msg" >&2
            i=$(((i + 1) % len))
            sleep 0.08
        done
    ) &
    UI_SPINNER_PID=$!
    disown "$UI_SPINNER_PID" 2>/dev/null || true
}

ui_spinner_stop() {
    local ok="${1:-1}"
    local msg="${2:-}"

    if [[ -n "${UI_SPINNER_PID}" ]]; then
        kill "$UI_SPINNER_PID" 2>/dev/null || true
        wait "$UI_SPINNER_PID" 2>/dev/null || true
        UI_SPINNER_PID=""
        if [[ -t 2 ]] || [[ -t 1 ]]; then
            printf '\r\033[K' >&2
        fi
    fi

    if [[ "$ok" == "1" ]]; then
        ui_ok "$msg"
    else
        ui_err "$msg"
    fi
}

ui_confirm() {
    local prompt="$1"
    local default="${2:-y}"
    local answer

    if [[ "${SOCKSCTL_YES:-0}" == "1" ]]; then
        return 0
    fi

    if [[ "$default" == "y" ]]; then
        printf '%s [Y/n]: ' "$prompt" >&2
    else
        printf '%s [y/N]: ' "$prompt" >&2
    fi

    read -r answer <"$(ui_tty)"
    answer="${answer:-}"

    if [[ -z "$answer" ]]; then
        [[ "$default" == "y" ]]
        return $?
    fi

    case "${answer,,}" in
        y|yes|д|да) return 0 ;;
        *) return 1 ;;
    esac
}

ui_prompt() {
    local prompt="$1"
    local default="${2:-}"
    local value

    if [[ -n "$default" ]]; then
        printf '%s [%s]: ' "$prompt" "$default" >&2
    else
        printf '%s: ' "$prompt" >&2
    fi

    read -r value <"$(ui_tty)"
    if [[ -z "$value" ]]; then
        value="$default"
    fi
    printf '%s' "$value"
}

ui_prompt_secret() {
    local prompt="$1"
    local value

    printf '%s: ' "$prompt" >&2
    read -rs value <"$(ui_tty)"
    echo >&2
    printf '%s' "$value"
}

ui_summary_box() {
    local -n _lines=$1
    echo
    ui_bold
    echo "  Проверь настройки:"
    ui_reset
    echo
    local line
    for line in "${_lines[@]}"; do
        printf '    %s\n' "$line"
    done
    echo
}

ui_final_success() {
    local listen_host="$1"
    local listen_port="$2"

    ui_header "Готово!"

    ui_bold
    echo "  SOCKS5-прокси:"
    ui_reset
    printf '    socks5h://%s:%s\n' "$listen_host" "$listen_port"
    echo
    ui_dim
    echo "  Для curl:"
    printf '    curl --socks5-hostname %s:%s https://ifconfig.me\n' "$listen_host" "$listen_port"
    echo
    echo "  Управление:"
    echo "    sudo socksctl status"
    echo "    sudo socksctl logs"
    echo "    sudo socksctl restart"
    echo "    sudo socksctl uninstall"
    ui_reset
    echo
}

ui_die() {
    ui_err "$1"
    exit "${2:-1}"
}
