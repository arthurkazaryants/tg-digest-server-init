# Tg Digest server init

Полностью автоматизированная, безопасная настройка VPS под Ubuntu 24.04 LTS для Tg Digest проекта.

## Что делает этот репозиторий

- ✅ Создает клиента с sudo доступом
- ✅ Настраивает SSH только по ключам (без паролей)
- ✅ Перемещает SSH на нестандартный порт
- ✅ Отключает root login и парольную аутентификацию
- ✅ Настраивает UFW firewall (deny incoming, разрешить только SSH)
- ✅ Защищает от brute-force через Fail2Ban
- ✅ Включает автоматические обновления
- ✅ Ограничивает рост systemd-journald логов
- ✅ Опционально устанавливает Docker
- ✅ Настраивает безопасное логирование в Docker
- ✅ Включает все проверки и верификацию

## Что НЕ делает

- ❌ Не устанавливает reverse-proxy или web-сервер
- ❌ Не открывает HTTP/HTTPS
- ❌ Не публикует Docker-контейнеры наружу по умолчанию
- ❌ Не настраивает DNS или домены
- ❌ Не устанавливает базы данных (только Docker для них доступен)

## Структура репозитория

```
tg-digest-server-init/
├── README.md                           # Этот файл
├── .gitignore                          # Git ignore правила
├── env.example                         # Пример конфигурации
├── bootstrap.sh                        # Главный скрипт (запускается на сервере)
├── lib/
│   └── common.sh                       # Общие функции для всех скриптов
├── scripts/                            # Серверные скрипты (запускаются удалённо)
│   ├── 01-base.sh                     # Базовая настройка системы
│   ├── 02-user.sh                     # Создание пользователя и SSH
│   ├── 03-firewall.sh                 # Настройка UFW
│   ├── 04-ssh-hardening.sh            # SSH Hardening (КРИТИЧНО)
│   ├── 05-fail2ban.sh                 # Защита от brute-force
│   ├── 06-docker-optional.sh          # Установка Docker (опционально)
│   └── 90-verify.sh                   # Проверка конфигурации
├── scripts-local/
│   └── bootstrap-remote.sh             # Локальный скрипт для загрузки на сервер
├── configs/                            # Конфиги, используемые скриптами
│   ├── ssh/
│   │   └── 99-pet-hardening.conf      # SSH drop-in конфиг
│   ├── fail2ban/
│   │   └── jail.local                 # Fail2Ban конфиг
│   ├── systemd/
│   │   └── journald.conf.d/
│   │       └── 99-pet-limits.conf    # systemd-journald лимиты
│   └── docker/
│       └── README.md                  # Docker security notes
└── compose/
    └── app-example/
        └── compose.yml                # Пример docker-compose (safe)
```

## Режим работы: Две части bootstrap

### Часть 1: Локальная (на твоем компьютере)

- Проверяет ssh, git, scp
- Подключается к серверу по SSH
- Загружает репозиторий на сервер
- Загружает .env файл

**Файл:** `scripts-local/bootstrap-remote.sh`

### Часть 2: Удаленная (на сервере)

- Запускается как root
- Выполняет все 7 этапов настройки по порядку
- Требует явных флагов для опасных операций
- Выполняет проверки безопасности после каждого этапа

**Файл:** `bootstrap.sh` (главный оркестратор)

## Подготовка

### 1. На твоем компьютере

**Установи требуемое:**
```bash
# macOS
brew install git openssh

# Debian/Ubuntu
apt-get install git openssh-client openssh-server
```

**Генерируй SSH ключ (если нет):**
```bash
ssh-keygen -t ed25519 -C "your-email@example.com"
# Ключ будет в ~/.ssh/id_ed25519 (private) и ~/.ssh/id_ed25519.pub (public)
```

**Клонируй этот репозиторий:**
```bash
git clone https://github.com/your-name/tg-digest-server-init.git
cd tg-digest-server-init
```

