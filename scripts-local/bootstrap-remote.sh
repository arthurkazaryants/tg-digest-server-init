#!/bin/bash

set -Eeuo pipefail

# Локальный bootstrap - запускается на клиентской машине

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Цвета для вывода (локально)
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() {
    echo -e "${BLUE}[INFO]${NC} $@"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $@"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $@"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $@"
}

# Проверка требуемых команд
check_local_tools() {
    log_info "Проверка локальных инструментов..."
    
    local tools=("ssh" "scp" "git")
    for tool in "${tools[@]}"; do
        if ! command -v "$tool" &> /dev/null; then
            log_error "Требуемая команда не найдена: $tool"
            exit 1
        fi
    done
    
    # Проверить sshpass для поддержки пароля
    if ! command -v sshpass &> /dev/null; then
        log_warn "sshpass не найден. Установка требуется для поддержки пароля..."
        if command -v brew &> /dev/null; then
            brew install sshpass
        elif command -v apt-get &> /dev/null; then
            sudo apt-get install -y sshpass
        else
            log_error "Не удалось установить sshpass. Установите вручную."
            exit 1
        fi
    fi
    
    log_success "Все инструменты присутствуют"
}

# Загрузить конфиг
load_config() {
    local env_file="${1:-.env}"
    
    if [[ ! -f "$env_file" ]]; then
        log_error ".env файл не найден: $env_file"
        exit 1
    fi
    
    set -a
    source "$env_file"
    set +a
    
    log_info "Конфиг загружен: $env_file"
}

# Запросить пароль SSH (интерактивно)
prompt_ssh_password() {
    # Если пароль уже установлен, пропустить
    if [[ -n "${SSH_PASSWORD:-}" ]]; then
        log_success "Пароль SSH уже установлен"
        return 0
    fi
    
    log_warn "=========================================="
    log_warn "Требуется пароль для SSH подключения"
    log_warn "=========================================="
    read -sp "Введи пароль SSH: " SSH_PASSWORD
    echo ""
    
    # Проверить что пароль не пустой
    if [[ -z "$SSH_PASSWORD" ]]; then
        log_error "Пароль не может быть пустым"
        exit 1
    fi
    
    export SSH_PASSWORD
    log_success "Пароль принят"
}

# Проверка требуемых переменных
require_var() {
    local var_name=$1
    local var_value=${!var_name:-}
    
    if [[ -z "$var_value" ]]; then
        log_error "Требуемая переменная не установлена: $var_name"
        exit 1
    fi
}

# Проверка подключения SSH
test_ssh_connection() {
    local host=$1
    local port=$2
    local user=$3
    
    log_info "Проверка SSH подключения к ${user}@${host}:${port}..."
    
    local output
    local exit_code=0
    
    output=$(timeout 10 sshpass -p "$SSH_PASSWORD" ssh -p "$port" -o ConnectTimeout=5 \
        -o StrictHostKeyChecking=accept-new -o UserKnownHostsFile=/dev/null \
        "$user@$host" "echo 'SSH OK'" 2>&1) || exit_code=$?
    
    if [[ $exit_code -eq 0 ]]; then
        log_success "SSH подключение успешно"
        return 0
    else
        log_error "SSH подключение не удалось (код: $exit_code)"
        log_error "Проверь:"
        log_error "  - REMOTE_HOST: $host"
        log_error "  - REMOTE_ROOT_PORT: $port"
        log_error "  - REMOTE_ROOT_USER: $user"
        log_error "  - Пароль SSH правильный"
        
        # Дополнительная диагностика для кода 255 (общая ошибка SSH)
        if [[ $exit_code -eq 255 ]]; then
            log_error ""
            log_error "SSH ошибка 255 может означать:"
            log_error "  - Неправильный пароль"
            log_error "  - Сервер отказывает в доступе"
            log_error "  - Проблемы с подключением к хосту"
            log_error ""
            log_error "Попробуй подключиться вручную:"
            log_error "  ssh -p $port $user@$host"
        fi
        
        return 1
    fi
}

