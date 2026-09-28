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
