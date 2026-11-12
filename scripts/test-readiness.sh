#!/usr/bin/env bash
# Behavioral tests for the issue readiness rule.
#
# These exist because the rule used to be prose. Prose about "7 conditions, one of
# which is human approval" was never executed, so nothing noticed when it stopped
# matching what the bot did. Now the rule is code, and these tests are what pins it.
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=scripts/lib/readiness.sh
. "$HERE/lib/readiness.sh"

passed=0
failed=0

check() {
  # check <name> <expected-status> <expected-reason-substring-or-empty> <body> <labels> [title]
  local name="$1" want="$2" want_reason="$3" body="$4" labels="$5" title="${6:-}"
  local got got_reason
  readiness_evaluate "$body" "$labels" "$title"
  got="$READINESS_STATUS"
  got_reason="$READINESS_REASONS"

  if [ "$got" != "$want" ]; then
    printf '  FAIL  %-52s want=%s got=%s reasons=[%s]\n' "$name" "$want" "$got" "$got_reason"
    failed=$((failed + 1))
    return
  fi
  if [ -n "$want_reason" ] && ! printf '%s\n' "$got_reason" | grep -qF "$want_reason"; then
    printf '  FAIL  %-52s want reason containing [%s] got=[%s]\n' "$name" "$want_reason" "$got_reason"
    failed=$((failed + 1))
    return
  fi
  if [ "$want" = "ready" ] && [ -n "$got_reason" ]; then
    printf '  FAIL  %-52s ready but reasons=[%s]\n' "$name" "$got_reason"
    failed=$((failed + 1))
    return
  fi
  printf '  PASS  %-52s %s\n' "$name" "$got"
  passed=$((passed + 1))
}

READY_BODY='## Описание

Добавить тихий переключатель mute в настройки.

## Acceptance criteria

- [ ] Переключатель виден
- [ ] По умолчанию выключен
'

echo "== label prefix matching =="
check "type only"              not_ready 'Нет метки area:*'          "$READY_BODY" 'type:feature'
check "area only"              not_ready 'Нет метки type:*'          "$READY_BODY" 'area:web'
check "type+area, no priority" not_ready 'Нет метки priority:*'      "$READY_BODY" 'type:feature area:web'
check "full triple is ready"   ready     ''                          "$READY_BODY" 'type:feature area:web priority:medium'

echo
echo "== body sections =="
check "no body at all"         not_ready 'Нет секции с описанием'    ''           'type:feature area:web priority:medium'
check "description only"       not_ready 'Нет acceptance criteria'   '## Описание

Текст.
' 'type:feature area:web priority:medium'
check "acceptance only"        not_ready 'Нет секции с описанием'    '## Acceptance criteria

- [ ] что-то
' 'type:feature area:web priority:medium'

echo
echo "== accepted section spellings =="
check "russian description"    ready '' '## Что нужно сделать

Описание задачи.

## Критерии приёмки

Готово, когда работает.
' 'type:bug area:api priority:high'
check "english context/summary" ready '' '## Context

Some context.

## Summary

What changes.

## Acceptance criteria

- [ ] ships
' 'type:chore area:ops priority:low'
check "english spelling without acceptance is still not ready" not_ready 'Нет acceptance criteria' '## Context

Some context.

## Summary

What changes.
' 'type:chore area:ops priority:low'
check "Done when"              ready '' '## Описание

Текст.

## Done when

Работает и не ломает старое.
' 'type:feature area:web priority:medium'
check "prose checklist counts" ready '' '## Описание

Текст.

Пункты:
  - [ ] первое
  - [x] второе
' 'type:feature area:web priority:medium'
check "heading needs word boundary" not_ready 'Нет acceptance criteria' '## Описание

Текст.

## Acceptance criteriae

Не то.
' 'type:feature area:web priority:medium'
check "prose mention is not a section" not_ready 'Нет секции с описанием' 'Мы добавим раздел acceptance criteria позже, пока нет acceptance criteria в body.

- [ ] что-то
' 'type:feature area:web priority:medium'

echo
echo "== regressions found while building this rule =="
# The trim idiom ${v#\"${v%%[![:space:]]*}\"} eats the first character when the
# value has no leading whitespace, which every markdown heading does.
check "hash with no space after it"    ready '' '##Описание

Текст.

##Acceptance criteria

- [ ] работает
' 'type:feature area:web priority:medium'
check "heading with trailing spaces"   ready '' '## Описание

Текст.

## Acceptance criteria

- [ ] работает
' 'type:feature area:web priority:medium'
check "deep heading level"             ready '' '### Описание

Текст.

#### Критерии приёмки

Готово.
' 'type:feature area:web priority:medium'
# A runner without a locale cannot fold Cyrillic case, so the Russian heading must
# match with the exact capitalisation used in the issue templates.
check "russian acceptance capitalised" ready '' '## Описание

Текст.

## Критерии приёмки

Готово, когда работает.
' 'type:feature area:web priority:medium'
check "checklist item with text after the box" ready '' '## Описание

Текст.

Пункты:
  - [ ] первое
  - [x] второе
