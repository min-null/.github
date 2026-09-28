# Issue Lifecycle

Issue, привязанный к PR, проходит через состояния, которые определяются активностью вокруг PR. Состояния представлены метками на issue, переходы выполняет workflow `.github/.github/workflows/issue-lifecycle-bot.yml`.

## Состояния

| Состояние | Переход | Метка | Что делает бот |
|---|---|---|---|
| `in-review` | открыт PR, ссылающийся на issue | `status:in-review` | ставит метку, пишет комментарий |
| `in-develop` | PR смёржен в `develop` | `status:in-develop` | ставит метку, пишет комментарий |
| `in-release` | открыт release PR (`develop → main`, метка `release`) | `status:in-release` | ставит метку, пишет комментарий |
| `released` | release PR смёржен в `main` | `status:released` | ставит метку, пишет комментарий, закрывает issue |

Состояния монотонны по времени, не по факту. Бот не «понижает» состояние, если PR закрыт не merge'ом; правки меток вручную бот не отменяет.

## Как связать issue и PR

В теле PR — любая из фраз, GitHub их распознаёт:

```text
Closes #42
Fixes #87
Resolves #103
```

Регистр не важен. Дополнительной метадаты не нужно. Ветка с именем `issues-<n>-*` тоже опознаётся, если в теле ничего не нашлось.

## Где лежит и что запускает

Workflow в `.github/.github/workflows/issue-lifecycle-bot.yml`. Триггеры:

- `pull_request` типа `closed` с `merged = true` — обрабатывает только что смёрженный PR;
- `schedule` каждый час — реконсиляция состояния по всем репам организационного флоу;
- `workflow_dispatch` — ручной запуск.

Полная кросс-репа работа требует, чтобы у workflow был `MIN_REPO_TOKEN` с правами `issues:write` и `pull-requests:read` на нужные репозитории. Без него бот покрывает только `.github` собственный.

## Границы

- Бот только пишет в issues и labels. PR-тела, код, contracts и deployment он не трогает.
- Каждый бот-комментарий начинается с префикса `[lifecycle-bot]`, чтобы их было легко фильтровать или скрывать.
- Бот идемпотентен: повторный запуск на том же PR не дублирует комментарий, а только подтверждает текущее состояние метки.
- Если PR упомянул issue из репы, к которой у workflow нет доступа, бот молча пропускает такой issue и продолжает с остальными. В логах остаётся запись.

## Сводный поток

```
issue открыт
    │
    ▼ PR открыт с Closes #N
status:in-review
    │
    ▼ PR смёржен → develop
status:in-develop
    │
    ▼ release PR открыт
status:in-release
    │
    ▼ release PR смёржен → main
status:released   →   issue закрыт (reason: completed)
```