### 2. Подготовка .env файла

**Скопируй пример:**
```bash
cp env.example .env
```

**Отредактируй .env (критичные параметры):**
```bash
# === СЕРВЕР ===
SERVER_HOSTNAME=my-awesome-server
TIMEZONE=Europe/Moscow

# === ПОЛЬЗОВАТЕЛЬ ===
NEW_USER=deploy
NEW_USER_SHELL=/bin/bash

# === SSH ===
SSH_PORT=2222
# 👇 ВАЖНО: Вставь СОДЕРЖИМОЕ твоего ~/.ssh/id_ed25519.pub (НЕ путь!)
SSH_PUBLIC_KEY="ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAID... your-email@example.com"

# === ДОСТУП ===
ALLOW_USERS=deploy

# === ПАРАМЕТРЫ BOOTSTRAP ===
REMOTE_ROOT_USER=root
REMOTE_ROOT_PORT=22           # Стандартный SSH порт, пока на нем сидим
REMOTE_HOST=192.168.1.100     # IP или домен сервера
REMOTE_DEPLOY_DIR=/opt/server-bootstrap

# === ФЛАГИ БЕЗОПАСНОСТИ (ПРОЧИТАЙ ПЕРЕД ВКЛЮЧЕНИЕМ!) ===
APPLY_SSH_CHANGES=false       # 🚨 Измени на true ТОЛЬКО после проверки нового порта!
FINALIZE_FIREWALL=false       # 🚨 Измени на true ТОЛЬКО после успешной проверки!

# === КОМПОНЕНТЫ ===
ENABLE_UFW=true
ENABLE_FAIL2BAN=true
ENABLE_DOCKER=true            # Опционально
ENABLE_UNATTENDED_UPGRADES=true
ENABLE_SWAP=true
SWAP_SIZE_GB=2

# === ЛОГИРОВАНИЕ ===
JOURNALD_MAX_SIZE=1G
JOURNALD_MAX_RETENTION=14d
```

### 3. Проверь SSH доступ

Убедись что можешь войти по SSH:
```bash
ssh -p 22 root@192.168.1.100
# Должен быть доступ (скорее всего по паролю или ключу, пока)
```

## Первый запуск: Локальный bootstrap

**Запусти скрипт:**
```bash
chmod +x scripts-local/bootstrap-remote.sh
./scripts-local/bootstrap-remote.sh .env https://github.com/your-name/tg-digest-server-init.git
```

**Скрипт запросит пароль:**
```
==========================================
Требуется пароль для SSH подключения
==========================================
Введи пароль SSH: [скрытый ввод]
```

Введи пароль root пользователя сервера.

**Или передай пароль через переменную окружения (безопаснее):**
```bash
SSH_PASSWORD="your-password" ./scripts-local/bootstrap-remote.sh .env https://github.com/your-name/tg-digest-server-init.git
```

**Или через параметр (менее безопасно, видно в истории):**
```bash
./scripts-local/bootstrap-remote.sh .env https://github.com/your-name/tg-digest-server-init.git --password "your-password"
```

**С локальной копией вместо git:**
```bash
./scripts-local/bootstrap-remote.sh .env /path/to/local/repo
```

**Скрипт сделает:**
- Проверит SSH подключение (с паролем)
- Установит git на сервере если требуется
- Скопирует репозиторий в `/opt/server-bootstrap`
- Загрузит `.env` файл безопасно

**Если все ОК - увидишь:**
```
[SUCCESS] Локальная часть завершена успешно!

СЛЕДУЮЩИЕ ШАГИ НА СЕРВЕРЕ:
1. Подключись к серверу:
   ssh -p 22 root@192.168.1.100

2. Запусти главный bootstrap (ОТ ROOT):
   cd /opt/server-bootstrap
   sudo bash bootstrap.sh

3. Когда скрипт попросит - проверь новый SSH порт
   в ДРУГОЙ сессии:
   ssh -p 2222 deploy@192.168.1.100
   ...
```

