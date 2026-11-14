KIT := apm_modules/xronos-i-am/skill-kit/kit

.PHONY: setup release
setup:
	@command -v mise >/dev/null || { echo "make setup: нет mise — поставьте его: https://mise.jdx.dev/getting-started.html" >&2; exit 1; }
	mise trust --quiet
	mise install
	apm install
	$(KIT)/bump-kit.sh
	lefthook install

ifeq (release,$(firstword $(MAKECMDGOALS)))
  RELEASE_PART := $(wordlist 2,$(words $(MAKECMDGOALS)),$(MAKECMDGOALS))
  $(eval $(RELEASE_PART):;@:)
endif
release: export SKIP_GLOBAL_INSTALL := 1
release:
	$(KIT)/release.sh $(RELEASE_PART)
