#!/usr/bin/env bash
# Configuration read/write

SOCKSCTL_CONFIG_DIR="/etc/socksctl"
SOCKSCTL_CONFIG_FILE="${SOCKSCTL_CONFIG_DIR}/config.env"

config_defaults() {
    SSH_HOST="${SSH_HOST:-}"
    SSH_PORT="${SSH_PORT:-22}"
    SSH_USER="${SSH_USER:-root}"
    KEY_PATH="${KEY_PATH:-/root/.ssh/socksctl_key}"
    LISTEN_HOST="${LISTEN_HOST:-127.0.0.1}"
    LISTEN_PORT="${LISTEN_PORT:-1080}"
    SERVICE_NAME="${SERVICE_NAME:-socksctl-tunnel}"
}

config_exists() {
    [[ -f "$SOCKSCTL_CONFIG_FILE" ]]
}

config_load() {
    config_defaults

    if [[ -f "$SOCKSCTL_CONFIG_FILE" ]]; then
        # shellcheck disable=SC1090
        source "$SOCKSCTL_CONFIG_FILE"
    fi
}

config_save() {
    config_defaults

    mkdir -p "$SOCKSCTL_CONFIG_DIR"
    chmod 700 "$SOCKSCTL_CONFIG_DIR"

    cat > "$SOCKSCTL_CONFIG_FILE" <<EOF
SSH_HOST=${SSH_HOST}
SSH_PORT=${SSH_PORT}
SSH_USER=${SSH_USER}
KEY_PATH=${KEY_PATH}
LISTEN_HOST=${LISTEN_HOST}
LISTEN_PORT=${LISTEN_PORT}
SERVICE_NAME=${SERVICE_NAME}
EOF

    chmod 600 "$SOCKSCTL_CONFIG_FILE"
}

config_socks_url() {
    config_load
    printf 'socks5h://%s:%s' "$LISTEN_HOST" "$LISTEN_PORT"
}

config_remote_target() {
    config_load
    printf '%s@%s:%s' "$SSH_USER" "$SSH_HOST" "$SSH_PORT"
}
