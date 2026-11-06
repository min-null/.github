# Единый флоу разработки и релиза MinChat

Канонический документ организации `min-null`. Он описывает **процесс** целиком:
от идеи до продакшена и отката. Репозитории не владеют процессом и не могут его
расширять — они хранят код, контракты, окружения и собственные runbook'и.

Если правило в этом документе расходится с `AGENTS.md` или `RELEASE_FLOW.md`
любого репозитория — **прав этот документ**. Расхождение нужно исправить, а не
обойти.

## Переход MinChat на Drone

Для `minchat-ci`, `minchat-backend`, `minchat-frontend`, `minchat-frontend-web`
и `minchat-ops` CI/CD переносится с Jenkins на Drone на CI VPS в рамках
[minchat-hq#455](https://github.com/min-null/minchat-hq/issues/455).
Jenkins после cutover отключён и не используется как резервный исполнитель.
Веточная модель, release labels и ручной контроль сохраняются.

- GitHub отправляет `push`, `pull_request`, `issues`, `delete` в HTTPS webhook
  worker. Worker проверяет HMAC и сохраняет события. Обычные push, commit,
  merge и PR не запускают release build или deploy. Push в `develop` только
  ставит независимый запрос dev updater для отдельного `dev.min-chat.online`.
- В PR автоматически проверяется только `minchat/branch-policy`: направление
  веток, имя feature-ветки и release label. Release CI gate не требуется
  перед merge в develop или main. Код принимается до release-проверки; ошибки
  обнаруживаются при выпуске по тегу.
- Отдельный тег `release-<version>` в `minchat-backend` или
  `minchat-frontend-web` запускает проверки и подготовку кандидата только этого
  компонента. Тег указывает на merge commit принятого release PR
  `develop -> main` с меткой `release`; совпадение версий и второй тег не нужны.
  Повторные доставки события не создают повторную сборку, а перемещение уже
  принятого тега отклоняется.
- Кандидат содержит тег, SHA, digest образа, provenance и результаты проверок
  компонента. Неуспешные обязательные проверки блокируют кандидата и выкладку.
  Подготовка не меняет сайт и не требует актуального тега второго компонента.
  Drone управляет запуском, очередью, логами и результатом; команды и проверки
  принадлежат приложениям и Ops.
- Выкладка вручную выбирает backend-кандидат, web-кандидат или оба. Невыбранный
  компонент сохраняется по точному digest текущего BOM. Preview фиксирует пару
  digest, окружение и BOM; применение не пересобирает образы. Перед выкладкой
  Ops проверяет REST-контракт выбранной пары OpenAPI. Успех переиспользуется
  только для тех же digest и версии проверки. Явный пропуск требует причины и
  подтверждения точной пары и остаётся `skipped`, в том числе после ошибки.
- REST-проверка не доказывает совместимость realtime, звонков и всех сценариев.
  Пропуск не отключает собственные проверки компонентов, provenance, backup,
  миграции и smoke. Под блокировкой Ops перед применением preview повторно
  сверяется BOM; при его изменении нужен новый preview и результат проверки.
- Ручная цель текущего web/backend выпуска — основной `min-chat.online` на
  `82.147.67.254`, как в принятом владельцем выпуске 1.0.37 (HQ #281).
  Его техническое имя Ops пока `dev`; это не отдельный `dev.min-chat.online`.
  При выпуске сохраняются существующие данные, volumes и топология. Новый
  параллельный prod stack и расписание production этим не включаются.
- Перед изменением сайта повторно проверяются опубликованные digest и SHA,
  сохраняется проверенный дамп БД; затем Ops выполняет миграции, deploy,
  smoke и BOM. Предыдущая пара сохраняется для отката. Успех build-only не
  означает deploy, успех одного окружения не означает выпуск обоих.
- После ошибки deploy повторяют только deploy того же сохранённого кандидата.
  Ошибка кода требует нового кандидата с полными проверками. После SUCCESS
  проверяют пользовательскую сессию, realtime и фактические версии; результаты
  фиксируют в HQ issue. Команды и срок хранения кандидата — в
  [verified-release](https://github.com/min-null/minchat-ci/blob/develop/docs/verified-release.md).
- Эта выбранная пользователем схема заменяет требования release CI gates
  до merge для пяти перечисленных репозиториев. Общие указания о PR quality
  gates ниже продолжают действовать для остальных репозиториев организации.
- Android build сохранён отдельным manual-only Drone pipeline. Push, PR, tags,
  расписания и web/backend releases его не запускают; подписанная публикация
  требует отдельного явного выбора. Сквозная Android сборка, подпись и
  публикация имеют статус `not_run` и не блокируют cutover. Flutter/Dart команды
  запускаются только на CI VPS, не на компьютере пользователя.
- Еженедельный production-выпуск будет использовать отдельные
  `release-<version>` кандидаты из `main`, полный обязательный CI, отдельный
  production runtime, smoke, BOM и rollback. Сейчас этот отдельный маршрут не готов и
  не включён: сначала требуется изолировать production от dev и проверить
  runtime, credentials, gateway и единственный координатор. Никаких расписаний
  или автоматических production jobs пока нет.
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

Для перечисленных репозиториев успешный `minchat/branch-policy` подтверждает
release PR policy. Полный component CI выполняется при подготовке кандидата;
отсутствующий hosted запуск не подменяют фиктивным зелёным check.

## Отдельная develop-среда на CI VPS

В рамках minchat-hq#149 появляется отдельная среда `dev.min-chat.online` на CI VPS.
Подписанные push webhook для `develop` backend, web и общего frontend ставят
запрос только на обновление этой среды. Обычные изменения исходников подхватываются
без пересборки образов; зависимости/config/migrations обрабатываются явно Ops.
Web develop выбирается независимо от parent gitlink, фактические SHA сохраняются.
Это исключение из правила «обычный push ничего не запускает» относится только к
dev updater: полный release CI и основной сайт запускаются независимо по
component release-тегам и ручному Ops preview. Старое техническое окружение
основного сайта не переименовывается этой задачей. Dev использует собственные
данные и credentials.
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
   release PR из коммита в `main`; backend и web ставятся независимо и могут
   иметь разные версии.

5. **Тег запускает только настроенный релизный маршрут.** Каждый тег запускает
   Drone-кандидат своего компонента. Ручной Ops preview выбирает компоненты и
   целевое окружение. Push в `develop`, merge feature PR и ручная сборка образа
   сами по себе не запускают deploy. Отдельный еженедельный
   production-маршрут пока не включён.

6. **Красный gate — не причина его обходить.** Сначала исправь направление PR или
   вернись в integration flow. Обязательные component checks, provenance,
   compatibility, backup, migrations и smoke блокируют применение при ошибке.

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
  -> короткая issue в minchat-hq (обязательный общий трекер; одной строки достаточно)
  -> результат + границы; детали уточняются по мере работы
  -> ветка feature/fix от develop
  -> PR в develop  +  quality gate репозитория
  -> merge в develop
  -> release PR develop -> main  (метка release, branch-policy)
  -> merge в main
  -> независимые release-теги backend и web из main
  -> Drone: проверки компонентов + digest-pinned кандидаты
  -> Ops: preview выбранной пары + REST compatibility check
  -> ручное применение выбранных компонентов без пересборки
  -> post-deploy smoke + release BOM
  -> (при сбое) rollback по предыдущему BOM

Production — целевой еженедельный маршрут после отдельной готовности и
приёмки runtime. Сейчас production deploy не настроен.
```

### 1. Запрос и scope

Каждая задача получает issue в `minchat-hq`; сначала проверь, нет ли дубля.
Для небольшой правки хватит заголовка и одной строки с ожидаемым результатом.
Для крупной или cross-repo работы коротко добавь границы, зависимости и способ
проверки. Organization Project можно использовать как обзор очереди, но он не
нужен для создания или начала задачи.

Cross-repo инициатива — один parent issue в `minchat-hq` с чеклистом PR и
явно указанным integration/release path для каждого затронутого репозитория.

Канон: [minchat-hq/docs/ownership.md](https://github.com/min-null/minchat-hq/blob/main/docs/ownership.md),
[minchat-hq/docs/project-management.md](https://github.com/min-null/minchat-hq/blob/main/docs/project-management.md).

### 2. Scope и решения

Обычные продуктовые и технические детали решает исполнитель в рамках запроса.
Не добавляй большие соседние возможности, платформы или настройки без связи с
целью. Если выяснилось, что меняется цель, приватность, безопасность,
совместимость или другой труднообратимый выбор, опиши последствия и спроси
владельца только об этом решении. Дизайн, контракты и ADR создаются по
необходимости и не являются обязательными gate перед стартом.

Короткий процесс: [minchat-hq/docs/process/feature-pipeline/README.md](https://github.com/min-null/minchat-hq/blob/main/docs/process/feature-pipeline/README.md).

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

Cross-repo фича: обновляй shared contract там, где меняется API или поведение.
Для каждого затронутого репозитория нужен свой PR и checkout, но один HQ issue
может связывать их все. Порядок работы определяется фактическими зависимостями;
не создавай child issues, если достаточно общего issue с коротким чеклистом.

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

Дождаться зелёного `minchat/branch-policy`, затем merge.

### 5. Теги и dispatch

Теги `release-<version>` ставятся независимо в release-producing репозитории:

- `min-null/minchat-backend`
- `min-null/minchat-frontend-web`

Webhook worker сохраняет каждый backend/web тег независимо.
Component dispatcher проверяет происхождение и передаёт точные repository, tag
и SHA в Drone. Неоднозначный ответ API автоматически не отправляется повторно:
оператор сначала сверяет его с Drone. Подготовка кандидата не выкладывает сайт;
Ops preview и его применение выполняются отдельными ручными командами.

Старые Actions/Ops production сценарии не являются согласованным weekly
координатором для выбранной изолированной production-среды. Не запускать
`minchat-ops/scripts/release.sh prod release-<version>` для текущего сайта:
до production acceptance нет подтверждённого production runtime и целевого
gateway. Пара release-тегов сама по себе не означает production deploy.
Команды dev и ручного обслуживания описаны в CI/Ops runbook; их статус
нужно сверять перед каждым запуском.

### 6. Деплой и откат

`minchat-ops` владеет preview, compatibility, backup, migrations, deploy, BOM,
smoke и rollback. Выкладка вручную выбирает backend, web или оба компонента;
невыбранный digest берётся из текущего BOM. После deploy выполняется smoke:
публичное здоровье, авторизованная сессия, realtime и фактические версии.
Откат читает предыдущий BOM. Push updater для отдельной dev-среды остаётся
независимым от release и deploy маршрута.

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
| Product guidance | `minchat-hq` | [docs/product-development-principles.md](https://github.com/min-null/minchat-hq/blob/main/docs/product-development-principles.md) |
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

## Чистая консоль и диагностика ошибок

**Штатные сценарии проходят без необработанных ошибок и ложных error-событий.
Неожиданные сбои остаются наблюдаемыми и расследуются.** Это критерий качества
затронутого сценария, а не обещание отсутствия любых красных строк браузера.

- Открытие и смена чатов, переход между вкладками, отмена запроса при навигации,
  временная потеря сети и успешное переподключение обрабатываются без
  `console.error`, необработанных исключений и `unhandledrejection`.
  Ожидаемый отказ, например ошибка ввода, также имеет явную обработку.
  Повтор, таймер или отмена сами по себе не означают ошибку приложения.
- Если действие пользователя не выполнено, интерфейс объясняет результат и
  доступный способ восстановления. Фоновая проверка или повтор не должны
  создавать технические сообщения и анимации возле каждого объекта.
  Состояние связи показывается в одном подходящем месте, когда влияет на работу;
  неизвестные данные не выдаются за подтверждённый результат.
- Неожиданный сбой и нарушение логики фиксируются как ошибки с контекстом
  операции, достаточным для расследования, без токенов, личной переписки и
  других чувствительных данных. Одна причина не должна порождать одинаковые
  записи на каждом слое или бесконечный поток ошибок при повторах.
- Нельзя добиваться чистой консоли отключением логирования, пустым `catch`,
  глобальным подавлением ошибок или механическим переводом всех ошибок в
  `warn`/`debug`. Ожидаемые события классифицируются по смыслу; реальные сбои
  сохраняют диагностику через существующие средства наблюдения.
- Сообщения, которые браузер сам выводит при неудачном сетевом запросе или
  WebSocket-соединении, учитываются отдельно от логов приложения. Не скрывай их:
  проверь восстановление и отсутствие каскада запросов. Сам источник сообщения
  не делает его безвредным — ошибка URL, CORS, сертификата или сервера требует
  разбора причины.

Для изменения клиентского поведения проверь основной затронутый сценарий и
относящиеся к нему отмену, отказ и восстановление. В PR укажи проверенные
сценарии, ошибки консоли/необработанные сбои и результат восстановления;
непроведённое отмечай `not_run` с причиной. Проверка может быть ручной или
автоматической; регрессия, которую можно надёжно воспроизвести, получает
подходящий тест. Это не требует полного аудита приложения в каждом PR.

Новые необработанные ошибки и ложные error-события в затронутом сценарии
исправляются до merge. Найденные старые сбои вне scope получают отдельную HQ
issue со ссылкой в PR; не выдавай такую проверку за «ошибок нет».

## Проверки перед merge

- Направление PR соответствует разделу «Обязательные правила».
- Quality gate репозитория зелёный.
- Для пяти перенесённых репозиториев release PR требует зелёный
  `minchat/branch-policy`; обязательные component checks выполняются до выдачи
  кандидата и блокируют apply при ошибке.
- Проведённые проверки перечислены; непроведённые помечены `not_run` с причиной.
- Для клиентского поведения выполнена [проверка консоли и восстановления](#чистая-консоль-и-диагностика-ошибок).
- Изменение workflow, compose, env-контракта или BOM сопровождается изменением
  документации в том же PR.

## Границы документации

- Этот документ описывает **процесс**, а не код и не окружения.
- Репозиторий добавляет данные и свои runbook'и, но не правила процесса.
- Новый шаг процесса сначала появляется здесь, потом на него ссылаются репозитории.
- Устаревшие правила удаляются здесь, а не молча расходятся по копиям в репах.
