#!/usr/bin/env bash
# Readiness of an issue for `status:pickable`.
#
# Deliberately jq-free and clock-free: it is sourced by the lifecycle workflow and
# by scripts/test-readiness.sh, and a readiness rule that only runs in one of them
# is a readiness rule nobody tests.
#
# Rule (minchat-hq/docs/process/feature-pipeline/rules.md):
#
#   ready = has description section
#       AND has acceptance section
#       AND has type:* label
#       AND has area:* label
#       AND has priority:* label
#       AND NOT coordination:blocked
#
# There is deliberately no condition about `needs:*` or `*:approved`. Those used to
# require a person to approve before work could start, which is exactly the
# human-approval gate removed on 2026-10-17. A well-formed issue with an open
# needs:design and no design:approved is ready. Keeping them as navigation only is
# the point.
#
# Usage:
#   readiness_evaluate "<body>" "<space separated labels>" ["<title>"]
#
# Sets:
#   READINESS_REASONS  newline separated missing/ blocking reasons ("" when ready)
#   READINESS_STATUS    ready | not_ready

readiness_has_label() {
  # $1 = space separated labels, $2 = exact label, or a prefix ending in ':'
  local labels="$1" needle="$2" label rest
  for label in $labels; do
    [ -n "$label" ] || continue
    case "$needle" in
      *:)
        # Prefix match, but the suffix must exist: a bare "type:" is not a label
        # anyone can set and must not satisfy the requirement.
        rest="${label#"$needle"}"
        if [ "$rest" != "$label" ] && [ -n "$rest" ]; then
          return 0
        fi
        ;;
      *)
        if [ "$label" = "$needle" ]; then
          return 0
        fi
        ;;
    esac
  done
  return 1
}