## Безопасный порядок применения

### ⚠️ КРИТИЧНО: Потеря доступа по SSH

Неправильное применение SSH hardening может **безвозвратно отрезать доступ** к серверу!

### Порядок выполнения на сервере

**1. SSH подключись к серверу:**
```bash
ssh -p 22 root@192.168.1.100
cd /opt/server-bootstrap
```

**2. Запусти bootstrap (он выполнит шаги 1-5):**
```bash
sudo bash bootstrap.sh
```

**Этапы автоматически:**
- ✅ 01-base.sh - Базовая система + hostname + timezone
- ✅ 02-user.sh - Создание пользователя + SSH ключ
- ✅ 03-firewall.sh - UFW (откроет новый SSH порт)
- ⚠️ 04-ssh-hardening.sh - **ОСТАНАВЛИВАЕТСЯ** (требует APPLY_SSH_CHANGES=true)
- ⚠️ 05-fail2ban.sh - Защита от brute-force
- ✅ 06-docker-optional.sh - Docker (если ENABLE_DOCKER=true)
- ✅ 90-verify.sh - Проверка всего

**3. Скрипт выведет перед SSH hardening:**
```
[WARN] ==========================================
[WARN] ВНИМАНИЕ: SSH изменения не применены!
[WARN] ==========================================

Это КРИТИЧНЫЙ шаг - потом будет сложно подключиться!

Перед применением:
1. Откройте НОВУЮ SSH сессию
2. Проверьте новый порт: ssh -p 2222 deploy@192.168.1.100
3. Только после УСПЕШНОГО входа финализируйте

Чтобы применить SSH изменения, установите:
APPLY_SSH_CHANGES=true
```

## Проверка нового SSH-подключения (ОБЯЗАТЕЛЬНО!)

**✅ ДО закрытия текущего SSH подключения:**

**В НОВОЙ сессии на твоем компьютере:**
```bash
# Проверь что новый порт работает
ssh -p 2222 deploy@192.168.1.100

# Должна быть успешная аутентификация
# (без пароля, только ключом)
```

**Если вход успешен:**
- ✅ SSH ключ правильно загружен
- ✅ Новый порт открыт в firewall
- ✅ Пользователь создан корректно

**Если вход НЕУДАЧЕН:**
- ❌ Не закрывай старую сессию!
- ❌ Вернись в старое подключение
- ❌ Проверь конфиг и переделай

**💡 Важно о root:**
- Root login отключен через `PermitRootLogin no`
- Для root операций используй `sudo` от пользователя `deploy`
- Это измеримо повышает безопасность сервера

## Финализация hardening

**Когда проверка новой сессии успешна:**

**В текущей SSH сессии на сервере:**
```bash
# Отредактируй .env
nano /opt/server-bootstrap/.env

# Измени:
APPLY_SSH_CHANGES=true
FINALIZE_FIREWALL=true

# Сохрани и выйди (Ctrl+X -> y -> Enter)
```

**Запусти bootstrap еще раз:**
```bash
sudo bash bootstrap.sh
```

**Этап 04-ssh-hardening.sh теперь:**
- Применит drop-in конфиг SSH
- Перезагрузит SSH сервис
- Отключит root login (окончательно)
- Отключит парольную аутентификацию (окончательно)

**После этого:**
- Используй ТОЛЬКО новый порт 2222
- Используй ТОЛЬКО пользователя deploy (или другой из ALLOW_USERS)
- Используй ТОЛЬКО SSH ключ (пароли отключены)

## Docker Security Notes

**ВАЖНО:** Docker может обойти firewall правила!

**Правила:**
- 🚫 НЕ публикуй контейнерные порты наружу без необходимости
- ✅ Используй `127.0.0.1:port:port` для localhost-only
- ✅ Используй `internal: true` сети для полной изоляции
- 🚫 НЕ добавляй пользователей в `docker` группу (эквивалент root)
- 📖 Полные notes в `configs/docker/README.md`

