# outdated-skills

Хук старта сессии: сообщает агенту об отставших зависимостях apm.yml проекта

## Установка

Глобально пакет не ставится: хук подключается зависимостью в `apm.yml` проекта, который он проверяет:

```yaml
dependencies:
  apm:
    - git: xronos-i-am/outdated-skills
      ref: v1.0.0
```

В репозитории скилла его приносит skill-kit.

## Что сообщает хук

Хук `SessionStart` запускает в каталоге сессии `COLUMNS=250 apm outdated` и передаёт агенту в контекст строки со статусом `outdated`: зависимости `apm.yml`, у которых вышла версия новее записанной.

- Хук только сообщает: `apm.yml`, `apm.lock.yaml` и установку он не меняет, `apm install` не запускает.
- Без `apm.yml` хук молчит.
- Без `apm.lock.yaml` сообщает, что проверка не сделана: `apm outdated` сверяет версии с lock-файлом.
- Если `apm outdated` завершился с ошибкой или в PATH нет `apm`, хук сообщает, что проверка не сделана.

### Доступ к gitlab

К gitlab apm ходит по https, даже когда в `apm.yml` записан `git@…`. Без логина по https зависимость молча показана как `unknown`, а не как отставшая. Дайте git логин по https:

```bash
glab auth login --hostname <хост>
git config --global credential.https://<хост>.helper '!glab auth git-credential'
```

`glab auth git-credential` — помощник git, который берёт токен из `glab`; первая команда сохраняет этот токен для хоста.
