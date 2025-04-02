# ldaptoipa

Набор shell-скриптов для миграции пользователей из LDAP в FreeIPA.

## Назначение

Этот репозиторий предназначен для автоматизации переноса пользователей из существующего LDAP-каталога в FreeIPA с возможностью последующего отключения старых аккаунтов.

Подходит для администраторов, которым требуется плавно перейти на FreeIPA, минимизируя ручные действия и ошибки.

## Сценарии

### `ldap_export_log.sh`
Экспортирует пользователей из LDAP в файл.

**Требования:**
- Установленный `ldapsearch`
- Настроенный доступ к LDAP-серверу

### `ipa_add_users_log.sh`
Добавляет пользователей, экспортированных из LDAP, в FreeIPA.

**Требования:**
- FreeIPA client tools (`ipa`)
- Аутентифицированный Kerberos-токен администратора FreeIPA

> **Примечание:** FreeIPA развёрнут в контейнере, доступ осуществляется по настроенному FQDN и через Kerberos. Убедитесь, что контейнер запущен и доступен из среды выполнения скриптов.

### `disable_users_log.sh`
Отключает указанных пользователей в FreeIPA, например, после успешной миграции.

## Использование

1. Выполните экспорт пользователей:
   ```bash
   ./ldap_export_log.sh
   ```

2. Проверьте экспортированные данные.

3. Добавьте пользователей в FreeIPA:
   ```bash
   ./ipa_add_users_log.sh
   ```

4. При необходимости — отключите старые аккаунты:
   ```bash
   ./disable_users_log.sh
   ```

## Примечания

- Скрипты логируют действия в отдельные файлы.
- FreeIPA развёрнут в контейнере. Убедитесь, что он доступен и корректно разрешается по FQDN.
- Рекомендуется запускать скрипты от имени пользователя с соответствующими правами.
- Перед выполнением операций в продуктивной среде — протестируйте в тестовом окружении.
