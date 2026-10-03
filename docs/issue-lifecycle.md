# Issue Lifecycle

Issue, привязанный к PR, проходит через состояния, которые определяются активностью вокруг PR. Состояния представлены метками на issue, переходы выполняет workflow `.github/.github/workflows/issue-lifecycle-bot.yml`.

## Состояния

### Слоты готовности (feature-pipeline)

Дополняют автоматические `status:*` снизу. Подробные правила — в [`minchat-hq/docs/process/feature-pipeline/rules.md`](https://github.com/min-null/minchat-hq/blob/main/docs/process/feature-pipeline/rules.md).

| Состояние | Переход | Метка | Кто ставит |
|---|---|---|---|
| `inbox` | создана новая issue без меток | `status:inbox` | Бот (auto) |
| `backlog` | разобрана, отложена | `status:backlog` | Человек |
| `pickable` | готова к работе, можно брать | `status:pickable` | Человек (после проверки 7 условий) |

Бот **не** переводит issue из `inbox` в `backlog`/`pickable` автоматически — это делает человек. Бот только ставит `inbox` на свежую issue.

### Автоматические состояния (PR-привязанные)

| Состояние | Переход | Метка | Что делает бот |
|---|---|---|---|
| `in-review` | открыт PR, ссылающийся на issue | `status:in-review` | ставит метку, пишет комментарий |
| `in-develop` | PR смёржен в `develop` | `status:in-develop` | ставит метку, пишет комментарий |
| `in-release` | открыт release PR (`develop → main`, метка `release`) | `status:in-release` | ставит метку, пишет комментарий |
| `released` | release PR смёржен в `main` | `status:released` | ставит метку, пишет комментарий, закрывает issue |

Состояния монотонны по времени, не по факту. Бот не «понижает» состояние, если PR закрыт не merge'ом; правки меток вручную бот не отменяет.

## Stale-bot (feature-pipeline)

Каждый час (в том же расписании, что основной цикл) бот проверяет:

1. **Любая застрявшая issue** (любого типа — эпики, фичи, баги): нет активности (комментариев, label changes, assign changes) **14 дней** → автоматически ставит `coordination:needs-decision` и пишет комментарий. **Исключение**: если есть `assignee` — не трогать.
2. **Эпики без `## Sub-tasks` 7 дней**: эпик-issues без секции `## Sub-tasks` через 7 дней после создания → `coordination:needs-decision` с предложением «разбить на sub-tasks или закрыть».

Метка `coordination:needs-decision` снимается **только человеком** (или автоматически при `status:released`).

Застрявшие задачи попадают в saved view «Feature Planning» (filter: `is:open label:coordination:needs-decision`).

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
    ▼ (бот) status:inbox
    │   разобрана → status:backlog (человек)
    │   готова    → status:pickable (человек, после 7 условий)
    │   в работе  → branch + PR (Closes #N)
    ▼
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

(параллельно, по таймеру)
    ▼ 14 дней без активности (любой тип)
coordination:needs-decision   →   saved view «Feature Planning»

(для эпиков)
    ▼ 7 дней без `## Sub-tasks`
coordination:needs-decision   →   saved view «Feature Planning»
```
