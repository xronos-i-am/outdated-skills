#!/usr/bin/env bash
# Хук SessionStart: сообщает агенту зависимости apm.yml, у которых вышла версия новее записанной.
# Только сообщает: apm.yml, apm.lock.yaml и установку не меняет, apm install не запускает.
# Всё, что скрипт пишет в stdout, попадает в контекст сессии.

skip() {
  echo "outdated-skills: проверка отставания зависимостей не сделана — $1"
  exit 0
}

[ -f apm.yml ] || exit 0
[ -f apm.lock.yaml ] || skip "нет apm.lock.yaml, а apm outdated сверяет версии с ним."
command -v apm >/dev/null 2>&1 || skip "в PATH нет apm."

# COLUMNS=250: без него apm режет имена в таблице по ширине терминала.
# stderr отдельно: его строки не должны попасть в разбор таблицы
errors=$(mktemp) || skip "не создан временный файл."
trap 'rm -f "$errors"' EXIT
table=$(COLUMNS=250 apm outdated 2>"$errors") || skip "apm outdated завершился с ошибкой: $(head -n 5 "$errors")"

# Статус — последняя колонка таблицы; за ним допустимы пробелы и рамка
rows=$(grep -E 'outdated[[:space:]│┃|]*$' <<<"$table")
[ -n "$rows" ] || exit 0

echo "outdated-skills: у зависимостей apm.yml вышла версия новее записанной (apm outdated):"
echo "$rows"
