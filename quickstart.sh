#!/bin/bash
# Быстрый старт Pet Server Bootstrap

set -e

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "=========================================="
echo "Tg Digest server init - Быстрый старт"
echo "=========================================="
echo ""

# Сделать скрипты исполняемыми
echo "[1/3] Установка прав исполнения на скрипты..."
chmod +x "$REPO_DIR/bootstrap.sh" \
         "$REPO_DIR/scripts"/*.sh \
         "$REPO_DIR/scripts-local"/*.sh \
         "$REPO_DIR/lib"/*.sh

# Проверить .env
echo "[2/3] Проверка конфигурации..."
if [[ ! -f "$REPO_DIR/.env" ]]; then
    echo "⚠ .env файл не найден!"
    echo "Создаю из примера: env.example"
    cp "$REPO_DIR/env.example" "$REPO_DIR/.env"
    echo "✓ Создан .env (отредактируй его перед запуском!)"
else
    echo "✓ .env файл существует"
fi

# Инструкции
echo ""
echo "[3/3] Инструкции для запуска:"
echo ""
echo "1. Отредактируй .env файл с твоими параметрами:"
echo "   nano $REPO_DIR/.env"
echo ""
echo "2. Запусти локальный bootstrap:"
echo "   cd $REPO_DIR"
echo "   ./scripts-local/bootstrap-remote.sh .env <git-url или путь>"
echo ""
echo "3. На сервере запусти:"
echo "   cd /opt/server-bootstrap"
echo "   sudo bash bootstrap.sh"
echo ""
echo "=========================================="
echo "Подробнее см. README.md"
echo "=========================================="
