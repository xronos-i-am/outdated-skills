# Обвязка разработки приходит из skill-kit той версии, что записана в apm.yml
KIT := apm_modules/xronos-i-am/skill-kit/kit

.PHONY: setup release
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
# Глобально пакет не ставится: хук нужен проектам с apm.yml, их он подключается зависимостью, а
# глобальная установка вернула бы хук в ~/.apm и в настройки Claude каждой сессии
release: export SKIP_GLOBAL_INSTALL := 1
release:
	$(KIT)/release.sh $(RELEASE_PART)
