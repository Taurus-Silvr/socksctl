#!/usr/bin/env bash
# Health checks and doctor

check_port_listening() {
    config_load
    local host="$LISTEN_HOST"
    local port="$LISTEN_PORT"

    if [[ "$host" == "0.0.0.0" ]]; then
        host="127.0.0.1"
    fi

    if command -v nc >/dev/null 2>&1; then
        if nc -z "$host" "$port" 2>/dev/null; then
            return 0
        fi
    fi

    if command -v ss >/dev/null 2>&1; then
        if ss -ltn "sport = :$port" 2>/dev/null | grep -q ":$port"; then
            return 0
        fi
    fi

    return 1
}

check_socks_curl() {
    config_load
    local host="$LISTEN_HOST"
    local port="$LISTEN_PORT"
    local result

    if [[ "$host" == "0.0.0.0" ]]; then
        host="127.0.0.1"
    fi

    result="$(curl -fsS --max-time 20 --socks5-hostname "${host}:${port}" https://ifconfig.me 2>/dev/null || true)"
    if [[ -n "$result" ]]; then
        CHECK_EXTERNAL_IP="$result"
        return 0
    fi

    return 1
}

check_verify_install() {
    config_load

    ui_step_begin "Проверка SOCKS5-прокси"

    if ! systemd_is_active; then
        ui_step_fail "systemd-сервис не активен."
        systemd_show_failure_logs
        return 1
    fi
    ui_info "systemd-сервис active"

    if ! check_port_listening; then
        ui_step_fail "Локальный порт ${LISTEN_HOST}:${LISTEN_PORT} не слушается."
        systemd_show_failure_logs
        return 1
    fi
    ui_info "Порт ${LISTEN_PORT} слушается"

    ui_spinner_start "Проверяю SOCKS5 через curl"
    if check_socks_curl; then
        ui_spinner_stop 1 "SOCKS5 работает, внешний IP: ${CHECK_EXTERNAL_IP}"
    else
        ui_spinner_stop 0 "SOCKS5 не отвечает через curl."
        systemd_show_failure_logs
        ui_info "Что проверить:"
        ui_info "- доступен ли внешний сервер ${SSH_HOST}"
        ui_info "- корректен ли SSH-ключ"
        ui_info "- логи: journalctl -u $SERVICE_NAME -n 30"
        return 1
    fi

    echo
    ui_ok "Установка завершена"
    return 0
}

check_run_doctor() {
    local failed=0

    ui_header "socksctl doctor"
    echo

    ui_bold
    echo "  Зависимости"
    ui_reset
    if deps_check; then
        :
    else
        failed=1
    fi
    echo

    ui_bold
    echo "  SSH-ключ"
    ui_reset
    config_load
    if [[ -f "$KEY_PATH" ]]; then
        ui_ok "Ключ найден: $KEY_PATH"
    else
        ui_err "Ключ не найден: $KEY_PATH"
        failed=1
    fi
    echo

    ui_bold
    echo "  Конфигурация"
    ui_reset
    if config_exists; then
        ui_ok "Конфиг: $SOCKSCTL_CONFIG_FILE"
    else
        ui_err "Конфиг не найден: $SOCKSCTL_CONFIG_FILE"
        failed=1
    fi
    echo

    ui_bold
    echo "  systemd"
    ui_reset
    if systemd_is_active; then
        ui_ok "Сервис $SERVICE_NAME активен"
    else
        ui_err "Сервис $SERVICE_NAME не активен"
        failed=1
    fi
    echo

    ui_bold
    echo "  Порт SOCKS5"
    ui_reset
    if check_port_listening; then
        ui_ok "Порт ${LISTEN_HOST}:${LISTEN_PORT} слушается"
    else
        ui_err "Порт ${LISTEN_HOST}:${LISTEN_PORT} не слушается"
        failed=1
    fi
    echo

    ui_bold
    echo "  SOCKS5 curl"
    ui_reset
    if check_socks_curl; then
        ui_ok "Прокси работает, внешний IP: ${CHECK_EXTERNAL_IP}"
    else
        ui_err "Прокси не отвечает через curl"
        failed=1
    fi
    echo

    ui_bold
    echo "  Внешний SSH"
    ui_reset
    if ssh_test_remote_reachable; then
        :
    else
        failed=1
    fi
    echo

    if [[ "$failed" -eq 0 ]]; then
        ui_ok "Все проверки пройдены"
        return 0
    fi

    ui_err "Обнаружены проблемы. Смотрите подсказки выше."
    return 1
}
