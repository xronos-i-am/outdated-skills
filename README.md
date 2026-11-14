# outdated-skills

Session-start hook that tells the agent about outdated dependencies in the project's `apm.yml`.

Русская версия: [README.ru.md](README.ru.md)

## Installation

The package is not installed globally: the hook is added as a dependency in the `apm.yml` of the project it checks:

```yaml
dependencies:
  apm:
    - git: xronos-i-am/outdated-skills
```

## What the hook reports

The `SessionStart` hook runs `COLUMNS=250 apm outdated` in the session directory and passes the rows with the `outdated` status to the agent's context: the `apm.yml` dependencies that have a newer version than the one recorded.

- The hook only reports: it does not change `apm.yml`, `apm.lock.yaml` or the installation, and does not run `apm install`.
- Without `apm.yml` the hook stays silent.
- Without `apm.lock.yaml` it reports that the check was not done: `apm outdated` compares versions against the lock file.
- If `apm outdated` fails or `apm` is not in PATH, the hook reports that the check was not done.

### Access to gitlab

`apm` checks `gitlab` dependencies over `https`, even if `apm.yml` records a `git@…` address. If git cannot log in to gitlab over https, the dependency is shown as `unknown` rather than outdated. For the check to work, set up https login for the host:

```bash
glab auth login --hostname <host>
git config --global credential.https://<host>.helper '!glab auth git-credential'
```
