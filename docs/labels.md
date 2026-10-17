# Словарь labels

Этот документ описывает единый labels-словарь организации `min-null`.
Подробные правила — в [`minchat-hq/docs/ownership.md`](https://github.com/min-null/minchat-hq/blob/main/docs/ownership.md)
и [`minchat-hq/docs/project-management.md`](https://github.com/min-null/minchat-hq/blob/main/docs/project-management.md).

Словарь применяется единообразно во всех code/ops репозиториях.
Project-поля `Status / Priority / Area / Target release / Size / Risk`
не дублируются labels.

## Type (что это)

| Label | Когда |
|---|---|
| `type:feature` | Новая функциональность. Требует product gate для `M+` |
| `type:bug` | Что-то не работает или работает неправильно |
| `type:chore` | Техдолг, обслуживание, рефакторинг без изменения поведения |
| `type:research` | Spike, discovery, RFC. До решения — это обсуждение, не задача |
| `type:security` | Безопасность: находка, контроль, threat model |

## Area (где)

Каждый issue должен иметь минимум один `area:*`. Это определяет
владельца и место, где будет вестись работа.

| Label | Репозиторий-владелец |
|---|---|
| `area:backend` | `minchat-backend` |
| `area:contracts` | `minchat-backend/shared` (cross-repo) |
| `area:web` | `minchat-frontend-web` |
| `area:desktop` | `minchat-frontend-desktop` |
| `area:android` | `minchat-frontend-android` |
| `area:flutter` | `minchat-frontend-flutter` |
| `area:ops` | `minchat-ops` |
| `area:hq` | `minchat-hq` (coordinator по умолчанию) |

## Priority (насколько срочно)

Обязательное условие `status:pickable`: без `priority:*` задача не может быть
поднята в борт (см. `minchat-hq/docs/process/feature-pipeline/rules.md`, условие 5).

| Label | Когда |
|---|---|
| `priority:critical` | Ломает основной сценарий, обхода нет |
| `priority:high` | Нужен в ближайшем цикле |
| `priority:medium` | Важен, но не блокирует |
| `priority:low` | Можно сделать позже, влияния нет |

`priority:high` появился раньше остальных и исторически используется шире всех,
поэтому в шкале их четыре. Новые задачи выбирают значение осознанно; проставка
приоритета — решение владельца, агент предлагает и аргументирует.

## Coordination (как)

| Label | Когда |
|---|---|
| `coordination:cross-repo` | Задача затрагивает несколько репозиториев; требуется parent issue в `minchat-hq` |
| `coordination:blocked` | Заблокировано другой задачей; обязательно ссылка на блокер |
| `coordination:needs-decision` | Нужно продуктовое или техническое решение; помечается owner-ом |

## Risk (что может пойти не так)

| Label | Когда |
|---|---|
| `risk:security` | Требует security review перед merge |
| `risk:privacy` | Затрагивает персональные данные, требует privacy review |
| `risk:migration` | Связан с миграцией БД или кодовой базы; см. migration policy |
| `risk:release` | Затрагивает release-train, требует release-pr |

## Status (feature-pipeline)

Слоты готовности issue. Дополняют автоматические `status:in-review/in-develop/in-release/released` (см. [`docs/issue-lifecycle.md`](./issue-lifecycle.md)). Подробные правила — в [`minchat-hq/docs/process/feature-pipeline/README.md`](https://github.com/min-null/minchat-hq/blob/main/docs/process/feature-pipeline/README.md).

| Label | Когда | Кто ставит |
|---|---|---|
| `status:inbox` | Новая, не разобрана. Бот ставит автоматически на issue без меток. | Бот |
| `status:backlog` | Разобрана, отложена. Не в этой итерации. | Человек или Product Owner |
| `status:pickable` | Готова к работе, можно брать. Проверяется джобом `readiness-gate` по 6 условиям (см. [rules.md](https://github.com/min-null/minchat-hq/blob/main/docs/process/feature-pipeline/rules.md)). | Человек или Product Owner |

> С 17.10.2026 `status:pickable` ставится человеком **или** Product Owner под мандатом
> ([product-owner/README.md](https://github.com/min-null/minchat-hq/blob/main/docs/process/product-owner/README.md)).
> Бот не ставит её — он проверяет обоснованность и снимает, если задача не готова.

## Gate (feature-pipeline)

**Гейты больше не блокируют переход в `status:pickable`.** С 17.10.2026 задача с
открытым `needs:design` берётся в работу. Метки остались как список «что ещё стоит
доделать для удобства».

Условие «все `needs:*` закрыты `*:approved`» было седьмым из семи и требовало
человека. Оно удалено, и правило теперь исполняется кодом, а не договорённостью.

| Label | Когда снимается |
|---|---|
| `needs:research` | После проведения research и занесения результатов в issue body |
| `needs:spec` | Когда в body появляется секция `## Acceptance criteria` или чеклист |
| `needs:design` | Когда артефакт дизайна приложен к issue |
| `needs:contract` | Когда контракт опубликован и ссылка добавлена в issue |
| `needs:adr` | Когда ADR опубликован |

## Approval (feature-pipeline)

**Информационные метки.** Они не закрывают гейт и не дают пропуска: задача берётся
без них. Ставить может человек или Product Owner — но только если решение реально
принято и записано в issue текстом, с владельцем и датой. Метка без текста решения
утверждает, что одобрение есть, а его нет.

Если без решения **начать нельзя**, это пишется в acceptance criteria задачи — там
это настоящее требование, а не цветная метка.

| Label | Что означает |
|---|---|
| `design:approved` | Дизайн принят, решение записано в issue |
| `contract:approved` | Контракт принят |
| `adr:approved` | ADR принят |

## Что НЕ используется как label

- `P0`, `P1`, `P2`, `P3` — это поле Project, не label.
- `Status`, `Target release`, `Iteration` — поля Project.
- Технические дублирующие метки (`backend`, `frontend`, `flutter`, `shared`,
  `devops`, `product`) заменяются на `area:*` и `type:*`.

## Разлив labels по репозиториям

Labels в GitHub — per-repository и **не наследуются**. Шаблон ниже
позволяет держать словарь синхронным:

```bash
# из scripts/sync-labels.sh
./scripts/sync-labels.sh min-null/<repo>
```

PR на добавление labels в новый репозиторий обязан включать запуск
этого скрипта и не должен менять сами labels.

## Аудит

Изменения словаря — через PR в `min-null/.github`. Любой code/ops
репозиторий, которому нужно добавить/убрать метку, открывает PR
против этого документа, а не против своего `.github/labels.yml`.
