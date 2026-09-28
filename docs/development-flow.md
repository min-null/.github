# Единый флоу разработки и релиза MinChat

Канонический документ организации `min-null`. Он описывает **процесс** целиком:
от идеи до продакшена и отката. Репозитории не владеют процессом и не могут его
расширять — они хранят код, контракты, окружения и собственные runbook'и.

Если правило в этом документе расходится с `AGENTS.md` или `RELEASE_FLOW.md`
любого репозитория — **прав этот документ**. Расхождение нужно исправить, а не
обойти.

## Обязательные правила

Этот раздел обязателен к прочтению агентом **до** создания ветки, до подготовки
PR и до любого merge. Остальной документ нужен для понимания контекста.

1. **Единая веточная модель для всех репозиториев.** В каждом code/ops
   репозитории существуют `develop` (интеграция) и `main` (release lane).
   Нет исключений на уровне организации.

2. **Только develop-first.** Любая feature/fix-ветка создаётся от актуальной
   `develop` и открывает PR **в `develop`**. `main` — не место для прямой
   приёмки задач.

3. **Только release PR в `main`.** Ветка `main` принимает исключительно
   `develop → main` с меткой `release`. Никаких feature/fix PR в `main`, никакого
   `main → develop`.

4. **Теги — только из `main`.** Тег `release-<version>` создаётся после merge
   release PR, из коммита в `main`. Один и тот же тег ставится в **каждом**
   release-producing репозитории.

5. **Тег — единственный триггер продакшена.** Push в `develop`, merge feature PR
   и ручная сборка образа не являются деплоем. Dev-выпуск запускается явно и
   деплоит только dev.

6. **Красный gate — не причина его обходить.** Сначала исправь направление PR или
   вернись в integration flow. Зелёный `Release Gate` — обязательная ручная
   точка контроля, потому что branch protection на текущем тарифе недоступен.

7. **Репозиторий не придумывает процесс.** Репо добавляет только свои
   данные: контракты, команды, runbook'и, quality gate. Новые правила веток,
   релиза или merge живут здесь, в этом документе.

8. **Проверяй, а не утверждай.** Непроведённая проверка помечается `not_run` с
   причиной и не считается успешной.

9. **`develop` не удаляется.** Ветка интеграции не является временной: её не
   удаляют после release, не удаляют «чтобы привести репо в порядок» и не
   удаляют при переносе задачи. Если ветки нет — это инцидент, который чинят и
   разбирают, а не состояние, которое «надо было убрать». Ветка отсутствует
   ровно до момента восстановления из `main`; каждая такая попытка попадает в
   разбор, потому что ломает develop-first флоу для всех, кто открывает PR.

   На текущем тарифе запретить удаление технически нельзя: branch protection и
   repository rulesets недоступны для приватных репозиториев, а
   `delete_branch_on_merge` отключён. Поэтому защита состоит из двух слоёв:
   guard-workflow `develop-guard.yml` пересоздаёт ветку из `main` и явно
   сигналит об этом, а настоящий запрет требует смены тарифа.

## Сквозной пайплайн

```text
идея
  -> Project item (organization Project `MinChat`)
  -> issue (по умолчанию в minchat-hq)
  -> product gate (для новой функциональности)
  -> ветка feature/fix от develop
  -> PR в develop  +  quality gate репозитория
  -> merge в develop
  -> release PR develop -> main  (метка release, Release Gate)
  -> merge в main
  -> тег release-<version> в каждом release-producing репо
  -> dispatch в minchat-ops
  -> сборка digest-pinned пары образов
  -> deploy в prod + post-deploy smoke
  -> запись release BOM
  -> (при сбое) rollback по предыдущему BOM
```

### 1. Идея и задача

Новая идея сначала становится item в organization Project `MinChat`. Если нужны
обсуждение, история или ссылки — issue создаётся в `minchat-hq`. Repo-local
issue допустим только по исключениям из ownership policy.

