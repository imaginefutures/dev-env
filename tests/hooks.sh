#!/usr/bin/env bash
# 틀의 저장소 폴더 지키기(worktree-guard.sh, ship.sh·sync-root.sh)와 자리 잡기(slot.sh, vitest.sh)를
# 만든 입력으로 돌려 본다. 팀 규칙 훅(work-guard.py)의 시험은 스튜디오 plugin/tests/hooks.sh에 있다. 임시 저장소에서만 돈다. 실행: tests/hooks.sh   (실패가 있으면 exit 1)
set -u
HERE="$(cd "$(dirname "$0")/.." && pwd)"
SLOT="$HERE/template/base/scripts/heavy/slot.sh"
export T
T="$(mktemp -d "${TMPDIR:-/tmp}/dev-env-hooks.XXXXXX")"
trap 'rm -rf "$T"' EXIT
fail=0

# j '<JSON 틀>': 틀 안의 @이름@을 같은 이름 환경 변수 값으로 바꾼다(값의 글자 \n은 줄바꿈).
# 홑따옴표 틀을 쓰는 까닭: bash 3.2는 "$( "\"..\"" )" 안의 겹따옴표를 잘못 나눈다.
j() {
  python3 -c '
import json, os, re, sys
fill = lambda m: json.dumps(os.environ.get(m.group(1), "").replace("\\n", "\n"))[1:-1]
print(re.sub(r"@([A-Z_]+)@", fill, sys.argv[1]))' "$1"
}

echo "# 저장소 폴더 맞추기 (worktree-guard session, scripts/git/ship.sh·sync-root.sh)"
WG="$HERE/template/base/.claude/hooks/worktree-guard.sh"
GITS="$HERE/template/base/scripts/git"
git init -q --bare -b main "$T/remote.git"
git clone -q "$T/remote.git" "$T/root" 2>/dev/null
ROOT="$T/root"
(cd "$ROOT" && git config user.email t@t && git config user.name t && echo a >a.txt && git add a.txt && git commit -qm init && git push -q origin main && git switch -q -c old-merge)
git -C "$ROOT" worktree add -q "$ROOT/wt" -b work/ship origin/main
SH="$ROOT/wt"
(cd "$SH" && git config user.email t@t && git config user.name t && echo b >b.txt && git add b.txt && git commit -qm ship-b)
session() { CWD="$1" j '{"hook_event_name":"SessionStart","cwd":"@CWD@"}' | bash "$WG" session; }
check() { # check <이름> <조건 결과 0/1>
  if [ "$2" = 0 ]; then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi
}
out="$(session "$SH")"
case "$out" in *"저장소 폴더"*"old-merge"*sync-root*) check "저장소 폴더가 main이 아니면 세션 시작 때 알림" 0 ;; *) check "저장소 폴더가 main이 아니면 세션 시작 때 알림: $out" 1 ;; esac
CWD="$ROOT" CMD="git -C $ROOT merge --ff-only origin/main" j '{"cwd":"@CWD@","tool_input":{"command":"@CMD@"}}' | bash "$WG" bash 2>/dev/null
check "저장소 폴더에서 손으로 git merge는 여전히 막음" "$([ $? = 2 ] && echo 0 || echo 1)"
CWD="$SH" CMD="$GITS/sync-root.sh" j '{"cwd":"@CWD@","tool_input":{"command":"@CMD@"}}' | bash "$WG" bash 2>/dev/null
check "sync-root.sh 부르기는 막지 않음" "$([ $? = 0 ] && echo 0 || echo 1)"
out="$(cd "$SH" && "$GITS/ship.sh" 2>&1)"
check "ship: 올리고 저장소 폴더를 main으로 옮겨 맞춤" "$([ "$(git -C "$T/remote.git" rev-parse main)" = "$(git -C "$SH" rev-parse HEAD)" ] && [ "$(git -C "$ROOT" symbolic-ref --short HEAD)" = main ] && [ "$(git -C "$ROOT" rev-parse HEAD)" = "$(git -C "$SH" rev-parse HEAD)" ] && echo 0 || echo 1)"
check "맞춘 뒤 세션 시작 알림 없음" "$([ -z "$(session "$SH")" ] && echo 0 || echo 1)"
# 다른 곳에서 main이 앞서 나가면 빨리감기가 안 되니 올리지 않는다.
git clone -q "$T/remote.git" "$T/other" 2>/dev/null
(cd "$T/other" && git config user.email t@t && git config user.name t && echo c >c.txt && git add c.txt && git commit -qm other && git push -q origin main)
(cd "$SH" && echo d >d.txt && git add d.txt && git commit -qm ship-d)
before="$(git -C "$T/remote.git" rev-parse main)"
out="$(cd "$SH" && "$GITS/ship.sh" 2>&1)"; code=$?
check "ship: origin/main이 앞서 있으면 올리지 않음" "$([ $code != 0 ] && [ "$(git -C "$T/remote.git" rev-parse main)" = "$before" ] && echo 0 || echo 1)"
out="$(session "$SH")"
case "$out" in *"1커밋 뒤다"*) check "저장소 폴더가 origin/main보다 뒤면 알림" 0 ;; *) check "뒤짐 알림: $out" 1 ;; esac
# 저장소 폴더에 커밋 안 한 변경이 있으면 올리기는 하되 맞추지 않고 알린다.
(cd "$SH" && git merge -q --no-edit origin/main)
echo dirty >>"$ROOT/a.txt"
out="$(cd "$SH" && "$GITS/ship.sh" 2>&1)"; code=$?
check "ship: 저장소 폴더가 더러우면 올린 뒤 맞추기는 멈추고 알림" "$([ $code = 1 ] && [ "$(git -C "$T/remote.git" rev-parse main)" = "$(git -C "$SH" rev-parse HEAD)" ] && [ "$(git -C "$ROOT" rev-parse HEAD)" != "$(git -C "$SH" rev-parse HEAD)" ] && printf '%s' "$out" | grep -q "커밋 안 한 변경" && echo 0 || echo 1)"
git -C "$ROOT" checkout -q -- a.txt
out="$(cd "$SH" && "$GITS/sync-root.sh" 2>&1)"
check "정리한 뒤 sync-root.sh로 맞춤" "$([ "$(git -C "$ROOT" rev-parse HEAD)" = "$(git -C "$SH" rev-parse HEAD)" ] && echo 0 || echo 1)"

