#!/bin/bash

set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Загрузить общие функции
source "${SCRIPT_DIR}/lib/common.sh"

# Убедиться что запущено от root
require_root

# Загрузить переменные окружения
load_env "${SCRIPT_DIR}/.env"

# Инициализировать логирование
init_logging

# Требуемые переменные
require_var "SERVER_HOSTNAME"
require_var "NEW_USER"
require_var "SSH_PORT"
require_var "SSH_PUBLIC_KEY"

log_info "=========================================="
log_info "Запуск Tg Digest server init"
log_info "=========================================="
log_info "Сервер: $SERVER_HOSTNAME"
log_info "Новый пользователь: $NEW_USER"
log_info "SSH порт: $SSH_PORT"
log_info "=========================================="

# Запуск скриптов по порядку
run_script() {
    local script=$1
    local script_path="${SCRIPT_DIR}/scripts/${script}"
    
    if [[ ! -f "$script_path" ]]; then
        log_error "Скрипт не найден: $script_path"
        exit 1
    fi
    
    log_info "Запускаю: $script"
    bash "$script_path"
    log_success "Завершен: $script"
    echo ""
}

# Основной порядок выполнения
run_script "01-base.sh"
run_script "02-user.sh"
run_script "03-firewall.sh"
run_script "04-ssh-hardening.sh"
run_script "05-fail2ban.sh"

# Docker опциональный
if [[ "${ENABLE_DOCKER:-false}" == "true" ]]; then
    run_script "06-docker-optional.sh"
fi

# Финальная проверка
run_script "90-verify.sh"

log_success "=========================================="
log_success "Bootstrap завершен успешно!"
log_success "=========================================="
log_info "Проверьте логи в: $LOG_DIR/bootstrap.log"