' 'type:feature area:web priority:medium'
# A CR from a Windows checkout must not change the answer.
CR_BODY=$'## Описание\r\n\r\nТекст.\r\n\r\n## Acceptance criteria\r\n\r\n- [ ] работает\r\n'
check "CRLF body matches LF body"      ready '' "$CR_BODY" 'type:feature area:web priority:medium'

echo
echo "== human approval is NOT a condition (the 2026-10-17 change) =="
check "open needs:design, no approval"  ready '' "$READY_BODY" \
  'type:feature area:web priority:medium needs:design'
check "all gates open, nothing approved" ready '' "$READY_BODY" \
  'type:feature area:web priority:medium needs:design needs:contract needs:adr needs:research needs:spec'
check "stale approved labels are harmless" ready '' "$READY_BODY" \
  'type:feature area:web priority:medium design:approved contract:approved adr:approved'

echo
echo "== real blockers still block =="
check "coordination:blocked"   not_ready 'Стоит coordination:blocked' "$READY_BODY" \
  'type:feature area:web priority:medium coordination:blocked'
check "other coordination labels do not block" ready '' "$READY_BODY" \
  'type:feature area:web priority:medium coordination:needs-decision'

echo
echo "== epics are containers =="
check "epic by labels"         not_ready 'Это эпик-контейнер' "$READY_BODY" \
  'area:hq type:feature priority:high' 'Перевести процесс'
check "epic by title"          not_ready 'Это эпик-контейнер' "$READY_BODY" \
  'area:hq type:chore priority:high' '[Epic] Перевести процесс'
check "hq issue without epic labels is a normal task" ready '' "$READY_BODY" \
  'area:hq type:chore priority:medium' 'Обновить канон процесса'

echo
echo "== label parsing edge cases =="
readiness_evaluate "$READY_BODY" '  status:pickable   type:bug  area:api  priority:critical  ' 'Bug'
[ "$READINESS_STATUS" = "ready" ] \
  && { printf '  PASS  %-52s %s\n' 'irregular whitespace between labels' "$READINESS_STATUS"; passed=$((passed + 1)); } \
  || { printf '  FAIL  %-52s got=%s\n' 'irregular whitespace between labels' "$READINESS_STATUS"; failed=$((failed + 1)); }

# "type:" with nothing after it must not count as a type label.
readiness_evaluate "$READY_BODY" 'type: area: priority:' 'X'
[ "$READINESS_STATUS" = "not_ready" ] \
  && { printf '  PASS  %-52s %s\n' 'bare prefix without a value' "$READINESS_STATUS"; passed=$((passed + 1)); } \
  || { printf '  FAIL  %-52s got=%s (bare prefixes must not count)\n' 'bare prefix without a value' "$READINESS_STATUS"; failed=$((failed + 1)); }

# A label whose name merely starts with the prefix characters must not match.
readiness_evaluate "$READY_BODY" 'xtype:x areax:y priorityz:w' 'X'
[ "$READINESS_STATUS" = "not_ready" ] \
  && { printf '  PASS  %-52s %s\n' 'prefix must not match mid-name' "$READINESS_STATUS"; passed=$((passed + 1)); } \
  || { printf '  FAIL  %-52s got=%s (prefix must not match mid-name)\n' 'prefix must not match mid-name' "$READINESS_STATUS"; failed=$((failed + 1)); }

# Idempotence: evaluating twice must give the same answer.
readiness_evaluate "$READY_BODY" 'type:feature area:web priority:medium' 'X'
first="$READINESS_STATUS"
readiness_evaluate "$READY_BODY" 'type:feature area:web priority:medium' 'X'
[ "$first" = "$READINESS_STATUS" ] \
  && { printf '  PASS  %-52s %s\n' 'evaluation is idempotent' "$first"; passed=$((passed + 1)); } \
  || { printf '  FAIL  %-52s %s then %s\n' 'evaluation is idempotent' "$first" "$READINESS_STATUS"; failed=$((failed + 1)); }

echo
echo "== comment body =="
readiness_evaluate 'ничего нет' 'status:pickable' 'X'
comment="$(readiness_comment 42 "$READINESS_REASONS")"
for needle in '#42' 'Нет секции с описанием' 'Нет acceptance criteria' 'Нет метки priority:'; do
  if printf '%s\n' "$comment" | grep -qF "$needle"; then
    printf '  PASS  %-52s\n' "comment mentions: $needle"
    passed=$((passed + 1))
  else
    printf '  FAIL  %-52s missing from comment\n' "comment mentions: $needle"
    failed=$((failed + 1))
  fi
done

# A ready issue must never produce a rejection comment.
comment=""
readiness_comment 7 ""
[ -z "$comment" ] \
  && { printf '  PASS  %-52s\n' 'no reasons means no comment'; passed=$((passed + 1)); } \
  || { printf '  FAIL  %-52s got [%s]\n' 'no reasons means no comment' "$comment"; failed=$((failed + 1)); }

echo
printf 'passed: %d   failed: %d\n' "$passed" "$failed"
[ "$failed" -eq 0 ] || exit 1
echo "RESULT: PASS"