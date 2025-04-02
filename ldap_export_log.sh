#!/bin/bash

LDAP_SERVER="ldap://****"
LDAP_BIND_DN="ldap_user@mail.mail"
LDAP_PASSWORD="password"

DISABLED_BASE="OU=disabled,DC=domain,DC=local"
ACTIVE_BASES=("OU=Users,DC=domain,DC=local")

ACTIVE_EXPORT_FILE="ldap_users_export.ldif"
DISABLED_EXPORT_FILE="disabled_users.ldif"
NEW_USERS_FILE="new_users.ldif"
PREVIOUS_EXPORT_FILE="ldap_users_export_previous.ldif"
LOGFILE="log/ldap_export.log"

export LDAPTLS_REQCERT=never

log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') $1" >> "$LOGFILE"
}

log "===== Начало экспорта LDAP пользователей ====="

# Архивируем предыдущий экспорт
if [[ -f "$ACTIVE_EXPORT_FILE" ]]; then
    mv "$ACTIVE_EXPORT_FILE" "$PREVIOUS_EXPORT_FILE"
fi

# Очищаем/создаём файлы
> "$ACTIVE_EXPORT_FILE"
> "$DISABLED_EXPORT_FILE"
> "$NEW_USERS_FILE"

# Обрабатываем активные OU
for base in "${ACTIVE_BASES[@]}"; do
    log "Поиск пользователей в базе: $base"
    if ldapsearch -x -H "$LDAP_SERVER" -D "$LDAP_BIND_DN" -w "$LDAP_PASSWORD" \
        -b "$base" "(objectClass=person)" sAMAccountName givenName sn mail userAccountControl >> "$ACTIVE_EXPORT_FILE"; then
        log "Успешный экспорт из: $base"
    else
        log "❌ Ошибка при экспорте из: $base"
    fi
done

# Обрабатываем OU DisabledAccounts
log "Поиск отключённых пользователей в базе: $DISABLED_BASE"
if ldapsearch -x -H "$LDAP_SERVER" -D "$LDAP_BIND_DN" -w "$LDAP_PASSWORD" \
    -b "$DISABLED_BASE" "(objectClass=person)" sAMAccountName >> "$DISABLED_EXPORT_FILE"; then
    log "Успешный экспорт из: $DISABLED_BASE"
else
    log "❌ Ошибка при экспорте из: $DISABLED_BASE"
fi

# Подсчёт результатов
ACTIVE_COUNT=$(grep -c "^dn:" "$ACTIVE_EXPORT_FILE")
DISABLED_COUNT=$(grep -c "^dn:" "$DISABLED_EXPORT_FILE")
log "Найдено активных пользователей: $ACTIVE_COUNT"
log "Найдено отключённых пользователей: $DISABLED_COUNT"

# Поиск новых пользователей
log "Сравнение с предыдущим экспортом для поиска новых пользователей..."
if [[ -f "$PREVIOUS_EXPORT_FILE" ]]; then
    # Извлекаем DN'ы
    grep "^dn:" "$ACTIVE_EXPORT_FILE" | sort > current_dns.txt
    grep "^dn:" "$PREVIOUS_EXPORT_FILE" | sort > previous_dns.txt

    comm -23 current_dns.txt previous_dns.txt > new_dns.txt

    if [[ -s new_dns.txt ]]; then
        while read -r dn; do
            # Выводим блок, соответствующий новому DN
            awk -v dn="$dn" '
                BEGIN {found=0}
                $0 ~ "^dn: " && found { exit }
                $0 == dn { print; found=1; next }
                found && $0 !~ /^#/ { print }
            ' "$ACTIVE_EXPORT_FILE"
            echo ""  # для разделения LDIF-записей
        done < new_dns.txt > "$NEW_USERS_FILE"

        NEW_USERS_COUNT=$(grep -c "^dn:" "$NEW_USERS_FILE")
        log "Найдено новых пользователей: $NEW_USERS_COUNT"
    else
        log "Нет новых пользователей."
    fi
else
    log "Нет предыдущего экспорта. Новый файл пользователей не сформирован."
fi

# Очистка временных файлов
rm -f current_dns.txt previous_dns.txt new_dns.txt

log "✅ Экспорт завершён успешно."
log "Файлы: $ACTIVE_EXPORT_FILE (активные), $DISABLED_EXPORT_FILE (отключённые), $NEW_USERS_FILE (новые)"
log "=============================================="

# Информируем в stdout
echo "Экспорт завершён."
echo "Активные пользователи: $ACTIVE_EXPORT_FILE ($ACTIVE_COUNT)"
echo "Отключённые пользователи: $DISABLED_EXPORT_FILE ($DISABLED_COUNT)"
[[ -f "$NEW_USERS_FILE" && -s "$NEW_USERS_FILE" ]] && echo "Новые пользователи: $NEW_USERS_FILE" || echo "Новых пользователей нет."