echo "# slot.sh"
unset CI
: >"$T/not-a-dir"
msg="$(XDG_CACHE_HOME="$T/not-a-dir" "$SLOT" e2e echo ran 2>&1)"
case "$msg" in *"자리 없이 돈다"*ran*) echo "ok   잠금 폴더를 못 만들면 알리고 자리 없이 돈다" ;; *) echo "FAIL 잠금 폴더 없음: $msg"; fail=1 ;; esac
export XDG_CACHE_HOME="$T/cache"
mkdir -p "$T/cache/dev-env/heavy/stuck/.mutex"
msg="$(HEAVY_MUTEX_TRIES=5 "$SLOT" stuck echo ran 2>&1)"
case "$msg" in *"잠금을"*"자리 없이 돈다"*ran*) echo "ok   잠금을 오래 못 받으면 알리고 자리 없이 돈다" ;; *) echo "FAIL 잠금 대기: $msg"; fail=1 ;; esac
"$SLOT" e2e sh -c 'sleep 2' &
sleep 0.5
start=$(date +%s)
msg="$("$SLOT" e2e true 2>&1)"
waited=$(($(date +%s) - start))
if [ "$waited" -ge 1 ] && printf '%s' "$msg" | grep -q '자리 기다림'; then
  echo "ok   두 번째 e2e는 첫째가 끝날 때까지 기다림(${waited}초): $msg"
else
  echo "FAIL 기다리지 않았다(${waited}초): $msg"
  fail=1
fi
wait
"$SLOT" e2e sleep 30 &
holder=$!
sleep 0.5
child="$(pgrep -P "$holder")"
kill -9 "$holder"
wait "$holder" 2>/dev/null
start=$(date +%s)
"$SLOT" e2e true 2>/dev/null
[ $(($(date +%s) - start)) -le 1 ] && echo "ok   kill -9로 죽은 자리는 바로 되찾음" || { echo "FAIL 죽은 자리를 못 되찾음"; fail=1; }
[ -n "$child" ] && kill "$child" 2>/dev/null
"$SLOT" test sh -c 'exit 7'
[ $? = 7 ] && echo "ok   명령의 종료 코드를 그대로 돌려줌" || { echo "FAIL 종료 코드"; fail=1; }
[ "$(CI=1 "$SLOT" e2e echo ci)" = ci ] && echo "ok   CI에서는 그냥 돈다" || { echo "FAIL CI"; fail=1; }

