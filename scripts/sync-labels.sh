#!/usr/bin/env bash
# Создаёт/обновляет labels в указанном репозитории по словарю docs/labels.md.
# Использование: ./scripts/sync-labels.sh min-null/<repo>
#
# - Идемпотентно: повторный запуск не падает на существующих labels.
# - Не удаляет чужие labels (если они не из словаря — оставляет).
# - Цвета и описания подтягиваются на актуальные.

set -euo pipefail

if [ $# -ne 1 ]; then
  echo "Usage: $0 min-null/<repo>" >&2
  exit 64
fi

REPO="$1"

# ---- Type ----
gh label create "type:feature" --color "0E8A16" --description "Новая функциональность" --repo "$REPO" || true
gh label create "type:bug"      --color "d73a4a" --description "Bug"                              --repo "$REPO" || true
gh label create "type:chore"    --color "fbca04" --description "Техдолг и обслуживание"           --repo "$REPO" || true
gh label create "type:research" --color "d4c5f9" --description "Исследование, spike, discovery"   --repo "$REPO" || true
gh label create "type:security" --color "b60205" --description "Безопасность"                    --repo "$REPO" || true

# ---- Area ----
gh label create "area:backend"   --color "5319e7" --description "Backend, REST/WS, БД"           --repo "$REPO" || true
gh label create "area:contracts" --color "8a2be2" --description "Shared contracts, schemas"      --repo "$REPO" || true
gh label create "area:web"       --color "c5def5" --description "Web-клиент"                     --repo "$REPO" || true
gh label create "area:desktop"   --color "bfd4f2" --description "Desktop-клиент"                 --repo "$REPO" || true
gh label create "area:android"   --color "3ddc84" --description "Android-клиент"                 --repo "$REPO" || true
gh label create "area:flutter"   --color "02569b" --description "Flutter-клиент"                 --repo "$REPO" || true
gh label create "area:ops"       --color "0e8a16" --description "Ops, deploy, environments"     --repo "$REPO" || true
gh label create "area:hq"        --color "f9d0c4" --description "Координация и мета-документация" --repo "$REPO" || true

# ---- Coordination ----
gh label create "coordination:cross-repo"     --color "7057ff" --description "Задача затрагивает несколько репозиториев" --repo "$REPO" || true
gh label create "coordination:blocked"        --color "b60205" --description "Заблокировано другой задачей"             --repo "$REPO" || true
gh label create "coordination:needs-decision" --color "fbc740" --description "Нужно продуктовое или техническое решение" --repo "$REPO" || true

# ---- Risk ----
gh label create "risk:security"  --color "b60205" --description "Security impact"           --repo "$REPO" || true
gh label create "risk:privacy"   --color "e11d48" --description "Privacy impact"            --repo "$REPO" || true
gh label create "risk:migration" --color "ff8c00" --description "Migration risk"            --repo "$REPO" || true
gh label create "risk:release"   --color "b60205" --description "Release risk"              --repo "$REPO" || true

echo "Labels in $REPO are in sync with docs/labels.md."