readiness_has_section() {
  # $1 = issue body, $2.. = accepted spellings of a section header (shell globs).
  #
  # Matching happens in bash, not in grep, on purpose. Every alternative was a real,
  # silent failure of this rule on a runner with no locale set:
  #   * a multibyte bracket class like [её] is applied byte-wise in the C locale, so
  #     it never matches the real letter - "## Критерии приёмки" was reported as
  #     "no acceptance criteria";
  #   * `printf | grep -q` under `set -o pipefail` turns grep's early exit into a
  #     failed pipeline, so a match could silently become a miss;
  #   * ${var,,} mangles non-ASCII characters when no locale is installed, turning
  #     a Cyrillic heading into garbage;
  #   * the usual `${v#"${v%%[![:space:]]*}"}` trim removes the first character
  #     when the value has no leading whitespace, which every "## Heading" has.
  # Bash's own regex plus globs avoid all four, and need no subprocess.
  local body="$1"
  shift
  local line heading pattern restore=0
  shopt -q nocasematch && restore=1
  # ASCII-only case folding. Cyrillic is compared with the exact spelling used in
  # the issue templates, which is also what the rule documents.
  shopt -s nocasematch
  while IFS= read -r line; do
    [[ "$line" =~ ^[[:space:]]*#+[[:space:]]*(.*[^[:space:]])[[:space:]]*$ ]] || continue
    heading="${BASH_REMATCH[1]}"
    for pattern in "$@"; do
      # shellcheck disable=SC2053  # glob is intended, not a literal compare
      if [[ "$heading" == $pattern ]]; then
        [ "$restore" -eq 1 ] || shopt -u nocasematch
        return 0
      fi
    done
  done <<< "$body"
  [ "$restore" -eq 1 ] || shopt -u nocasematch
  return 1
}

readiness_has_checklist() {
  # A task list is an acceptance section in its own right. The box is followed by
  # whitespace or end of line, because a real checklist item has text after it:
  # "  - [ ] переключатель виден".
  local line
  while IFS= read -r line; do
    [[ "$line" =~ ^[[:space:]]*[-*][[:space:]]*\[[^]]*\]([[:space:]]|$) ]] && return 0
  done <<< "$1"
  return 1
}

readiness_evaluate() {
  # $1 = issue body, $2 = space separated labels, $3 = issue title
  local body="${1:-}"
  local labels="${2:-}"
  local title="${3:-}"

  # A body that arrived from a Windows checkout or editor carries CR. Strip it once
  # here so the rule cannot depend on how the file happened to be saved.
  body="${body//$'\r'/}"

  READINESS_REASONS=""
  local reasons=""

  # Header spellings are globs. ASCII is matched case-insensitively; Cyrillic is
  # compared literally, because a runner with no locale cannot fold Cyrillic case
  # without corrupting the string. Both capitalisations are therefore listed for the
  # Russian headings. "при*мки" covers приёмки and приемки.
  if ! readiness_has_section "$body" \
      'описание' 'Описание' \
      'что нужно сделать' 'Что нужно сделать' \
      'что надо сделать' 'Что надо сделать' \
      'context' 'tl;dr' 'summary'; then
    reasons="${reasons}Нет секции с описанием\n"
  fi

  if ! readiness_has_section "$body" \
      'acceptance criteria' 'Критерии при*мки' 'критерии при*мки' 'acceptance' 'done when' \
      && ! readiness_has_checklist "$body"; then
    reasons="${reasons}Нет acceptance criteria в body\n"
  fi

  readiness_has_label "$labels" 'type:' || reasons="${reasons}Нет метки type:*\n"
  readiness_has_label "$labels" 'area:' || reasons="${reasons}Нет метки area:*\n"
  readiness_has_label "$labels" 'priority:' || reasons="${reasons}Нет метки priority:*\n"

  if readiness_has_label "$labels" 'coordination:blocked'; then
    reasons="${reasons}Стоит coordination:blocked\n"
  fi

  # An epic is a container, not a work item. It has no acceptance criteria of its own,
  # so it must never enter status:pickable and deadlock the board.
  if readiness_is_epic "$title" "$labels"; then
    reasons="${reasons}Это эпик-контейнер, а не задача\n"
  fi

  READINESS_REASONS="$(printf '%b' "$reasons" | sed '/^$/d')"
  if [ -n "$READINESS_REASONS" ]; then
    READINESS_STATUS="not_ready"
  else
    READINESS_STATUS="ready"
  fi
}

readiness_is_epic() {
  local title="${1:-}" labels="${2:-}"
  readiness_has_label "$labels" 'area:hq' || return 1
  if readiness_has_label "$labels" 'type:feature' || readiness_has_label "$labels" 'type:research'; then
    return 0
  fi
  case "$title" in
    \[Epic\]* | '[Epic]'*) return 0 ;;
  esac
  return 1
}

readiness_comment() {
  # $1 = issue number, $2 = READINESS_REASONS. Empty reasons produce no comment at
  # all: a ready issue must never get a rejection comment.
  local number="$1" reasons="$2"
  [ -n "$reasons" ] || return 0
  printf '\U0001F534 Не могу оставить `status:pickable` на #%s: задача не готова к работе.\n\n' "$number"
  printf 'Не хватает:\n'
  while IFS= read -r reason; do
    [ -n "$reason" ] || continue
    printf -- '- \274\157 %s\n' "$reason"
  done <<EOF
$reasons
EOF
  printf '\nЧто сделать:\n'
  while IFS= read -r reason; do
    [ -n "$reason" ] || continue
    case "$reason" in
      'Нет секции с описанием')         printf -- '- Дописать в body секцию `## Описание`.\n' ;;
      'Нет acceptance criteria в body') printf -- '- Дописать чеклист `- [ ]` или секцию `## Acceptance criteria`.\n' ;;
      'Нет метки type:*')               printf -- '- Проставить метку `type:*`.\n' ;;
      'Нет метки area:*')               printf -- '- Проставить метку `area:*`.\n' ;;
      'Нет метки priority:*')           printf -- '- Проставить метку `priority:*`.\n' ;;
      'Стоит coordination:blocked')     printf -- '- Снять `coordination:blocked`: это настоящая блокировка, снимает тот, кто её поставил.\n' ;;
      'Это эпик-контейнер, а не задача') printf -- '- Эпик не берётся в работу. Создайте child-issues с acceptance criteria.\n' ;;
      *)                               printf -- '- %s\n' "$reason" ;;
    esac
  done <<EOF
$reasons
EOF
}