**Пример безопасного compose:**
```yaml
services:
  app:
    image: myapp:1.0
    # ✅ Правильно - только локально
    ports:
      - "127.0.0.1:8080:8080"
    security_opt:
      - no-new-privileges:true
    cap_drop:
      - ALL
    read_only: true
```

## Recovery / Rollback

### Если потерял доступ по SSH

**Если используешь облачного провайдера (Digitalocean, Linode, AWS):**
1. Используй их веб-консоль (Console, noVNC, etc.)
2. Логинься как root (если доступна)
3. Проверь `/etc/ssh/sshd_config.d/99-pet-hardening.conf`
4. Переименуй файл в `.bak`:
   ```bash
   mv /etc/ssh/sshd_config.d/99-pet-hardening.conf \
      /etc/ssh/sshd_config.d/99-pet-hardening.conf.bak
   systemctl reload ssh
   ```
5. Подключись обратно со старыми параметрами
6. Найди ошибку и переделай

### Если хочешь откатить изменения полностью

**Backup файлы хранятся как `.timestamp.bak`:**
```bash
# Найди backups
ls -la /etc/ssh/sshd_config.d/
ls -la /etc/fail2ban/

# Восстанови если нужно
cp /path/to/sshd_config.1234567890.bak /etc/ssh/sshd_config
systemctl reload ssh
```

### Переделать сервер с нуля

```bash
# На сервере (если доступ есть)
sudo rm -rf /opt/server-bootstrap

# На клиенте - запусти bootstrap еще раз
./scripts-local/bootstrap-remote.sh .env <repo>
```

## Post-install чекстер

**На твоем компьютере:**

```bash
ssh -p 2222 deploy@192.168.1.100 "
echo '=== Hostname ===' && hostname && \
echo '=== User ===' && whoami && \
echo '=== Sudo ===' && sudo -l && \
echo '=== SSH Port ===' && grep Port /etc/ssh/sshd_config.d/99-pet-hardening.conf && \
echo '=== Firewall ===' && sudo ufw status | grep -E 'Status|2222' && \
echo '=== Fail2Ban ===' && sudo fail2ban-client status sshd 2>/dev/null || echo 'Not ready' && \
echo '=== Docker ===' && docker --version 2>/dev/null || echo 'Not installed' && \
echo '=== Logs ===' && ls -lh /var/log/tg-digest-server-init/
"
```

## Типичные проблемы

### "Permission denied (publickey)"

- Проверь что SSH_PUBLIC_KEY в .env - это содержимое ~/.ssh/id_ed25519.pub
- Проверь что ключ не содержит опечаток
- Убедись что используешь правильный ключ локально:
  ```bash
  ssh -i ~/.ssh/id_ed25519 -p 2222 deploy@192.168.1.100
  ```

### "Connection refused" на порту 2222

- Сервер еще не завершил bootstrap
- Или APPLY_SSH_CHANGES остается false
- Проверь статус скрипта в логах:
  ```bash
  tail -f /var/log/tg-digest-server-init/bootstrap.log
  ```

### UFW блокирует трафик

- Проверь статус:
  ```bash
  sudo ufw status verbose
  ```
- Если нужен доступ к приложению (локально):
  ```bash
  sudo ufw allow from 127.0.0.1 to 127.0.0.1 port 8080
  ```

### Docker не может запустить контейнер

- Проверь права:
  ```bash
  docker ps
  sudo docker ps
  ```
- Если нужен доступ без sudo - добавь в docker group:
  ```bash
  sudo usermod -aG docker deploy
  # ⚠️ Это эквивалент root доступа!
  ```

## License

MIT - используй свободно

## Support

Если что-то сломалось:
1. Читай `/var/log/tg-digest-server-init/bootstrap.log` на сервере
2. Проверь конфиг в `.env`
3. Переделай нужный этап заново
4. Скрипты идемпотентны - безопасно запускать несколько раз