Cross-repo инициатива — один parent issue в `minchat-hq` с чеклистом PR и
явно указанным integration/release path для каждого затронутого репозитория.

Канон: [minchat-hq/docs/ownership.md](https://github.com/min-null/minchat-hq/blob/main/docs/ownership.md),
[minchat-hq/docs/project-management.md](https://github.com/min-null/minchat-hq/blob/main/docs/project-management.md).

### 2. Product gate

Новая функциональность проходит продуктовый gate до реализации: пользователь,
мотивация, usage, основной и негативные пути, UX и критерий успеха. Наличие
готового backend endpoint не является причиной добавить поверхность в продукт.

Канон: [minchat-hq/docs/product-development-principles.md](https://github.com/min-null/minchat-hq/blob/main/docs/product-development-principles.md).

### 3. Ветка и PR в develop

```sh
git fetch origin
git switch develop && git pull --ff-only
git worktree add ../<repo>-issues-<номер>-<короткое-описание> -b issues-<номер>-<короткое-описание>
cd ../<repo>-issues-<номер>-<короткое-описание>
git submodule update --init --recursive
```

Каждый PR живёт в собственном worktree. Одна ветка = одна задача; объединять
две фичи в одну ветку запрещено.

PR в `develop` должен проходить quality gate своего репозитория. Направление
веток проверяется автоматически.

Cross-repo фича: сначала фиксируется контракт в репозитории-владельце, затем
клиентская реализация в отдельной ветке и отдельной задаче. Один commit или
worktree не покрывает несколько репозиториев.

### 4. Release PR в main

```text
base: main    <- обязательно
compare: develop
label: release (обязательно)
```

```sh
gh pr create --base main --head develop --label release \
  --title "release: <версия>" --body-file .github/PULL_REQUEST_TEMPLATE/release.md
```

Дождаться зелёного `Release Gate`, затем merge.

### 5. Теги и dispatch

Один и тот же тег `release-<version>` ставится в оба release-producing
репозитория:

- `min-null/minchat-backend`
- `min-null/minchat-frontend-web`

Backend tag workflow — **canonical release coordinator**: он проверяет tag policy
и то, что указанные коммиты лежат в `main`, затем шлёт `repository_dispatch`
`release` в `minchat-ops`. Ops принимает только совпадающую пару `release-*`
refs; отсутствие тега в одном из репозиториев даёт явную ошибку checkout, а не
молчаливый откат на `main`.

### 6. Деплой и откат

`minchat-ops` собирает и выкатывает релиз целиком. Продакшн всегда digest-pinned.
После деплоя — smoke: публичное здоровье, auth, realtime, runtime metadata.
Текущая пара образов записывается в release BOM; откат читает предыдущий BOM
целиком.

Dev-выпуск запускается вручную на ops `develop` с `backend_ref=develop` и
`frontend_ref=develop` и деплоит только dev.

Канон: [minchat-ops/docs/release-process.md](https://github.com/min-null/minchat-ops/blob/main/docs/release-process.md),
[minchat-ops/docs/rollback.md](https://github.com/min-null/minchat-ops/blob/main/docs/rollback.md).

### 7. Защита ветки develop

`develop` удаляли четыре раза за сентябрь 2026, каждым разом сразу после merge
release PR в `main`. Наблюдаемый вред один: ветки нет, Branch Policy отклоняет
feature PR, и задачу приходится направлять в другую ветку.

Заблокировать удаление на Free-плане нельзя — branch protection и rulesets
возвращают `HTTP 403 Upgrade to GitHub Pro`, а `delete_branch_on_merge` уже
выключен. Поэтому в каждом code/ops репозитории лежит одинаковый
`develop-guard.yml`:

```yaml
name: Develop Guard

on:
  push:
    branches: [main, develop]
  schedule:
    - cron: '17 4 * * *'
  workflow_dispatch:

permissions:
  contents: write
```

Workflow делает одно: если `refs/heads/develop` отсутствует, он создаёт его из
текущего `main` и печатает `::error`-annotation. Если ветка есть — сразу
выходит, ничего не меняя.

Триггеры и их границы:

- `push` в `main` ловит наблюдаемый случай — удаление сразу после release-мержа;
- `push` в `develop` ловит удаление в ходе интеграционной работы;
- `schedule` — ежедневная подстраховка, **но таймеры GitHub читают workflow только
  из ветки по умолчанию**, то есть ежедневная проверка включается лишь после
  промоута в `main`;
- `workflow_dispatch` — ручная проверка по требованию.

Workflow не падает: он восстанавливает ветку и поднимает annotation, иначе
отсутствие `develop` блокировало бы несвязанные merge. Ключ — собственный
`GITHUB_TOKEN` репозитория с `contents: write`, длинный-lived PAT уровня
организации не используется: токен на запись во все 11 репозиториев — это
лишняя поверхность, которой не место в секрете.

Образец: [development-kit/.github/workflows/develop-guard.yml](https://github.com/min-null/development-kit/blob/main/.github/workflows/develop-guard.yml).

## Параллельная работа

Git поддерживает не одну активную ветку, а сколько угодно — через worktree.
Эта модель — единственный способ вести несколько фич и фиксов одновременно
без потери чужих изменений.

### Базовые правила

- **Каждой задаче — свой worktree.** Никакой параллельной записи в один checkout.
  Если переключаешься между задачами в одной репе, значит нужен ещё один
  worktree, а не commit на ту же ветку.
- **Одна ветка = одна задача.** Объединять две фичи или два фикса в одну ветку
  запрещено. Каждый worktree пишет строго свою задачу.
- **Каждой работе соответствует таска.** Если у работы пока нет номера issue,
  он создаётся в `minchat-hq` до старта, и имя приводится к формату ниже.
- **Только main checkout пишет в `develop` и `main`.** Из worktree открывается
  PR, но merge и push в защищённые ветки — операция main checkout, чтобы
  submodule и CI-state не разъезжались.
- **Каждый worktree получает свежий setup.** `git submodule update --init
  --recursive` и репозиторный `Makefile`/`script` запускаются заново; чужой
  submodule-state не наследуется.
- **Integration owner назначается в parent issue в `minchat-hq`.** При
  конфликтующих изменениях одного файла в разных worktree порядок
  определяет integration owner.

### Именование

Ветка и папка worktree именуются одинаково. Никаких дополнительных префиксов,
разделителей, тегов или суффиксов в имени не допускается — имя ровно такое,
как ниже. Любые попытки добавить префикс вроде `codex/`, `agent/`, `tmp/` —
тот же шум, что и старая ветка с произвольным именем.

```text
issues-<номер>-<короткое-описание>
```

Примеры:

```text
issues-42-fix-call-rejection
issues-87-incoming-call-ringing
issues-103-add-workspace-tabs
```

Слаг — буквы, цифры и дефис, нижний регистр. Если у работы пока нет номера,
допустимо начать с короткого описания, но issue создаётся немедленно и ветка
переименовывается.

### Откуда это

- Команды `git worktree add`, submodule setup и submodule-границы — в
  [`development-kit/docs/repository-workflow.md`](https://github.com/min-null/development-kit/blob/main/docs/repository-workflow.md),
  раздел Worktrees.
- Сквозная фича с ролями и evidence — skill `feature-orchestration`
  (MIN Development Kit).
- При конфликте приоритетов между параллельными worktree — решение integration
  owner-а, зафиксированное в parent issue в `minchat-hq`.

## Релизный план

Живёт в `minchat-hq/roadmap/` и не дублируется в репозиториях.

- [roadmap/README.md](https://github.com/min-null/minchat-hq/blob/main/roadmap/README.md) — индекс активных документов
- [release-1.0.md](https://github.com/min-null/minchat-hq/blob/main/roadmap/release-1.0.md) — план стабилизации до `1.0.0`
- [release-bom.md](https://github.com/min-null/minchat-hq/blob/main/roadmap/release-bom.md) — manifest согласования backend/client/contracts
- [summer-cleanup-exit.md](https://github.com/min-null/minchat-hq/blob/main/roadmap/summer-cleanup-exit.md) — гейт входа в релиз
- [welcome-to-the-gaming.md](https://github.com/min-null/minchat-hq/blob/main/roadmap/welcome-to-the-gaming.md) — roadmap пивота

Исполняемые задачи релиза заводятся в Project и code/ops репозиториях, а не
живут в roadmap.

## Карта канонов

Процесс описан здесь. Всё остальное имеет своего владельца и **не копируется**
в этот документ.

| Тема | Владелец | Документ |
|---|---|---|
| Процесс: ветки, PR, release, deploy | org | этот документ |
| Карта репозиториев | `minchat-hq` | [docs/repositories.md](https://github.com/min-null/minchat-hq/blob/main/docs/repositories.md) |
| Куда заводить задачи, labels | `minchat-hq` | [docs/ownership.md](https://github.com/min-null/minchat-hq/blob/main/docs/ownership.md) |
| Product gate | `minchat-hq` | [docs/product-development-principles.md](https://github.com/min-null/minchat-hq/blob/main/docs/product-development-principles.md) |
| Релизный план | `minchat-hq` | [roadmap/](https://github.com/min-null/minchat-hq/tree/main/roadmap) |
| Release map и границы deploy | `minchat-hq` | [docs/release-map.md](https://github.com/min-null/minchat-hq/blob/main/docs/release-map.md) |
| Branch/release flow backend | `minchat-backend` | [docs/release-flow.md](https://github.com/min-null/minchat-backend/blob/main/docs/release-flow.md) |
| Архитектура и runbook'и backend | `minchat-backend` | [docs/README.md](https://github.com/min-null/minchat-backend/blob/main/docs/README.md) |
| Контракты REST/WS/UI/behavioral | `minchat-backend` | [shared/README.md](https://github.com/min-null/minchat-backend/blob/main/shared/README.md) |
| Submodules, worktrees, границы клиентов | `minchat-frontend` | [AGENTS.md](https://github.com/min-null/minchat-frontend/blob/main/AGENTS.md) |
| Оркестрация фичи, роли, evidence | `development-kit` | [docs/usage.md](https://github.com/min-null/development-kit/blob/main/docs/usage.md) |
| Работа с репозиториями в агенте | `development-kit` | [docs/repository-workflow.md](https://github.com/min-null/development-kit/blob/main/docs/repository-workflow.md) |
| Релизный процесс, BOM, rollback | `minchat-ops` | [docs/release-process.md](https://github.com/min-null/minchat-ops/blob/main/docs/release-process.md) |
| Окружения, secrets, quality gate | `minchat-ops` | [docs/](https://github.com/min-null/minchat-ops/tree/main/docs) |

## Проверки перед merge

- Направление PR соответствует разделу «Обязательные правила».
- Quality gate репозитория зелёный.
- Для backend — `Backend CI` зелёный, включая contract drift checks.
- Для релиза — зелёный `Release Gate` (направление веток, метка, полный quality gate).
- Проведённые проверки перечислены; непроведённые помечены `not_run` с причиной.
- Изменение workflow, compose, env-контракта или BOM сопровождается изменением
  документации в том же PR.

## Границы документации

- Этот документ описывает **процесс**, а не код и не окружения.
- Репозиторий добавляет данные и свои runbook'и, но не правила процесса.
- Новый шаг процесса сначала появляется здесь, потом на него ссылаются репозитории.
- Устаревшие правила удаляются здесь, а не молча расходятся по копиям в репах.
