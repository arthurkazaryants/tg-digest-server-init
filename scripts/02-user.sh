#!/bin/bash

set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"

require_root
load_env "${SCRIPT_DIR}/.env"

log_info "========== Настройка пользователя =========="

require_var "NEW_USER"
require_var "SSH_PUBLIC_KEY"
require_var "SSH_PORT"

local_user="${NEW_USER}"
local_shell="${NEW_USER_SHELL:-/bin/bash}"

# Создать пользователя с паролем и sudo доступом
log_info "Создание пользователя: $local_user"
local_password=$(create_user "$local_user" "$local_shell")

# Настроить SSH ключ
log_info "Настройка SSH ключа для: $local_user"
setup_ssh_key "$local_user" "$SSH_PUBLIC_KEY"

log_success "sudo доступ настроен (требуется пароль)"

echo ""
log_warn "=========================================="
log_warn "ВАЖНО: Сохрани начальный пароль!"
log_warn "=========================================="
log_info "Пользователь: $local_user"
log_info "Пароль: $local_password"
log_warn ""
log_warn "⚠️  Рекомендуется сменить пароль при первом логине:"
log_warn "  ssh -p $SSH_PORT ${local_user}@SERVER"
log_warn "  passwd"
log_warn "=========================================="
echo ""

log_success "========== Пользователь настроен =========="
