#!/usr/bin/env bash
# Вливает ветку worktree задачи в ветку основного чекаута одним коммитом с итоговым сообщением.
#   land.sh <ветка worktree> [<ссылка на issue>] <<'EOF'
#   <итоговое сообщение>
#   EOF
# Со ссылкой на issue GitHub или GitLab дописывает к сообщению строку «Closes …»: по ней трекер
# закрывает issue, когда коммит попадает в ветку по умолчанию. Issue другого хоста, чем origin, строка
# не закроет, и скрипт вливает без неё, сказав об этом.
set -euo pipefail

if [[ $# -lt 1 || $# -gt 2 ]]; then
  echo "land: аргументы — <ветка worktree> [<ссылка на issue>], а не «$*»; итоговое сообщение — на stdin" >&2
  exit 1
fi
branch=$1
issue=${2:-}

# Пустые строки по краям сообщения снимаются: строка Closes встаёт отдельным абзацем ровно через одну
message=$(sed -e 's/[[:space:]]*$//' | sed -e '/./,$!d' | sed -e ':a' -e '/^\n*$/{$d;N;ba' -e '}')
if [[ -z $message ]]; then
  echo "land: на stdin нет итогового сообщения" >&2
  exit 1
fi

if [[ -n $issue ]]; then
  # GitHub: https://host/owner/repo/issues/N; GitLab: https://host/group/…/project/-/issues/N
  if [[ $issue =~ ^https?://([^/]+)/(.+)/issues/([0-9]+)([/?#].*)?$ ]]; then
    host=${BASH_REMATCH[1]}
    path=${BASH_REMATCH[2]%/-}
    number=${BASH_REMATCH[3]}
  else
    echo "land: «$issue» — не ссылка на issue GitHub или GitLab (https://…/issues/<номер>); задачу без issue вливай без второго аргумента" >&2
    exit 1
  fi
fi

# Основной чекаут — первый каталог в git worktree list
primary=$(git worktree list --porcelain | sed -n '1s/^worktree //p')
target=$(git -C "$primary" branch --show-current)
if [[ -z $target ]]; then
  echo "land: основной чекаут $primary не на ветке (detached HEAD)" >&2
  exit 1
fi
worktree=$(git worktree list --porcelain |
  awk -v ref="refs/heads/$branch" '/^worktree /{path=substr($0, 10)} $0 == "branch " ref {print path}')
if [[ -z $worktree ]]; then
  echo "land: у ветки «$branch» нет worktree — ветки с worktree печатает git worktree list" >&2
  exit 1
fi

# host/путь репозитория из адреса: https://host/путь(.git), ssh://git@host:порт/путь и git@host:путь(.git)
# дают одно и то же — без порта и в нижнем регистре, как их сравнивают GitHub и GitLab
repo_of() {
  sed -E -e 's#^[a-z+]+://##' -e 's#^[^@/]+@##' -e 's#^([^/:]+):[0-9]+/#\1/#' -e 's#:#/#' -e 's#\.git$##' -e 's#/$##' <<<"${1,,}"
}

# Строку Closes пишет только скрипт: форма ссылки зависит от origin, и рукописная закрыла бы не тот issue
theirs=$(grep -iE '^[[:space:]]*(close[sd]?|fix(e[sd])?|resolve[sd]?)[[:space:]:]+[^[:space:]]*#[0-9]+' <<<"$message" || true)
closes=
if [[ -n $issue ]]; then
  origin=$(repo_of "$(git -C "$primary" remote get-url origin 2>/dev/null || true)")
  # Issue своего репозитория закрывает #N, а чужого на том же хосте — только путь/репозиторий#N
  issue_host=${host%:*}
  if [[ $origin == "${issue_host,,}/${path,,}" ]]; then
    closes="Closes #$number"
  elif [[ $origin == "${issue_host,,}"/* ]]; then
    closes="Closes $path#$number"
  else
    echo "land: строка Closes не дописана — issue на $host, а origin — «${origin:-не задан}»: коммит этого репозитория его не закроет, закрой issue руками"
  fi
fi
if [[ -n $theirs && ${theirs,,} != "${closes,,}" ]]; then
  echo "land: в сообщении уже стоит «$theirs» — убери её: закрывающую строку дописывает сам land.sh по ссылке на issue" >&2
  exit 1
fi
if [[ -n $closes && -z $theirs ]]; then
  message+=$'\n\n'"$closes"
fi
if [[ -n $closes ]]; then
  echo "land: в сообщение коммита входит строка «$closes» — issue закроется, когда коммит попадёт в ветку по умолчанию"
fi

# Один коммит wt land вливает с его собственным сообщением, а не с --message
if [[ $(git -C "$primary" rev-list --count "$target..$branch") == 1 ]]; then
  git -C "$worktree" commit --quiet --amend --message="$message"
fi

cd "$primary"
wt -y land --message="$message" -- --branch "$branch"
