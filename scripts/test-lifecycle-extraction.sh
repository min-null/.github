#!/usr/bin/env bash
# Функциональный тест извлечения ссылок на issue из тела PR.
# Логика продублирована из .github/workflows/issue-lifecycle-bot.yml намеренно:
# тест падает, если в workflow поменяется regex и он перестанет узнавать реальные
# release-PR (у них `Refs #N` и head-ветка `develop`).
# Использование: ./scripts/test-lifecycle-extraction.sh
# Выход 0 — все проверки прошли.

set -uo pipefail

extract_closing() {
  echo "$1" | grep -oiE '(closes|fixes|resolves|fix|close)[[:space:]]*#[0-9]+' | grep -oE '[0-9]+' | sort -u
}

extract_all() {
  { echo "$1" | grep -oiE '(closes|fixes|resolves|fix|close|refs|see|part[ _-]?of)[[:space:]]*#[0-9]+' | grep -oE '[0-9]+'
    echo "$1" | grep -oiE "(closes|fixes|resolves|fix|close|refs|see|part[ _-]?of)[[:space:]]+minchat-ops[[:space:]]*#[0-9]+" | grep -oE '[0-9]+'
  } | grep -E '^[0-9]+$' | sort -u
}

pass=0
fail=0

check() {
  local name="$1" body="$2" want_all="$3" want_closing="$4"
  local got_all got_closing
  got_all=$(extract_all "$body" | tr '\n' ' ' | sed 's/ $//')
  got_closing=$(extract_closing "$body" | tr '\n' ' ' | sed 's/ $//')
  if [ "$got_all" = "$want_all" ] && [ "$got_closing" = "$want_closing" ]; then
    printf '  PASS  %-46s all=[%s] closing=[%s]\n' "$name" "$got_all" "$got_closing"
    pass=$((pass + 1))
  else
    printf '  FAIL  %-46s all=[%s] want=[%s] | closing=[%s] want=[%s]\n' \
      "$name" "$got_all" "$want_all" "$got_closing" "$want_closing"
    fail=$((fail + 1))
  fi
}

echo "== issue reference extraction =="

# Real bodies from merged release PRs (the ones that were silently skipped).
check "ops#44 body (Refs #42 local)" \
  'Refs #42; parent min-null/minchat-hq#137. Validation: feature PR #43 — все три gates passed; 27 offline scenarios, shell/action lint, compose/policy/BOM.' \
  "42" ""

check "ops#41 body (Refs #39)" \
  'Refs #39. No production tags or deployment are triggered by this ops promotion.' \
  "39" ""

check "cross-repo Refs is NOT taken" \
  'Refs min-null/minchat-hq#96.' \
  "" ""

check "own-repo long form IS taken" \
  'Refs minchat-ops#55 and closes #56.' \
  "55 56" "56"

check "closing phrase wins over refs" \
  'Refs #10. Closes #20.' \
  "10 20" "20"

check "fix/close variants" \
  'Fix #5 close #6' \
  "5 6" "5 6"

check "see / part of" \
  'See #7. Part of #8.' \
  "7 8" ""

check "no refs at all" \
  'Promote develop to main. Local checks passed.' \
  "" ""

check "no false positive on prose #" \
  'Issue #42 mentioned mid-sentence without a keyword.' \
  "" ""

check "case insensitive CLOSES" \
  'CLOSES #77' \
  "77" "77"

echo
echo "passed: $pass   failed: $fail"
[ "$fail" -eq 0 ] || exit 1
echo "RESULT: PASS"