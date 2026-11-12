# Метки GitHub

Метки нужны для поиска и понятной координации. Они не являются формой, readiness gate или разрешением начинать работу.

## Базовые метки

| Семейство | Значение |
|---|---|
| `type:*` | Вид работы: feature, bug, chore, research, security |
| `area:*` | Основная часть продукта: backend, contracts, web, desktop, android, flutter, ops, hq |
| `coordination:cross-repo` | В одной задаче участвует несколько репозиториев |
| `coordination:blocked` | Внешняя зависимость мешает продолжать; укажи причину и ссылку |
| `coordination:needs-decision` | Конкретный вопрос ждёт решения владельца |

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

## Автоматические статусы PR

`status:in-review`, `status:in-develop`, `status:in-release` и `status:released` отражают продвижение PR. Их проставляет [Issue Lifecycle Bot](./issue-lifecycle.md).

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

`status:inbox/backlog/pickable`, `needs:*` и `*:approved` относятся к прежнему процессу. Они не блокируют старт и не нужны новым задачам. Оставь старые метки для исторического контекста или сними при обычной правке issue; массово удалять их не нужно.

## Синхронизация

Labels per-repository. Чтобы создать или обновить базовый набор:

```bash
./scripts/sync-labels.sh min-null/<repo>
```

Скрипт не удаляет существующие метки. Изменения самого словаря проходят через PR в `min-null/.github`.
