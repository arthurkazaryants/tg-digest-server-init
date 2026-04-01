#!/bin/bash

set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"

require_root
load_env "${SCRIPT_DIR}/.env"

log_info "========== Установка Docker (опционально) =========="

if [[ "${ENABLE_DOCKER:-false}" != "true" ]]; then
    log_warn "Docker отключен через ENABLE_DOCKER=false"
    exit 0
fi

# Проверить что Docker еще не установлен
if command -v docker &> /dev/null; then
    log_warn "Docker уже установлен"
    exit 0
fi

log_info "Установка Docker Engine для Ubuntu 24.04..."

# Удалить старые версии
apt-get remove -y docker docker.io containerd runc 2>/dev/null || true

# Установить зависимости
apt-get install -y -qq \
    ca-certificates \
    curl \
    gnupg \
    lsb-release

# Добавить Docker GPG ключ
mkdir -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | \
    gpg --dearmor -o /etc/apt/keyrings/docker.gpg

# Добавить Docker репозиторий
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | \
  tee /etc/apt/sources.list.d/docker.list > /dev/null

# Обновить индекс пакетов
apt-get update -qq

# Установить Docker Engine, CLI и Compose Plugin
log_info "Установка Docker компонентов..."
apt-get install -y -qq \
    docker-ce \
    docker-ce-cli \
    containerd.io \
    docker-compose-plugin \
    docker-buildx-plugin \
    docker-scan-plugin

log_success "Docker установлен"

# Включить сервис
systemctl enable docker
systemctl start docker

# Проверить установку
log_info "Проверка Docker..."
docker --version
docker compose version
log_success "Docker готов к использованию"

# ВАЖНОЕ ПРЕДУПРЕЖДЕНИЕ
log_warn "=========================================="
log_warn "ВАЖНО: БЕЗОПАСНОСТЬ DOCKER"
log_warn "=========================================="
log_warn ""
log_warn "1. docker group эквивалентна ROOT доступу"
log_warn "   НЕ добавляй пользователей в group без"
log_warn "   понимания рисков!"
log_warn ""
log_warn "2. Контейнеры с публичными портами могут"
log_warn "   нарушить firewall модель сервера"
log_warn ""
log_warn "3. Используй internal/host networking для"
log_warn "   приватных сервисов (по умолчанию)"
log_warn ""
log_warn "4. Если нужны публичные порты - явно"
log_warn "   разреши в UFW и docker-compose"
log_warn ""
log_warn "5. НЕ отключай docker iptables без причины"
log_warn "=========================================="

# Пример compose структуры
log_info "Создание примера docker-compose..."
mkdir -p "${SCRIPT_DIR}/../compose/app-example"

log_success "========== Docker установлен =========="