echo "# vitest.sh (pnpm test: 고른 실행은 자리 없이, 전체 실패는 실패한 파일만 다시)"
VT="$HERE/template/ts-web/scripts/heavy/vitest.sh"
mkdir -p "$T/vt" "$T/bin"
cp "$VT" "$SLOT" "$T/vt/"
VT="$T/vt/vitest.sh"
cat >"$T/bin/vitest" <<'FAKE'
#!/usr/bin/env bash
# 가짜 vitest: run [옵션] [파일...]. 파일을 안 주면 FAKE_FILES 전체. FAKE_FAIL은 늘 실패, FAKE_FLAKY는 전체 실행에서만 실패.
shift
out=""
files=""
for a in "$@"; do
  case "$a" in --outputFile.json=*) out="${a#*=}" ;; -*) ;; *) files="$files $a" ;; esac
done
full=0
[ -z "$files" ] && files="$FAKE_FILES" && full=1
echo "$full$files" >>"$FAKE_LOG"
[ -n "${FAKE_CRASH:-}" ] && exit 1
bad=0
rows=""
for f in $files; do
  st=passed
  case " ${FAKE_FAIL:-} " in *" $f "*) st=failed ;; esac
  [ "$full" = 1 ] && case " ${FAKE_FLAKY:-} " in *" $f "*) st=failed ;; esac
  [ "$st" = failed ] && bad=1
  rows="$rows${rows:+,}{\"name\":\"$f\",\"status\":\"$st\"}"
done
[ -n "$out" ] && echo "{\"testResults\":[$rows]}" >"$out"
exit "$bad"
FAKE
chmod +x "$T/bin/vitest"
export VITEST_BIN="$T/bin/vitest" FAKE_FILES="a.test.ts b.test.ts c.test.ts" FAKE_LOG="$T/vt/log"
vt() { : >"$FAKE_LOG"; out="$("$VT" "$@" 2>&1)"; code=$?; }
vt
check "전체 실행이 통과하면 0" "$([ $code = 0 ] && [ "$(wc -l <"$FAKE_LOG" | tr -d ' ')" = 1 ] && echo 0 || echo 1)"
FAKE_FLAKY="b.test.ts" vt
check "전체에서만 실패한 파일은 다시 돌려 통과하면 0, 이름을 보임" "$([ $code = 0 ] && printf '%s' "$out" | grep -q "다시 돌려 통과: 1개(부하로 인한 실패로 봄): b.test.ts /" && grep -qx "0 b.test.ts" "$FAKE_LOG" && echo 0 || echo 1)"
FAKE_FLAKY="b.test.ts" FAKE_FAIL="c.test.ts" vt
check "다시 돌려도 실패하는 파일이 있으면 실패" "$([ $code != 0 ] && printf '%s' "$out" | grep -q "다시 돌려 통과: 1개.*여전히 실패: 1개: c.test.ts" && echo 0 || echo 1)"
FAKE_CRASH=1 vt
check "실패한 파일을 못 뽑으면(설정·DB 실패) 다시 돌리지 않고 실패" "$([ $code != 0 ] && [ "$(wc -l <"$FAKE_LOG" | tr -d ' ')" = 1 ] && echo 0 || echo 1)"
CI=1 FAKE_FLAKY="b.test.ts" vt
check "CI에서는 다시 돌리지 않음(들쭉날쭉한 실패를 가리지 않게)" "$([ $code != 0 ] && [ "$(wc -l <"$FAKE_LOG" | tr -d ' ')" = 1 ] && echo 0 || echo 1)"
HEAVY_SLOTS_TEST=1 "$SLOT" test sleep 3 &
sleep 0.5
start=$(date +%s)
vt web/src/x.test.ts
check "파일을 고른 실행은 자리를 기다리지 않음" "$([ $code = 0 ] && [ $(($(date +%s) - start)) -le 1 ] && ! printf '%s' "$out" | grep -q "자리 기다림" && echo 0 || echo 1)"
start=$(date +%s)
HEAVY_SLOTS_TEST=1 vt
check "전체 실행은 자리를 기다림" "$([ $code = 0 ] && printf '%s' "$out" | grep -q "자리 기다림" && echo 0 || echo 1)"
wait

exit "$fail"
