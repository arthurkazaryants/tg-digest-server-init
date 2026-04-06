#!/bin/bash

set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"

require_root
load_env "${SCRIPT_DIR}/.env"

log_info "========== Настройка Fail2Ban =========="

require_var "SSH_PORT"

if [[ "${ENABLE_FAIL2BAN:-true}" != "true" ]]; then
    log_warn "Fail2Ban отключен через ENABLE_FAIL2BAN=false"
    exit 0
fi

# Убедиться что fail2ban установлен
if ! command -v fail2ban-server &> /dev/null; then
    log_error "Fail2Ban не установлен"
    exit 1
fi

log_info "Применение Fail2Ban конфига..."

# Backup существующего конфига
backup_file "/etc/fail2ban/jail.local" || true

# Создать локальный конфиг с нашими параметрами
cat > /etc/fail2ban/jail.local << EOF
[DEFAULT]
bantime = 3600
findtime = 600
maxretry = 3
destemail = root@localhost
sendername = Fail2Ban

[sshd]
enabled = true
port = $SSH_PORT
filter = sshd
logpath = /var/log/auth.log
maxretry = 3
bantime = 3600
findtime = 600
EOF

log_success "Fail2Ban конфиг создан"

# Примечание: используем стандартный sshd фильтр из fail2ban
# Убедимся что конфиг валиден
log_info "Проверка синтаксиса Fail2Ban конфига..."
fail2ban-client -c /etc/fail2ban/ status > /dev/null 2>&1 || {
    log_warn "Ошибка конфига, пытаюсь запустить вручную..."
}

# Перезагрузить fail2ban
log_info "Перезагрузка Fail2Ban..."
systemctl enable fail2ban
systemctl restart fail2ban

# Подождать инициализации и наличия сокета
log_info "Ожидание инициализации Fail2Ban..."
max_attempts=30
attempt=0
while [[ $attempt -lt $max_attempts ]]; do
    if fail2ban-client ping &> /dev/null; then
        break
    fi
    attempt=$((attempt + 1))
    if [[ $attempt -lt $max_attempts ]]; then
        sleep 0.2
    fi
done

if [[ $attempt -eq $max_attempts ]]; then
    log_warn "Fail2Ban не ответил в срок, но сервис запущен"
else
    log_success "Fail2Ban готов к работе"
fi

log_success "Fail2Ban включен"

# Вывести статус (неблокирующее)
log_info "Статус Fail2Ban:"
fail2ban-client status || log_warn "Не удалось получить полный статус Fail2Ban (сервис инициализируется)"

log_info "Статус sshd jail:"
fail2ban-client status sshd || log_warn "sshd jail еще не инициализирован"

log_success "========== Fail2Ban настроен =========="
