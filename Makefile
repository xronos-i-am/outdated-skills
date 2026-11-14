# Обвязка разработки приходит из skill-kit той версии, что записана в apm.yml
KIT := apm_modules/xronos-i-am/skill-kit/kit
# Корень Claude для apm install -g: ~/.claude/skills и rules — симлинки сюда, а сквозь симлинк apm не пишет
APM_GLOBAL_ENV := CLAUDE_CONFIG_DIR=$(HOME)/.claude-profiles/shared

.PHONY: install setup release
# Ставит глобально последний выпущенный тег, а не рабочую копию: до агента доходит только выпущенная
# версия скилла. Пакет — путь репозитория из origin, как в release.sh; kit не нужен, и install проходит
# без make setup
install:
	@pkg=$$(git remote get-url origin 2>/dev/null | sed -E 's#^[a-z+]+://##; s#^[^/@]*@##; s#^[^/:]+[:/]##; s#^[0-9]+/##; s#\.git$$##'); \
	[ -n "$$pkg" ] || { echo "make install: у репозитория нет origin — добавьте его: git remote add origin <адрес>" >&2; exit 1; }; \
	tag=$$(git ls-remote --tags --sort=-v:refname origin 'v*' | sed -n '1s#.*refs/tags/\(v[^^]*\).*#\1#p'); \
	[ -n "$$tag" ] || { echo "make install: у origin нет тега vX.Y.Z — выпустите версию: make release" >&2; exit 1; }; \
	cd ~/.apm && $(APM_GLOBAL_ENV) apm install -g $$pkg#$$tag

# После клона и правки своего скилла: ставит apm и lefthook из mise.toml, skill-kit и dev-скиллы,
# поднимает версию kit в apm.yml до последнего тега и ставит хуки
setup:
	@command -v mise >/dev/null || { echo "make setup: нет mise — поставьте его: https://mise.jdx.dev/getting-started.html" >&2; exit 1; }
	mise trust --quiet
	mise install
	apm install
	$(KIT)/bump-kit.sh
	lefthook install

# make release [minor|major] — по умолчанию patch; слово после release уходит в release.sh, и он
# проверяет его до выпуска, а не make — после
ifeq (release,$(firstword $(MAKECMDGOALS)))
  RELEASE_PART := $(wordlist 2,$(words $(MAKECMDGOALS)),$(MAKECMDGOALS))
  $(eval $(RELEASE_PART):;@:)
endif
release:
	$(KIT)/release.sh $(RELEASE_PART)
