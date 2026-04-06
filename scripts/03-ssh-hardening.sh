#!/bin/bash

set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"

require_root
load_env "${SCRIPT_DIR}/.env"

log_info "========== SSH Hardening =========="
log_info "ВАЖНО: Этот этап выполняется ДО firewall для безопасного переведения портов"

require_var "SSH_PORT"
require_var "ALLOW_USERS"

# Убедиться что конфиг директория существует
mkdir -p /etc/ssh/sshd_config.d

# Копировать drop-in конфиг
log_info "Применение SSH drop-in конфига..."

backup_file "/etc/ssh/sshd_config.d/99-pet-hardening.conf" || true

cat > /etc/ssh/sshd_config.d/99-pet-hardening.conf << EOF
# Tg Digest Server SSH Hardening
# Автоматически управляемый файл - не редактируй вручную

Port $SSH_PORT
PermitRootLogin no
PasswordAuthentication no
KbdInteractiveAuthentication no
ChallengeResponseAuthentication no
PubkeyAuthentication yes
UsePAM yes
X11Forwarding no
AllowUsers $ALLOW_USERS
LoginGraceTime 30
MaxAuthTries 3
ClientAliveInterval 300
ClientAliveCountMax 2
Compression delayed
TCPKeepAlive yes
MaxSessions 10
EOF

log_success "Drop-in конфиг создан"

# Проверить синтаксис
log_info "Проверка синтаксиса sshd конфига..."
if ! sshd -t; then
    log_error "sshd конфиг имеет синтаксические ошибки"
    log_error "Запустите: sudo sshd -t"
    exit 1
fi

log_success "sshd конфиг валиден"

# Проверить флаг для применения изменений
if [[ "${APPLY_SSH_CHANGES:-false}" != "true" ]]; then
    log_warn "=========================================="
    log_warn "ВНИМАНИЕ: SSH изменения не применены!"
    log_warn "=========================================="
    log_warn ""
    log_warn "Порядок действий (КРИТИЧНЫЙ для безопасности):"
    log_warn ""
    log_warn "1. Откройте НОВУЮ SSH сессию на порт $SSH_PORT"
    log_warn "   ssh -p $SSH_PORT $ALLOW_USERS@<сервер>"
    log_warn ""
    log_warn "2. Только после УСПЕШНОГО входа установите флаг:"
    log_warn "   APPLY_SSH_CHANGES=true"
    log_warn ""
    log_warn "3. Запустите bootstrap еще раз - firewall будет применен"
    log_warn "   на следующем этапе автоматически"
    log_warn ""
    log_warn "⚠️  Если не применишь флаг и отключишь сессию,"
    log_warn "    потеряешь доступ!"
    log_warn "=========================================="
    exit 0
fi

# Применить изменения
log_info "Перезагружаю SSH сервис..."
systemctl reload ssh

log_success "SSH сервис перезагружен на порту $SSH_PORT"
log_warn "=========================================="
log_warn "ВАЖНО: Подключайтесь ТОЛЬКО на порт $SSH_PORT!"
log_warn "=========================================="

log_success "========== SSH Hardening завершен =========="
