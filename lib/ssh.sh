#!/usr/bin/env bash
# SSH key management and remote setup

ssh_prepare_dir() {
    local ssh_dir
    ssh_dir="$(dirname "$KEY_PATH")"

    mkdir -p "$ssh_dir"
    chmod 700 "$ssh_dir"
    ui_step_ok "SSH-директория готова: $ssh_dir"
}

ssh_key_exists() {
    [[ -f "$KEY_PATH" && -f "${KEY_PATH}.pub" ]]
}

ssh_handle_existing_key() {
    if ! ssh_key_exists; then
        return 0
    fi

    ui_warn "Найден существующий ключ: $KEY_PATH"
    echo
    echo "  Что сделать?"
    echo "    1) Использовать его"
    echo "    2) Создать новый с другим именем"
    echo "    3) Перезаписать существующий"
    echo

    local choice
    choice="$(ui_prompt "Выбор" "1")"

    case "$choice" in
        1)
            ui_step_ok "Использую существующий ключ"
            return 0
            ;;
        2)
            local suffix
            suffix="$(date +%Y%m%d%H%M%S)"
            KEY_PATH="/root/.ssh/socksctl_key_${suffix}"
            ui_info "Новый путь ключа: $KEY_PATH"
            return 0
            ;;
        3)
            if ! ui_confirm "Перезаписать существующий ключ?" "n"; then
                ui_die "Установка отменена." 1
            fi
            rm -f "$KEY_PATH" "${KEY_PATH}.pub"
            return 0
            ;;
        *)
            ui_die "Неверный выбор." 1
            ;;
    esac
}

ssh_generate_key() {
    if ssh_key_exists; then
        chmod 600 "$KEY_PATH"
        chmod 644 "${KEY_PATH}.pub"
        ui_step_ok "SSH-ключ готов: $KEY_PATH"
        return 0
    fi

    ui_spinner_start "Генерирую SSH-ключ ed25519"

    if ! ssh-keygen -t ed25519 -f "$KEY_PATH" -N "" -q; then
        ui_spinner_stop 0 "Не удалось создать SSH-ключ."
        return 1
    fi

    chmod 600 "$KEY_PATH"
    chmod 644 "${KEY_PATH}.pub"

    ui_spinner_stop 1 "SSH-ключ создан: $KEY_PATH"
    return 0
}

ssh_add_known_host() {
    local scan_file scan_line

    ui_spinner_start "Добавляю хост в known_hosts"

    scan_file="$(mktemp)"
    if ! ssh-keyscan -p "$SSH_PORT" -H "$SSH_HOST" >"$scan_file" 2>/dev/null; then
        rm -f "$scan_file"
        ui_spinner_stop 0 "ssh-keyscan не смог получить ключ хоста."
        return 1
    fi

    if [[ ! -s "$scan_file" ]]; then
        rm -f "$scan_file"
        ui_spinner_stop 0 "ssh-keyscan вернул пустой результат."
        return 1
    fi

    touch /root/.ssh/known_hosts
    chmod 600 /root/.ssh/known_hosts

    while IFS= read -r scan_line; do
        [[ -z "$scan_line" ]] && continue
        if ! grep -qxF "$scan_line" /root/.ssh/known_hosts 2>/dev/null; then
            echo "$scan_line" >> /root/.ssh/known_hosts
        fi
    done < "$scan_file"

    rm -f "$scan_file"
    ui_spinner_stop 1 "known_hosts обновлён"
    return 0
}

ssh_copy_id_to_remote() {
    ui_info "Сейчас потребуется пароль от ${SSH_USER}@${SSH_HOST} (один раз, не сохраняется)."
    echo

    if ! ssh-copy-id -i "${KEY_PATH}.pub" -p "$SSH_PORT" -o StrictHostKeyChecking=accept-new "${SSH_USER}@${SSH_HOST}"; then
        ui_err "Не удалось добавить ключ на внешний сервер."
        echo
        ui_info "Что проверить:"
        ui_info "- правильный IP/домен сервера"
        ui_info "- SSH-порт ($SSH_PORT)"
        ui_info "- имя пользователя ($SSH_USER)"
        ui_info "- открыт ли SSH на внешнем сервере"
        ui_info "- разрешён ли вход по паролю"
        return 1
    fi

    ui_step_ok "Публичный ключ добавлен на внешний сервер"
    return 0
}

ssh_verify_connection() {
    local quiet="${1:-0}"

    if [[ "$quiet" != "1" ]]; then
        ui_spinner_start "Проверяю SSH-подключение по ключу"
    fi

    if ssh -i "$KEY_PATH" -p "$SSH_PORT" \
        -o BatchMode=yes \
        -o ConnectTimeout=15 \
        -o StrictHostKeyChecking=yes \
        "${SSH_USER}@${SSH_HOST}" true 2>/dev/null; then
        if [[ "$quiet" != "1" ]]; then
            ui_spinner_stop 1 "SSH-подключение по ключу работает"
        fi
        return 0
    fi

    if [[ "$quiet" == "1" ]]; then
        return 1
    fi

    ui_spinner_stop 0 "Не удалось подключиться по SSH-ключу."
    echo
    ui_err "Команда:"
    ui_info "ssh -i $KEY_PATH -p $SSH_PORT ${SSH_USER}@${SSH_HOST} true"
    echo
    ui_info "Что проверить:"
    ui_info "- IP или домен сервера"
    ui_info "- SSH-порт"
    ui_info "- имя пользователя"
    ui_info "- доступен ли сервер из сети"
    ui_info "- разрешена ли авторизация по ключам в sshd_config"
    return 1
}

ssh_test_remote_reachable() {
    config_load
    ui_spinner_start "Проверяю доступность внешнего SSH-сервера"

    if ssh -i "$KEY_PATH" -p "$SSH_PORT" \
        -o BatchMode=yes \
        -o ConnectTimeout=10 \
        -o StrictHostKeyChecking=yes \
        "${SSH_USER}@${SSH_HOST}" true 2>/dev/null; then
        ui_spinner_stop 1 "Внешний SSH-сервер доступен"
        return 0
    fi

    ui_spinner_stop 0 "Внешний SSH-сервер недоступен"
    return 1
}
