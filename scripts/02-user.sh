#!/bin/bash

set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"

require_root
load_env "${SCRIPT_DIR}/.env"

log_info "========== Настройка пользователя =========="

require_var "NEW_USER"
require_var "SSH_PUBLIC_KEY"

local_user="${NEW_USER}"
local_shell="${NEW_USER_SHELL:-/bin/bash}"

# Создать пользователя
if ! user_exists "$local_user"; then
    log_info "Создание пользователя: $local_user"
    create_user "$local_user" "$local_shell"
else
    log_warn "Пользователь уже существует: $local_user"
fi

# Настроить SSH ключ
log_info "Настройка SSH ключа для: $local_user"
setup_ssh_key "$local_user" "$SSH_PUBLIC_KEY"

# Убедиться что у пользователя есть sudo без пароля
log_info "Настройка sudo для: $local_user"
if [[ ! -f /etc/sudoers.d/"$local_user" ]]; then
    echo "$local_user ALL=(ALL) NOPASSWD:ALL" | tee /etc/sudoers.d/"$local_user"
    chmod 0440 /etc/sudoers.d/"$local_user"
    log_success "sudo доступ настроен"
else
    log_warn "sudo конфиг уже существует для: $local_user"
fi

log_success "========== Пользователь настроен =========="
