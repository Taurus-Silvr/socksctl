#!/usr/bin/env bash
# Package dependencies

DEPS_PACKAGES=(
    autossh
    openssh-client
    curl
    ca-certificates
    netcat-openbsd
)

deps_install() {
    ui_spinner_start "Устанавливаю зависимости"

    export DEBIAN_FRONTEND=noninteractive

    if ! apt-get update -qq >/dev/null 2>&1; then
        ui_spinner_stop 0 "Не удалось обновить список пакетов (apt update)."
        return 1
    fi

    if ! apt-get install -y -qq "${DEPS_PACKAGES[@]}" >/dev/null 2>&1; then
        ui_spinner_stop 0 "Не удалось установить зависимости."
        ui_info "Попробуйте вручную: apt install -y ${DEPS_PACKAGES[*]}"
        return 1
    fi

    ui_spinner_stop 1 "Зависимости установлены"
    return 0
}

deps_check() {
    local pkg missing=()
    for pkg in "${DEPS_PACKAGES[@]}"; do
        if ! dpkg -s "$pkg" >/dev/null 2>&1; then
            missing+=("$pkg")
        fi
    done

    if ((${#missing[@]} > 0)); then
        ui_err "Не установлены пакеты: ${missing[*]}"
        return 1
    fi

    ui_ok "Все зависимости установлены"
    return 0
}
