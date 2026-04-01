#!/bin/bash

set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"

require_root
load_env "${SCRIPT_DIR}/.env"

log_info "========== Проверка конфигурации =========="

echo ""
log_info "--- Базовая информация ---"
echo "Hostname: $(hostnamectl --static)"
echo "Timezone: $(timedatectl | grep 'Time zone' | awk '{print $3}')"
echo "OS: $(lsb_release -d | cut -f2)"
echo "Kernel: $(uname -r)"

echo ""
log_info "--- Пользователь ---"
if id "${NEW_USER}" > /dev/null 2>&1; then
    log_success "✓ Пользователь существует: ${NEW_USER}"
else
    log_error "✗ Пользователь не найден: ${NEW_USER}"
fi

echo ""
log_info "--- SSH сервис ---"
if systemctl is-active --quiet ssh; then
    log_success "✓ SSH сервис запущен"
else
    log_error "✗ SSH сервис остановлен"
fi

if sshd -t 2>/dev/null; then
    log_success "✓ sshd конфиг валиден"
else
    log_error "✗ sshd конфиг невалиден"
fi

echo ""
log_info "--- Слушающие порты ---"
echo "Socket сокеты слушают:"
ss -tlnp 2>/dev/null | grep -E "State|ssh|LISTEN" || echo "  Нет данных"

echo ""
log_info "--- Firewall (UFW) ---"
if ufw status | grep -q "Status: active"; then
    log_success "✓ UFW включен"
    log_info "Статус:"
    ufw status numbered
else
    log_warn "⚠ UFW выключен"
fi

echo ""
log_info "--- Fail2Ban ---"
if systemctl is-active --quiet fail2ban; then
    log_success "✓ Fail2Ban запущен"
    if command -v fail2ban-client &> /dev/null; then
        echo "Общий статус:"
        fail2ban-client status 2>/dev/null || echo "  Ошибка получения статуса"
        echo ""
        echo "SSH jail:"
        fail2ban-client status sshd 2>/dev/null || echo "  sshd jail не активен"
    fi
else
    log_warn "⚠ Fail2Ban отключен"
fi

echo ""
log_info "--- Автоматические обновления ---"
if systemctl is-active --quiet unattended-upgrades; then
    log_success "✓ unattended-upgrades запущены"
else
    log_warn "⚠ unattended-upgrades остановлены"
fi

echo ""
log_info "--- Docker ---"
if command -v docker &> /dev/null; then
    log_success "✓ Docker установлен"
    docker --version
    if systemctl is-active --quiet docker; then
        log_success "✓ Docker daemon запущен"
    else
        log_warn "⚠ Docker daemon остановлен"
    fi
else
    log_info "ℹ Docker не установлен (опционально)"
fi

echo ""
log_info "--- systemd-journald ---"
if [[ -f /etc/systemd/journald.conf.d/99-pet-limits.conf ]]; then
    log_success "✓ journald лимиты настроены"
    cat /etc/systemd/journald.conf.d/99-pet-limits.conf
else
    log_warn "⚠ journald лимиты не настроены"
fi

echo ""
log_success "========== Проверка завершена =========="
log_warn "СЛЕДУЮЩИЕ ШАГИ:"
log_warn "1. Проверьте отсутствие ошибок выше"
log_warn "2. Аккуратно подключитесь на новый SSH порт:"
log_warn "   ssh -p ${SSH_PORT} ${NEW_USER}@<сервер>"
log_warn "3. Не закрывайте текущую SSH сессию пока не проверите новое подключение"
