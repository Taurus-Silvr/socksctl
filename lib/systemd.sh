#!/usr/bin/env bash
# systemd service management

SYSTEMD_UNIT_PATH="/etc/systemd/system"

systemd_unit_file() {
    printf '%s/%s.service' "$SYSTEMD_UNIT_PATH" "$SERVICE_NAME"
}

systemd_build_exec_start() {
    printf '/usr/bin/autossh -M 0 -N -i %s -o ExitOnForwardFailure=yes -o ServerAliveInterval=30 -o ServerAliveCountMax=3 -D %s:%s -p %s %s@%s' \
        "$KEY_PATH" "$LISTEN_HOST" "$LISTEN_PORT" "$SSH_PORT" "$SSH_USER" "$SSH_HOST"
}

systemd_write_unit() {
    local unit_file exec_start
    unit_file="$(systemd_unit_file)"
    exec_start="$(systemd_build_exec_start)"

    cat > "$unit_file" <<EOF
[Unit]
Description=socksctl persistent SSH SOCKS5 tunnel
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
Environment="AUTOSSH_GATETIME=0"
ExecStart=${exec_start}
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

    ui_step_ok "Сервис создан: $(basename "$unit_file")"
}

systemd_enable_start() {
    ui_spinner_start "Запускаю systemd-сервис"

    systemctl daemon-reload

    if ! systemctl enable "$SERVICE_NAME" >/dev/null 2>&1; then
        ui_spinner_stop 0 "Не удалось включить автозапуск сервиса."
        return 1
    fi

    if ! systemctl restart "$SERVICE_NAME"; then
        ui_spinner_stop 0 "Не удалось запустить сервис."
        systemd_show_failure_logs
        return 1
    fi

    sleep 2

    if systemctl is-active --quiet "$SERVICE_NAME"; then
        ui_spinner_stop 1 "Сервис запущен"
        return 0
    fi

    ui_spinner_stop 0 "Сервис не перешёл в состояние active."
    systemd_show_failure_logs
    return 1
}

systemd_is_active() {
    config_load
    systemctl is-active --quiet "$SERVICE_NAME"
}

systemd_restart_service() {
    config_load
    if systemctl restart "$SERVICE_NAME"; then
        sleep 2
        systemctl is-active --quiet "$SERVICE_NAME"
        return $?
    fi
    return 1
}

systemd_show_failure_logs() {
    config_load
    echo
    ui_warn "Последние 30 строк journalctl:"
    journalctl -u "$SERVICE_NAME" -n 30 --no-pager 2>/dev/null || true
    echo
}

systemd_stop_disable() {
    config_load
    systemctl stop "$SERVICE_NAME" 2>/dev/null || true
    systemctl disable "$SERVICE_NAME" 2>/dev/null || true
}

systemd_remove_unit() {
    config_load
    local unit_file
    unit_file="$(systemd_unit_file)"

    systemd_stop_disable

    if [[ -f "$unit_file" ]]; then
        rm -f "$unit_file"
    fi

    systemctl daemon-reload
    systemctl reset-failed "$SERVICE_NAME" 2>/dev/null || true
}

systemd_show_status() {
    config_load
    local state active enabled

    if systemctl list-unit-files "$SERVICE_NAME.service" >/dev/null 2>&1; then
        state="$(systemctl is-active "$SERVICE_NAME" 2>/dev/null || echo unknown)"
        enabled="$(systemctl is-enabled "$SERVICE_NAME" 2>/dev/null || echo unknown)"
    else
        state="not-found"
        enabled="not-found"
    fi

    echo "  Сервис:           $SERVICE_NAME"
    echo "  Состояние:        $state"
    echo "  Автозапуск:       $enabled"
    echo "  Внешний сервер:   $(config_remote_target)"
    echo "  SOCKS5:           $(config_socks_url)"
    echo "  SSH-ключ:         $KEY_PATH"

    if [[ "$state" != "active" ]]; then
        echo
        ui_warn "Сервис не активен. Последние ошибки:"
        journalctl -u "$SERVICE_NAME" -n 10 --no-pager 2>/dev/null | tail -n 10 || true
    fi
}
