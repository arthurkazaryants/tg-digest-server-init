# Docker Security Notes

## Правила безопасности контейнеров на этом сервере

### 1. Сетевая модель

По умолчанию **НЕ открывай** контейнерные порты наружу.

Используй:

```yaml
# ❌ ПЛОХО - публикует порт наружу
services:
  app:
    ports:
      - "8080:8080"

# ✅ ХОРОШО - только локально
services:
  app:
    ports:
      - "127.0.0.1:8080:8080"

# ✅ ХОРОШО - внутренняя сеть
services:
  app:
    expose:
      - 8080
    networks:
      - internal

networks:
  internal:
    internal: true
```

### 2. Docker daemon и безопасность

- **docker group эквивалентна root доступу**
- НЕ добавляй пользователями в `docker` группу без необходимости
- Если нужен docker для пользователя - используй `docker run --user`

Проверить:
```bash
getent group docker
grep docker /etc/group
```

### 3. UFW и Docker interact

UFW и Docker могут конфликтовать если публикуешь порты.

- Docker может обойти UFW правила если используешь `ports:`
- Используй `127.0.0.1:port:port` чтобы избежать публикации
- Или явно разреши в UFW перед публикацией

### 4. Volumes и права доступа

- Проверяй владельца volumes
- Используй `:ro` (read-only) где возможно
- НЕ монтируй `/` или системные директории

```bash
# Правильно
docker run -v /data/app:/app:ro myapp

# Неправильно
docker run -v /:/container ubuntu
```

### 5. Image безопасность

- Используй конкретные версии, не `latest`
- Сканируй images перед использованием:

```bash
docker image inspect myapp:1.0
docker run --rm aquasec/trivy image myapp:1.0
```

### 6. Runtime security

Используй security options:

```yaml
services:
  app:
    security_opt:
      - no-new-privileges:true
    cap_drop:
      - ALL
    cap_add:
      - NET_BIND_SERVICE
    read_only: true
    tmpfs:
      - /tmp
```

## Пример: безопасный compose

```yaml
version: '3.8'

services:
  app:
    image: myapp:1.0
    restart: unless-stopped
    
    # Сеть - только локально
    ports:
      - "127.0.0.1:8080:8080"
    
    # Безопасность
    security_opt:
      - no-new-privileges:true
    cap_drop:
      - ALL
    read_only: true
    
    # Volumes
    volumes:
      - /data/app:/app:ro
      - /tmp:/tmp
    
    # Ресурсы
    deploy:
      resources:
        limits:
          cpus: '0.5'
          memory: 512M
        reservations:
          cpus: '0.25'
          memory: 256M
    
    environment:
      - LOG_LEVEL=info
    
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8080/health"]
      interval: 30s
      timeout: 5s
      retries: 3

networks:
  default:
    internal: true
```

## Проверка после развертывания

```bash
# Слушающие порты - должны быть локальные
sudo ss -tlnp

# UFW статус - не должны быть открыты app порты
sudo ufw status verbose

# Docker networks
docker network ls
docker network inspect bridge

# Running containers
docker ps -a

# Docker logs
docker logs --tail 100 container_name
```
