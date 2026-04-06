#!/bin/bash

set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"

require_root
load_env "${SCRIPT_DIR}/.env"

log_info "========== Базовая настройка системы =========="

# Обновить систему
log_info "Обновление пакетов..."
apt-get update -qq
apt-get upgrade -y -qq
log_success "Пакеты обновлены"

# Установить необходимые утилиты
log_info "Установка базовых утилит..."
apt-get install -y -qq \
    curl \
    wget \
    git \
    vim \
    htop \
    net-tools \
    ufw \
    fail2ban \
    jq \
    unattended-upgrades \
    apt-listchanges \
    ca-certificates

log_success "Базовые утилиты установлены"

# Установить hostname
if [[ ! -z "${SERVER_HOSTNAME:-}" ]]; then
    log_info "Установка hostname на: $SERVER_HOSTNAME"
    hostnamectl set-hostname "$SERVER_HOSTNAME"
    log_success "Hostname установлен"
fi

# Установить timezone
if [[ ! -z "${TIMEZONE:-}" ]]; then
    log_info "Установка timezone на: $TIMEZONE"
    timedatectl set-timezone "$TIMEZONE"
    log_success "Timezone установлен"
fi

# Включить unattended-upgrades
if [[ "${ENABLE_UNATTENDED_UPGRADES:-true}" == "true" ]]; then
    log_info "Включаю автоматические обновления..."
    dpkg-reconfigure -plow unattended-upgrades
    systemctl enable unattended-upgrades
    systemctl restart unattended-upgrades
    log_success "Автоматические обновления включены"
fi

# Настроить journald логи
if [[ -d /etc/systemd/journald.conf.d ]]; then
    log_info "Настройка systemd journald..."
    
    mkdir -p /etc/systemd/journald.conf.d
    
    cat > /etc/systemd/journald.conf.d/99-pet-limits.conf << 'EOF'
[Journal]
SystemMaxUse=1G
RuntimeMaxUse=256M
MaxRetentionSec=14d
EOF
    
    systemctl restart systemd-journald
    log_success "journald логи настроены"
fi

# Настроить swap (опционально)
if [[ "${ENABLE_SWAP:-false}" == "true" ]]; then
    swap_size="${SWAP_SIZE_GB:-2}"
    
    if ! swapon --show | grep -q /swapfile; then
        log_info "Создание swap файла (${swap_size}G)..."
        
        fallocate -l "${swap_size}G" /swapfile
        chmod 600 /swapfile
        mkswap /swapfile
        swapon /swapfile
        
        append_if_missing "/swapfile none swap sw 0 0" /etc/fstab
        log_success "Swap файл создан"
    else
        log_warn "Swap файл уже существует"
    fi
fi

log_success "========== Базовая настройка завершена =========="
