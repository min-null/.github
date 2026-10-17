# Issue Lifecycle

Issue, привязанный к PR, проходит через состояния, которые определяются активностью вокруг PR. Состояния представлены метками на issue, переходы выполняет workflow `.github/.github/workflows/issue-lifecycle-bot.yml`.

## Состояния

### Слоты готовности (feature-pipeline)

Дополняют автоматические `status:*` снизу. Подробные правила — в [`minchat-hq/docs/process/feature-pipeline/rules.md`](https://github.com/min-null/minchat-hq/blob/main/docs/process/feature-pipeline/rules.md).

| Состояние | Переход | Метка | Кто ставит |
|---|---|---|---|
| `inbox` | создана новая issue без меток | `status:inbox` | Бот (auto) |
| `backlog` | разобрана, отложена | `status:backlog` | Человек или Product Owner |
| `pickable` | готова к работе, можно брать | `status:pickable` | Человек или Product Owner |

Бот **не** переводит issue из `inbox` в `backlog`/`pickable` автоматически — это
решение человека или Product Owner под мандатом
([product-owner/README.md](https://github.com/min-null/minchat-hq/blob/main/docs/process/product-owner/README.md)).
Бот ставит `inbox` на свежую issue и **проверяет обоснованность** `status:pickable`.

### Readiness-gate

Джоб `readiness-gate` в `issue-lifecycle-bot.yml` срабатывает, когда issue получила
`status:pickable`, и проверяет 6 условий: описание, acceptance criteria,
`type:*` / `area:*` / `priority:*`, отсутствие `coordination:blocked`, не эпик.

- Готово — бот молчит.
- Не готово — снимает `status:pickable` и один раз пишет, чего не хватает
  (повторный комментарий не дублируется).

Ни одно из шести условий не требует решения человека. Гейты `needs:*` и
approval-метки `*:approved` в проверке **не участвуют** — они остались навигацией.
Раньше это было только прозой, и убрать гейт было нечего: теперь правило исполняется
кодом (`scripts/lib/readiness.sh`, тесты — `scripts/test-readiness.sh`).

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

Метку `coordination:needs-decision` снимает тот, кто решил: владелец или Product Owner (автоматически — при `status:released`).

Застрявшие задачи попадают в saved view «Feature Planning» (filter: `is:open label:coordination:needs-decision`).

## Как связать issue и PR

В теле PR — любая из закрывающих фраз, GitHub их распознаёт:

```text
Closes #42
Fixes #87
Resolves #103
```

Регистр не важен. Ветка с именем `issues-<n>-*` тоже опознаётся, если в теле ничего не нашлось.

### Два класса сигналов

Бот различает закрывающие и упоминающие ссылки. Это важно для release-PR: у них
head-ветка `develop`, поэтому запасной путь по имени ветки не работает, а связь с
задачами идёт через `Refs`.

| Класс | Фразы | Merge в `main` ставит | Merge в `main` закрывает |
|---|---|---|---|
| закрывающий | `Closes`, `Fixes`, `Resolves` (+ `fix`, `close`) | `status:released` | **да** |
| упоминающий | `Refs`, `See`, `Part of` | `status:released` | **нет** |

Если PR содержит только упоминающие ссылки, issue получает `status:released` и
комментарий, но остаётся открытым — закрытие за человеком. Это осознанно:
`Refs #42` в release-PR означает «задача #42 едет в этот релиз», а не «задача #42
этим PR завершена».

Если PR содержит обе категории для одного issue, побеждает закрывающая.

## Состояния монотонны

Метки состояния взаимоисключающие: при переходе вперёд бот снимает предыдущие
`status:*` и оставляет ровно одну актуальную. На issue в любой момент не должно
быть одновременно `status:pickable` и `status:in-develop`.

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
    │   разобрана → status:backlog (человек или PO)
    │   готова    → status:pickable (человек или PO, проверяет readiness-gate)
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
