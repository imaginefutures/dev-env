#!/usr/bin/env bash
# pnpm test의 본체. 전체 실행은 컴퓨터 전체 자리(scripts/heavy/slot.sh test, 기본 2)를 받아 돌고,
# 파일·이름을 고른 실행(`pnpm test web/x`, `pnpm test -t 이름`)은 작아서 기다리지 않는다.
# 전체 실행이 실패하면 실패한 파일만 한 번, 파일 병렬 없이 다시 돌린다. 부하로 난 실패(시간 초과, DB 연결 수 초과)와
# 진짜 실패를 가른다. 다시 돌려 통과한 파일은 이름을 보이고(숨기지 않는다), 여전히 실패한 파일이 있을 때만 실패로 끝낸다.
# CI에서는 자리도 다시 돌리기도 없이 그냥 돈다: 러너 하나에 일 하나라 부하 실패가 없고, 다시 돌리기는 들쭉날쭉한 시험을 가릴 수 있다.
set -u
here="$(cd "$(dirname "$0")" && pwd)"
runner="${VITEST_BIN:-vitest}"

# 고른 실행인가: 옵션(-로 시작)이 아닌 인자가 하나라도 있으면 고른 것이다(파일·폴더·-t 이름).
targeted=0
for arg in "$@"; do
  case "$arg" in -*) ;; *) targeted=1 ;; esac
done
if [ -n "${CI:-}" ] || [ "$targeted" = 1 ]; then
  exec "$runner" run "$@"
fi

dir="$(mktemp -d "${TMPDIR:-/tmp}/vitest-rerun.XXXXXX")"
trap 'rm -rf "$dir"' EXIT
"$here/slot.sh" test "$runner" run --reporter=default --reporter=json --outputFile.json="$dir/full.json" "$@"
code=$?
[ "$code" = 0 ] && exit 0

# JSON 보고에서 실패한 파일을 뽑는다. 파일이 안 나오면(설정·DB 준비 실패, 처리 안 된 오류) 다시 돌릴 것이 없으니 그대로 실패.
failed_files() {
  python3 -c '
import json, sys
try:
    data = json.load(open(sys.argv[1]))
except Exception:
    sys.exit(0)
for r in data.get("testResults", []):
    if r.get("status") == "failed":
        print(r["name"])' "$1"
}
first="$(failed_files "$dir/full.json")"
[ -n "$first" ] || exit "$code"
n="$(printf '%s\n' "$first" | wc -l | tr -d ' ')"
echo "[test] 실패한 파일 ${n}개를 파일 병렬 없이 한 번 다시 돌린다(부하로 난 실패를 가르려고)." >&2
# shellcheck disable=SC2046 # 파일 이름에는 빈칸이 없다(시험 파일 이름 규칙)
"$runner" run --no-file-parallelism --reporter=default --reporter=json --outputFile.json="$dir/again.json" $(printf '%s\n' "$first") "$@"
again_code=$?
still="$(failed_files "$dir/again.json")"
if [ "$again_code" != 0 ] && [ -z "$still" ]; then
  still="$first" # 다시 돌리기 자체가 실패했는데 파일을 못 뽑았으면 처음 실패를 그대로 둔다.
fi
passed="$(printf '%s\n' "$first" | grep -vxF -f <(printf '%s\n' "$still") || true)"
m=0
[ -n "$still" ] && m="$(printf '%s\n' "$still" | wc -l | tr -d ' ')"
names() { for f in $1; do printf ' %s' "${f#"$PWD"/}"; done; }
echo "[test] 다시 돌려 통과: $((n - m))개(부하로 인한 실패로 봄)${passed:+:$(names "$passed")} / 여전히 실패: ${m}개${still:+:$(names "$still")}" >&2
[ "$m" = 0 ]
