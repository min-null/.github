# Расход GitHub Actions

Канон процесса: [min-null/.github/docs/development-flow.md](https://github.com/min-null/.github/blob/develop/docs/development-flow.md#расход-github-actions).

Issue Lifecycle Bot обрабатывает успешный merge по событию; закрытие PR без merge пропускает runner. Подстраховка: понедельник 05:17 UTC, только этот репозиторий. Общая реализация в `.github` не обходит остальные приватные репозитории токеном caller. Повторные комментарии пропускаются; окно восстановления — восемь дней.

Develop Guard проверяет `main` push, удаление `develop` и ручной запуск. Резервная проверка: понедельник 04:17 UTC. Удаление других веток пропускает runner. Job восстанавливает отсутствующую `develop` из `main`.

## Включение после приостановки

2026-10-04 Issue Lifecycle Bot временно выключен в десяти приватных репозиториях для сохранения остатка квоты. На время паузы метки и комментарии после merge обновляются вручную.

Сначала промоутить общую реализацию `.github` в `main` через обычный release PR, затем включить callers. Общая реализация фильтрует старый hourly cron до выделения runner: обработка merge и ручной recovery работают даже до собственного release caller. Еженедельный fallback начнёт работать после промоута wrapper в его `main`.

```sh
gh workflow enable issue-lifecycle-bot.yml -R min-null/.github
gh workflow run issue-lifecycle-bot.yml -R min-null/.github --ref main
```

Ручной запуск восстановит статусы merge за последние восемь дней. Расписание читается из `main`; hourly cron старого caller будет пропущен общим workflow без runner. Публикация тегов и production deploy для этого изменения не нужны.

## Проверка изменения

Локально: actionlint 1.7.12 для изменённых workflow, ShellCheck 0.11.0 для их shell-блоков, YAML parsing — passed. Для общей реализации проверены mock-сценарии: merge по событию, обход только caller-репозитория, пропуск повторного комментария, однократная пагинация stale issues, восстановление отсутствующей develop. Branch Lint проверен на допустимой и недопустимой ветке; исправлены YAML-отступы heredoc, из-за которых старый workflow не разбирался.

Полные runtime/quality проверки выполняются в PR CI; локально не запускались, поскольку runtime не менялся.
