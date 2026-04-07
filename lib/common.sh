#!/bin/bash

set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LOG_DIR="/var/log/tg-digest-server-init"

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Инициализация логирования
init_logging() {
    mkdir -p "$LOG_DIR"
    touch "$LOG_DIR/bootstrap.log"
}

# Логирование
log() {
    local level=$1
    shift
    local message="$@"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo -e "${timestamp} [${level}] ${message}" | tee -a "$LOG_DIR/bootstrap.log"
}

log_info() {
    log "${BLUE}INFO${NC}" "$@"
}

log_success() {
    log "${GREEN}SUCCESS${NC}" "$@"
}

log_warn() {
    log "${YELLOW}WARN${NC}" "$@"
}

log_error() {
    log "${RED}ERROR${NC}" "$@"
}

# Загрузка .env файла
load_env() {
    local env_file="${1:-.env}"
    if [[ ! -f "$env_file" ]]; then
        log_error ".env файл не найден: $env_file"
        exit 1
    fi
    set -a
    source "$env_file"
    set +a
    log_info ".env файл загружен: $env_file"
}

# Проверка требуемых переменных
require_var() {
    local var_name=$1
    local var_value=${!var_name:-}
    if [[ -z "$var_value" ]]; then
        log_error "Обязательная переменная не установлена: $var_name"
        exit 1
    fi
}

# Проверка требуемого инструмента
require_command() {
    local cmd=$1
    if ! command -v "$cmd" &> /dev/null; then
        log_error "Требуемая команда не найдена: $cmd"
        exit 1
    fi
}

# Backup файла перед изменением
backup_file() {
    local file=$1
    if [[ -f "$file" ]]; then
        local backup="${file}.$(date +%s).bak"
        cp -p "$file" "$backup"
        log_info "Backup создан: $backup"
        echo "$backup"
    fi
}

# Проверка, что скрипт запущен как root
require_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "Этот скрипт должен быть запущен от root"
        exit 1
    fi
}

# Проверка конфига sshd перед перезагрузкой
verify_sshd_config() {
    if ! sshd -t &> /dev/null; then
        log_error "sshd конфиг невалидный. Запустите: sudo sshd -t"
        return 1
    fi
    log_success "sshd конфиг валидный"
    return 0
}

# Безопасный перезащиту sshd с проверкой
reload_sshd_safe() {
    if ! verify_sshd_config; then
        log_error "Не могу перезагрузить sshd - конфиг невалидный"
        return 1
    fi
    log_info "Перезагружаю sshd..."
    systemctl reload ssh
    log_success "sshd перезагружен"
    return 0
}

# Добавление строки в файл, если её там нет
append_if_missing() {
    local line=$1
    local file=$2
    
    if ! grep -Fxq "$line" "$file"; then
        echo "$line" >> "$file"
        log_info "Добавлено в $file: $line"
        return 0
    fi
    return 1
}

# Проверка, есть ли пользователь
user_exists() {
    local user=$1
    id "$user" &> /dev/null
}

# Генерация безопасного пароля
generate_password() {
    # Генерировать 16 символов с буквами, цифрами и спецсимволами
    openssl rand -base64 12 | tr -d "=+/" | cut -c1-16
}

# Создание пользователя с паролем
create_user() {
    local user=$1
    local shell=${2:-/bin/bash}
    local password=$(generate_password)
    
    if user_exists "$user"; then
        log_warn "Пользователь уже существует: $user"
        return 0
    fi
    
    # Создать пользователя
    useradd -m -s "$shell" -G sudo "$user"
    log_success "Пользователь создан: $user"
    
    # Установить пароль
    echo "$user:$password" | chpasswd
    log_info "Пароль установлен для: $user"
    
    # Требовать пароль для sudo (более безопасно)
    append_if_missing "$user ALL=(ALL) ALL" /etc/sudoers.d/"$user"
    chmod 0440 /etc/sudoers.d/"$user"
    
    # Сохранить пароль в переменную для вывода
    echo "$password"
}

# Настройка SSH authorized_keys
setup_ssh_key() {
    local user=$1
    local ssh_public_key=$2
    local home_dir=$(getent passwd "$user" | cut -d: -f6)
    local ssh_dir="$home_dir/.ssh"
    local auth_keys="$ssh_dir/authorized_keys"
    
    mkdir -p "$ssh_dir"
    chmod 700 "$ssh_dir"
    
    # Добавить ключ, если его там нет
    if ! grep -Fq "$ssh_public_key" "$auth_keys" 2>/dev/null; then
        echo "$ssh_public_key" >> "$auth_keys"
        log_info "SSH ключ добавлен для пользователя: $user"
    else
        log_warn "SSH ключ уже есть для пользователя: $user"
    fi
    
    chmod 600 "$auth_keys"
    chown "$user:$user" "$ssh_dir" "$auth_keys"
}

# Проверка, разрешено ли то или иное действие флагом
require_flag() {
    local flag_name=$1
    local flag_value=${!flag_name:-}
    
    if [[ "$flag_value" != "true" ]]; then
        return 1
    fi
    return 0
}

# Основной обработчик ошибок
error_exit() {
    local line_no=$1
    log_error "Ошибка на строке $line_no"
    exit 1
}

# Установка trap для ошибок
trap 'error_exit ${LINENO}' ERR

export -f log log_info log_success log_warn log_error
export -f require_var require_command require_root require_flag
export -f load_env init_logging backup_file
export -f verify_sshd_config reload_sshd_safe append_if_missing
export -f user_exists create_user setup_ssh_key generate_password
