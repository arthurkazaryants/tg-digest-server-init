#!/bin/bash

set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"

require_root
load_env "${SCRIPT_DIR}/.env"

log_info "========== Настройка UFW firewall =========="

require_var "SSH_PORT"

if [[ "${ENABLE_UFW:-true}" != "true" ]]; then
    log_warn "UFW отключен через ENABLE_UFW=false"
    exit 0
fi

# Убедиться что UFW установлен
if ! command -v ufw &> /dev/null; then
    log_error "UFW не установлен"
    exit 1
fi

log_info "Применение базовых правил UFW..."

# Базовая политика
ufw --force enable > /dev/null 2>&1 || true
ufw default deny incoming
ufw default allow outgoing
ufw default deny routed

log_success "Базовые правила применены"

# Добавить SSH порт
log_info "Разрешаю SSH на порту: $SSH_PORT"

# Проверить есть ли уже такое правило
if ! ufw status | grep -q "$SSH_PORT/tcp"; then
    ufw allow "$SSH_PORT/tcp"
    log_success "SSH вход разрешен на порту $SSH_PORT"
else
    log_warn "Правило UFW уже существует для $SSH_PORT"
fi

# Вывести статус
log_info "Текущий статус UFW:"
ufw status verbose

# Предупреждение о финализации
if [[ "${FINALIZE_FIREWALL:-false}" != "true" ]]; then
    log_warn "=========================================="
    log_warn "ВНИМАНИЕ: Firewall не финализирован!"
    log_warn "=========================================="
    log_warn "Чтобы завершить, установите:"
    log_warn "FINALIZE_FIREWALL=true"
    log_warn "=========================================="
fi

log_success "========== UFW firewall настроен =========="
