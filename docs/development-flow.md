# Единый флоу разработки и релиза MinChat

Канонический документ организации `min-null`. Он описывает **процесс** целиком:
от идеи до продакшена и отката. Репозитории не владеют процессом и не могут его
расширять — они хранят код, контракты, окружения и собственные runbook'и.

Если правило в этом документе расходится с `AGENTS.md` или `RELEASE_FLOW.md`
любого репозитория — **прав этот документ**. Расхождение нужно исправить, а не
обойти.

## Переход MinChat на Jenkins

Для `minchat-ci`, `minchat-backend`, `minchat-frontend`, `minchat-frontend-web`
и `minchat-ops` CI/CD переносится на VPS Jenkins в рамках
[minchat-hq#142](https://github.com/min-null/minchat-hq/issues/142).
После проверенного cutover действуют правила ниже; упоминания Actions в
остальном документе описывают прежнюю реализацию и остальные репозитории.
Веточная модель, release labels, согласованные теги и ручной контроль сохраняются.

- GitHub отправляет `push`, `pull_request`, `issues`, `delete` в HTTPS webhook
  worker. Worker проверяет HMAC и сохраняет события. Обычные push, commit,
  merge и PR не запускают Jenkins quality/security checks или deploy.
- В PR автоматически проверяется только `minchat/branch-policy`: направление
  веток, имя feature-ветки и release label. Jenkins PR gate больше не требуется
  перед merge в develop или main. Код принимается до CI-проверки; ошибки
  обнаруживаются при выпуске по тегу.
- Единственный обычный запуск CI/CD — пара одинаковых `release-<version>` тегов
  в `minchat-backend` и `minchat-frontend-web`. Теги указывают на merge commits
  release PR `develop -> main` с меткой `release`. Первый тег ждёт второй;
  повторные webhook deliveries не создают повторный выпуск.
- Когда пара готова, Jenkins проверяет происхождение тегов и выполняет полный
  backend/client/security/Ops CI, затем собирает digest-pinned образы и
  поручает Ops deploy, smoke и BOM в текущий dev-контур. Вручную заданный
  `SKIP_TESTS=true` пропускает эти проверки, но не блокирует deploy; Jenkins
  и панель явно помечают такой запуск «проверки пропущены». Его SUCCESS не
  подтверждает качество или безопасность.
- Jenkins не выпускает в production. Изолированная production-среда и её
  координатор ещё не готовы; еженедельный production-релиз пока не настроен.
  До отдельного acceptance нельзя считать основной сайт production-целью или
  использовать старый маршрут как замену.
- Вручную повторить неудачный выпуск можно только с существующей парой
  release-тегов; пустой `RELEASE_TAG` и выпуск из develop запрещены.
- Эта выбранная пользователем схема заменяет требования quality/Jenkins gates
  до merge для пяти перечисленных репозиториев. Общие указания о PR quality
  gates ниже продолжают действовать для остальных репозиториев организации.
- Flutter tests и APK отложены пользователем для завершения миграции текущего
  сайта. Они имеют статус `not_run` и не входят в текущий frontend PR gate
  или dev-release. При последующем включении Flutter/Dart разрешены только
  на CI VPS, локальный запуск на компьютере пользователя запрещён.
- Целевой еженедельный production-выпуск будет использовать парные
  `release-<version>` теги из `main`, полный обязательный CI, отдельный
  production runtime, smoke, BOM и rollback. Сейчас этот маршрут не готов и
  не включён: сначала требуется изолировать production от dev и проверить
  runtime, credentials, gateway и единственный координатор. Никаких расписаний
  или Jenkins production jobs пока нет.
- Webhook worker заменяет branch lint, develop guard и issue lifecycle для
  перенесённых репозиториев. Он имеет права только на выбранные репозитории.
  HQ task issue закрывается по явной closing reference на `min-null/minchat-hq#N`
  после merge в main;
  cross-repo HQ parent закрывает integration owner. Статусные метки и approval
  labels бот не выдумывает: `readiness-gate` только проверяет обоснованность
  `status:pickable` и снимает её, если задача не готова.
- Weekly reconciliation выполняется на CI VPS по понедельникам 05:17 UTC,
  независимо от default branch GitHub. Сбой виден в health и журнале.

Команды, credentials, recovery и ограничения среды принадлежат
[minchat-ci runbook](https://github.com/min-null/minchat-ci/blob/develop/docs/setup.md)
и [Ops runbook](https://github.com/min-null/minchat-ops/blob/develop/docs/release-process.md).

## Отдельная develop-среда на CI VPS

В рамках minchat-hq#149 появляется отдельная среда `dev.min-chat.online` на CI VPS.
Подписанные push webhook для `develop` backend, web и общего frontend ставят
запрос только на обновление этой среды. Обычные изменения исходников подхватываются
без пересборки образов; зависимости/config/migrations обрабатываются явно Ops.
Web develop выбирается независимо от parent gitlink, фактические SHA сохраняются.
Это исключение из правила «обычный push ничего не запускает» относится только к
dev updater: полный release CI и основной сайт по-прежнему запускаются по паре
согласованных release-тегов. Старое техническое окружение основного сайта не
переименовывается этой задачей. Dev использует собственные данные и credentials.
Dev reload не гарантирует непрерывность звонка и не заменяет release smoke.

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

5. **Тег запускает только настроенный релизный маршрут.** Сейчас пара тегов
   запускает Jenkins выпуск в dev. Push в `develop`, merge feature PR и ручная
   сборка образа не запускают production deploy. Отдельный еженедельный
   production-маршрут пока не включён.

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
  -> issue в minchat-hq, если нужны история, обсуждение или координация
  -> product gate (для новой функциональности)
  -> ветка feature/fix от develop
  -> PR в develop  +  quality gate репозитория
  -> merge в develop
  -> release PR develop -> main  (метка release, Release Gate)
  -> merge в main
  -> тег release-<version> в backend и web main
  -> Jenkins: проверка пары + полный CI
  -> сборка digest-pinned пары образов
  -> deploy текущего настроенного Jenkins-контура (dev)
  -> post-deploy smoke + release BOM
  -> (при сбое) rollback по предыдущему BOM

Production — целевой еженедельный маршрут после отдельной готовности и
приёмки runtime. Сейчас production deploy не настроен.
```

### 1. Идея и задача

Новая идея сначала становится item в organization Project `MinChat`. Если нужны
обсуждение, история или ссылки — issue создаётся в `min-null/minchat-hq`.

**Все MinChat task issues живут только в `min-null/minchat-hq`.** Это включает
баги одного code/ops репозитория, технические задачи и child issues. Code/ops
репозитории хранят код, PR и runbook'и, но не task backlogs. Исключение — только
прямое указание Линара создать issue в другом репозитории.

Перед созданием issue агент обязан найти возможную существующую задачу в HQ и
проверить, что `repository_full_name` назначения — ровно `min-null/minchat-hq`.
Текущий checkout или репозиторий реализации не меняют назначение. Если у агента
нет доступа к HQ, он сообщает об этом и не создаёт issue в code/ops репозитории.
Если task issue уже ошибочно появилась вне HQ, агент находит или создаёт её HQ
соответствие, добавляет ссылки в обе стороны и закрывает repo-local issue как
duplicate.

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

Для текущего Jenkins маршрута webhook dispatcher ждёт одинаковые
`release-<version>` теги backend и web, проверяет их merge commits в `main`
и передаёт пару в `minchat-release/dev-release`. Jenkins выполняет CI и
деплоит только в dev. При ручном `SKIP_TESTS=true` проверки пропускаются и
это состояние остаётся видимым в истории.

Старые Actions/Ops production сценарии не являются согласованным weekly
координатором для выбранной изолированной production-среды. Не запускать
`minchat-ops/scripts/release.sh prod release-<version>` для текущего сайта:
до production acceptance нет подтверждённого production runtime и целевого
gateway. Пара release-тегов сама по себе не означает production deploy.
Команды dev и ручного обслуживания описаны в Jenkins/Ops runbook; их статус
нужно сверять перед каждым запуском.

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
    branches: [main]
  delete:
  schedule:
    - cron: '17 4 * * 1'
  workflow_dispatch:

permissions:
  contents: write
```

Workflow делает одно: если `refs/heads/develop` отсутствует, он создаёт его из
текущего `main` и печатает `::error`-annotation. Если ветка есть — сразу
выходит, ничего не меняя.

Триггеры и их границы:

- `push` в `main` ловит наблюдаемый случай — удаление сразу после release-мержа;
- `delete` запускает job только при удалении ветки `develop`; удаления feature-веток пропускаются до выделения runner;
- `schedule` — еженедельная подстраховка, **но таймеры GitHub читают workflow только
  из ветки по умолчанию**, то есть еженедельная проверка включается лишь после
  промоута в `main`;
- `workflow_dispatch` — ручная проверка по требованию.

Workflow не падает: он восстанавливает ветку и поднимает annotation, иначе
отсутствие `develop` блокировало бы несвязанные merge. Ключ — собственный
`GITHUB_TOKEN` репозитория с `contents: write`, длинный-lived PAT уровня
организации не используется: токен на запись во все 11 репозиториев — это
лишняя поверхность, которой не место в секрете.

Образец: [development-kit/.github/workflows/develop-guard.yml](https://github.com/min-null/development-kit/blob/main/.github/workflows/develop-guard.yml).

## Расход GitHub Actions

- Issue Lifecycle Bot обрабатывает merge по событию в своём репозитории. Резервный обход выполняется раз в неделю и охватывает только этот репозиторий; токен на всю организацию не требуется. Обход смотрит последние восемь дней и не повторяет уже опубликованные комментарии.
- Develop Guard сохраняет `push` в `main`, удаление `develop`, ручной запуск и еженедельную страховку. Обычный push в `develop` не выделяет отдельный runner для проверки наличия этой же ветки.
- CI и security одного PR отменяют устаревший прогон после нового коммита. Ручные проверки и release-проверки не отменяются другим PR; деплой не включается в такую группу.
- Quality gate выполняется в PR и после push в `main`. Повтор на push в `develop` не требуется: приёмка изменений в `develop` по-прежнему требует зелёного PR gate.
- Backend pytest в CI использует два изолированных worker-процесса на одном runner, завершает прогон при первом сбое и печатает медленные тесты. При успешном прогоне выполняется полный набор; локально для диагностики можно запускать полный набор без `-x`.
- Служебные workflow не заменяют quality/security/release gates. Расписания читаются из default branch; изменение в `develop` ещё не обновляет расписание `main`.
- Общий lifecycle workflow принимает только weekly cron `17 5 * * 1`. Старый hourly cron caller-репозитория пропускает все job до выделения runner. После обновления общей реализации в `.github/main` private callers можно включить даже до собственного release: merge-события и ручной recovery работают, hourly не расходует минуты; weekly fallback появится после промоута wrapper в `main`.

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

**Формат enforce-ится автоматически** workflow `branch-lint.yml`: имя вне
формата блокирует merge. Release PR `develop → main` и интеграционные
ветки `develop`/`main` линт пропускает.

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
