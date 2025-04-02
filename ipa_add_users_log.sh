#!/bin/bash

IPA_PRINCIPAL="admin"
IPA_PASSWORD="adminpass"
IPA_CONTAINER_NAME="ipa-server"
EXPORT_FILE="new_users.ldif"
ADDED_USERS_LOG="log/added_users.log"
SCRIPT_LOG="log/ipa_import.log"

log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$SCRIPT_LOG"
}

# Аутентификация
log "Аутентификация Kerberos для $IPA_PRINCIPAL"
docker exec -i "$IPA_CONTAINER_NAME" bash -c "echo '$IPA_PASSWORD' | kinit '$IPA_PRINCIPAL'"
if [ $? -eq 0 ]; then
    log "Успешная аутентификация Kerberos"
else
    log "Ошибка аутентификации Kerberos"
    exit 1
fi

# Обработка файла и взаимодействие с FreeIPA
awk -v container="$IPA_CONTAINER_NAME" -v logfile="$ADDED_USERS_LOG" -v scriptlog="$SCRIPT_LOG" '
function log_added_user(uid) {
    "date \"+%Y-%m-%d %H:%M:%S\"" | getline timestamp
    close("date \"+%Y-%m-%d %H:%M:%S\"")
    print timestamp " - " uid >> logfile
}

function log_script(message) {
    "date \"+%Y-%m-%d %H:%M:%S\"" | getline timestamp
    close("date \"+%Y-%m-%d %H:%M:%S\"")
    print timestamp " - " message >> scriptlog
}

/^sAMAccountName:/ { uid=$2 }
/^givenName:/ { given=$2 }
/^sn:/ { sn=$2 }
/^mail:/ { mail=$2 }
/^userAccountControl:/ { uac=$2 }

/^$/ {
    if (uid && uac == 512) {
        cmd_check = "docker exec " container " ipa user-show " uid " >/dev/null 2>&1"
        if (system(cmd_check) != 0) {

            # Если фамилия отсутствует — подставляем "-"
            if (!sn) {
                log_script("Пустая фамилия у пользователя " uid ", подставляется дефолтное значение \"-\"")
                sn = "-"
            }

            cmd = "docker exec " container " ipa user-add " uid
            if (given) cmd = cmd " --first=\"" given "\""
            cmd = cmd " --last=\"" sn "\""
            if (mail) cmd = cmd " --email=\"" mail "\""

            log_script("Создание пользователя: " uid " (first=" given ", last=" sn ", mail=" mail ")")
            status = system(cmd)
            if (status == 0) {
                log_script("Пользователь " uid " успешно создан")
                log_added_user(uid)
            } else {
                log_script("Ошибка создания пользователя: " uid)
                print "Ошибка создания пользователя: " uid > "/dev/stderr"
            }
        } else {
            cmd = "docker exec " container " ipa user-mod " uid
            if (given) cmd = cmd " --first=\"" given "\""
            if (sn) cmd = cmd " --last=\"" sn "\""
            if (mail) cmd = cmd " --email=\"" mail "\""
            log_script("Обновление пользователя: " uid " (first=" given ", last=" sn ", mail=" mail ")")
            system(cmd)
        }

        cmd_status = "docker exec " container " ipa user-enable " uid
        log_script("Активация пользователя: " uid)
        system(cmd_status)
    }
    uid=given=sn=mail=uac=""
}
' "$EXPORT_FILE"

# Завершение сессии Kerberos
log "Завершение Kerberos-сессии"
docker exec "$IPA_CONTAINER_NAME" kdestroy
if [ $? -eq 0 ]; then
    log "Kerberos-сессия завершена успешно"
else
    log "Ошибка при завершении Kerberos-сессии"
fi

