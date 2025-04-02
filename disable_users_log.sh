#!/bin/bash

IPA_PRINCIPAL="admin"
IPA_PASSWORD="adminpass"
IPA_CONTAINER_NAME="ipa-server"
DISABLED_USERS_FILE="disabled_users.ldif"
LOGFILE="log/disabled_users.log"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> "$LOGFILE"
}

log "=== Запуск скрипта отключения пользователей ==="

# Проверка, что контейнер существует
if ! docker ps -a --format '{{.Names}}' | grep -Fxq "$IPA_CONTAINER_NAME"; then
    log "ERROR: контейнер '$IPA_CONTAINER_NAME' не найден"
    exit 1
fi
log "Контейнер найден"

# Аутентификация через kinit
docker exec -i "$IPA_CONTAINER_NAME" bash -c "echo '$IPA_PASSWORD' | kinit '$IPA_PRINCIPAL'"
if [ $? -ne 0 ]; then
    log "ERROR: не удалось аутентифицироваться через kinit"
    exit 1
else
    log "Успешная аутентификация Kerberos через kinit"
fi

# Обработка списка пользователей
awk -v container="$IPA_CONTAINER_NAME" -v logf="$LOGFILE" '
/^sAMAccountName:/ { uid=$2 }
/^$/ {
    if (uid) {
        cmd_check = "docker exec " container " ipa user-show " uid " >/dev/null 2>&1"
        if (system(cmd_check) == 0) {
            cmd_disable = "docker exec " container " ipa user-disable " uid " >/dev/null 2>&1"
            if (system(cmd_disable) == 0) {
                now = strftime("[%Y-%m-%d %H:%M:%S] ")
                cmd_log = "echo \"" now "Пользователь успешно отключён: " uid "\" >> " logf
                system(cmd_log)
            }
        }
    }
    uid=""
}' "$DISABLED_USERS_FILE"

# Завершение Kerberos-сессии
docker exec "$IPA_CONTAINER_NAME" kdestroy
if [ $? -eq 0 ]; then
    log "Сессия Kerberos завершена"
else
    log "ERROR: Ошибка при завершении Kerberos-сессии"
fi

log "=== Завершение скрипта ==="

