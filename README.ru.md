# outdated-skills

Хук старта сессии: сообщает агенту об отставших зависимостях `apm.yml` проекта

## Установка

Глобально пакет не ставится: хук подключается зависимостью в `apm.yml` проекта, который он проверяет:

```yaml
dependencies:
  apm:
    - git: xronos-i-am/outdated-skills
```

## Что сообщает хук

Хук `SessionStart` запускает в каталоге сессии `COLUMNS=250 apm outdated` и передаёт агенту в контекст строки со статусом `outdated`: зависимости `apm.yml`, у которых вышла версия новее записанной.

- Хук только сообщает: `apm.yml`, `apm.lock.yaml` и установку он не меняет, `apm install` не запускает.
- Без `apm.yml` хук молчит.
- Без `apm.lock.yaml` сообщает, что проверка не сделана: `apm outdated` сверяет версии с lock-файлом.
- Если `apm outdated` завершился с ошибкой или в PATH нет `apm`, хук сообщает, что проверка не сделана.

### Доступ к gitlab

`apm` проверяет `gitlab`-зависимости по `https`, даже если в `apm.yml` записан адрес `git@…`. Если git не может войти в gitlab по https, зависимость показана как `unknown`, а не как отставшая. Чтобы проверка работала, настройте для хоста вход по https:

```bash
glab auth login --hostname <хост>
git config --global credential.https://<хост>.helper '!glab auth git-credential'
```