# Установить git на сервере если требуется
ensure_git_on_server() {
    local host=$1
    local port=$2
    local user=$3
    
    log_info "Проверка git на сервере..."
    
    if sshpass -p "$SSH_PASSWORD" ssh -p "$port" -o StrictHostKeyChecking=accept-new \
        -o UserKnownHostsFile=/dev/null "$user@$host" "command -v git" > /dev/null 2>&1; then
        log_success "git уже установлен на сервере"
        return 0
    fi
    
    log_warn "git не найден, устанавливаю..."
    sshpass -p "$SSH_PASSWORD" ssh -p "$port" -o StrictHostKeyChecking=accept-new \
        -o UserKnownHostsFile=/dev/null "$user@$host" \
        "apt-get update -qq && apt-get install -y git" || {
        log_error "Не удалось установить git на сервере"
        return 1
    }
    
    log_success "git установлен"
}

# Клонировать или обновить репозиторий
deploy_repo() {
    local host=$1
    local port=$2
    local user=$3
    local deploy_dir=$4
    local source=$5
    
    log_info "Развертывание репозитория..."
    
    # Создать директорию если её нет
    log_info "Создание директории: $deploy_dir"
    sshpass -p "$SSH_PASSWORD" ssh -p "$port" -o StrictHostKeyChecking=accept-new \
        -o UserKnownHostsFile=/dev/null "$user@$host" "mkdir -p $deploy_dir" || {
        log_error "Не удалось создать директорию"
        return 1
    }
    
    # Проверить есть ли уже репозиторий
    if sshpass -p "$SSH_PASSWORD" ssh -p "$port" -o StrictHostKeyChecking=accept-new \
        -o UserKnownHostsFile=/dev/null "$user@$host" "[[ -d $deploy_dir/.git ]]" 2>/dev/null; then
        log_warn "Репозиторий уже существует в $deploy_dir"
        log_info "Обновление репозитория..."
        sshpass -p "$SSH_PASSWORD" ssh -p "$port" -o StrictHostKeyChecking=accept-new \
            -o UserKnownHostsFile=/dev/null "$user@$host" \
            "cd $deploy_dir && git pull origin main" || {
            log_error "Не удалось обновить репозиторий"
            return 1
        }
    else
        # Определить источник - URL или локальный путь
        if [[ "$source" =~ ^(https?|git|ssh):// ]]; then
            # Это git URL
            log_info "Клонирование из: $source"
            sshpass -p "$SSH_PASSWORD" ssh -p "$port" -o StrictHostKeyChecking=accept-new \
                -o UserKnownHostsFile=/dev/null "$user@$host" \
                "git clone $source $deploy_dir" || {
                log_error "Не удалось клонировать репозиторий"
                return 1
            }
        else
            # Это локальный путь
            if [[ ! -d "$source" ]]; then
                log_error "Локальный путь не найден: $source"
                return 1
            fi
            
            log_info "Копирование локального репозитория: $source"
            sshpass -p "$SSH_PASSWORD" rsync -e "ssh -p $port" -avz --exclude='.git' --exclude='.env' \
                "$source/" "$user@$host:$deploy_dir/" || {
                log_error "Не удалось скопировать репозиторий"
                return 1
            }
        fi
    fi
    
    log_success "Репозиторий развернут в $deploy_dir"
}

# Загрузить .env файл
upload_env() {
    local host=$1
    local port=$2
    local user=$3
    local deploy_dir=$4
    local env_source=$5
    
    if [[ ! -f "$env_source" ]]; then
        log_error ".env файл не найден: $env_source"
        return 1
    fi
    
    log_warn "=========================================="
    log_warn "ВАЖНО: Загрузка .env на сервер"
    log_warn "=========================================="
    log_warn "Секреты будут отправлены по SSH"
    log_warn "Убедись что соединение зашифровано!"
    log_warn ""
    
    log_info "Копирование .env на сервер..."
    sshpass -p "$SSH_PASSWORD" scp -P "$port" -o StrictHostKeyChecking=accept-new \
        -o UserKnownHostsFile=/dev/null "$env_source" "$user@$host:$deploy_dir/.env" || {
        log_error "Не удалось загрузить .env"
        return 1
    }
    
    # Установить правильные права доступа
    sshpass -p "$SSH_PASSWORD" ssh -p "$port" -o StrictHostKeyChecking=accept-new \
        -o UserKnownHostsFile=/dev/null "$user@$host" "chmod 600 $deploy_dir/.env" || {
        log_error "Не удалось установить права доступа на .env"
        return 1
    }
    
    log_success ".env загружен и защищен (600)"
}

# Основной flow
main() {
    log_info "=========================================="
    log_info "Tg Digest server init - Локальная часть"
    log_info "=========================================="
    
    # Различные режимы использования
    if [[ $# -lt 2 ]]; then
        log_error "Использование:"
        log_error "  $0 <.env файл> <git URL или локальный путь> [опции]"
        log_error ""
        log_error "Опции:"
        log_error "  --password <пароль>   Передать пароль SSH в аргументе (небезопасно, видно в ps)"
        log_error ""
        log_error "Примеры:"
        log_error "  $0 .env https://github.com/user/tg-digest-server-init.git"
        log_error "  $0 .env /path/to/local/repo"
        log_error "  SSH_PASSWORD='mypass' $0 .env https://github.com/user/tg-digest-server-init.git"
        log_error "  $0 .env https://github.com/user/tg-digest-server-init.git --password 'mypass'"
        exit 1
    fi
    
    local env_file="$1"
    local repo_source="$2"
    
    # Парсить оставшиеся параметры
    shift 2
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --password)
                if [[ -z "${2:-}" ]]; then
                    log_error "--password требует значение"
                    exit 1
                fi
                export SSH_PASSWORD="$2"
                log_warn "⚠️  Пароль SSH передан в параметре командной строки"
                log_warn "Это видно в истории и процессах - используй для тестирования только!"
                shift 2
                ;;
            *)
                log_error "Неизвестный параметр: $1"
                exit 1
                ;;
        esac
    done
    
    # Загрузить конфиг
    load_config "$env_file"
    
    # Проверить требуемые переменные
    require_var "REMOTE_HOST"
    require_var "REMOTE_ROOT_USER"
    require_var "REMOTE_ROOT_PORT"
    require_var "REMOTE_DEPLOY_DIR"
    
    # Проверить локальные инструменты
    check_local_tools
    
    # Запросить пароль SSH если не установлен
    prompt_ssh_password
    
    echo ""
    log_info "=========================================="
    log_info "Параметры развертывания:"
    log_info "=========================================="
    log_info "Host: $REMOTE_HOST"
    log_info "Port: $REMOTE_ROOT_PORT"
    log_info "User: $REMOTE_ROOT_USER"
    log_info "Deploy Dir: $REMOTE_DEPLOY_DIR"
    log_info "Repo Source: $repo_source"
    log_info "=========================================="
    echo ""
    
    # Проверить SSH подключение
    if ! test_ssh_connection "$REMOTE_HOST" "$REMOTE_ROOT_PORT" "$REMOTE_ROOT_USER"; then
        log_error "Не удалось подключиться к серверу"
        exit 1
    fi
    
    # Убедиться что git установлен
    if ! ensure_git_on_server "$REMOTE_HOST" "$REMOTE_ROOT_PORT" "$REMOTE_ROOT_USER"; then
        log_error "Не удалось обеспечить git на сервере"
        exit 1
    fi
    
    # Развернуть репозиторий
    if ! deploy_repo "$REMOTE_HOST" "$REMOTE_ROOT_PORT" "$REMOTE_ROOT_USER" \
        "$REMOTE_DEPLOY_DIR" "$repo_source"; then
        log_error "Не удалось развернуть репозиторий"
        exit 1
    fi
    
    # Загрузить .env
    if ! upload_env "$REMOTE_HOST" "$REMOTE_ROOT_PORT" "$REMOTE_ROOT_USER" \
        "$REMOTE_DEPLOY_DIR" "$env_file"; then
        log_error "Не удалось загрузить .env"
        exit 1
    fi
    
    echo ""
    log_success "=========================================="
    log_success "Локальная часть завершена успешно!"
    log_success "=========================================="
    log_info ""
    log_info "СЛЕДУЮЩИЕ ШАГИ НА СЕРВЕРЕ:"
    log_info "1. Подключись к серверу:"
    log_info "   ssh -p $REMOTE_ROOT_PORT ${REMOTE_ROOT_USER}@${REMOTE_HOST}"
    log_info ""
    log_info "2. Запусти главный bootstrap (ОТ ROOT):"
    log_info "   cd $REMOTE_DEPLOY_DIR"
    log_info "   sudo bash bootstrap.sh"
    log_info ""
    log_info "3. Когда скрипт попросит - проверь новый SSH порт"
    log_info "   в ДРУГОЙ сессии:"
    log_info "   ssh -p ${SSH_PORT} ${NEW_USER}@${REMOTE_HOST}"
    log_info ""
    log_info "4. После успешной проверки вернись и закончи скрипт"
    log_info "=========================================="
}

main "$@"
