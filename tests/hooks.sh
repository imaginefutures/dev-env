#!/usr/bin/env bash
# 틀 훅(template/base/.claude/hooks/work-guard.py)과 자리 잡기(template/base/scripts/heavy/slot.sh)를
# 만든 입력으로 돌려 본다. 임시 저장소에서만 돈다. 실행: tests/hooks.sh   (실패가 있으면 exit 1)
set -u
HERE="$(cd "$(dirname "$0")/.." && pwd)"
GUARD="$HERE/template/base/.claude/hooks/work-guard.py"
SLOT="$HERE/template/base/scripts/heavy/slot.sh"
export T
T="$(mktemp -d "${TMPDIR:-/tmp}/dev-env-hooks.XXXXXX")"
trap 'rm -rf "$T"' EXIT
fail=0

# expect <이름> <deny|allow|block> <찾을 글(없으면 "")> <모드> <훅 입력 JSON>
expect() {
  local name="$1" want="$2" needle="$3" mode="$4" json="$5" out got
  out="$(printf '%s' "$json" | python3 "$GUARD" "$mode")"
  case "$out" in
    *'"permissionDecision": "deny"'*) got=deny ;;
    *'"decision": "block"'*) got=block ;;
    *) got=allow ;;
  esac
  if [ "$got" = "$want" ] && { [ -z "$needle" ] || printf '%s' "$out" | grep -qF -- "$needle"; }; then
    echo "ok   $name"
  else
    echo "FAIL $name: 기대 $want${needle:+ ($needle)}, 실제 $got: $out"
    fail=1
  fi
}
# j '<JSON 틀>': 틀 안의 @이름@을 같은 이름 환경 변수 값으로 바꾼다(값의 글자 \n은 줄바꿈).
# 홑따옴표 틀을 쓰는 까닭: bash 3.2는 "$( "\"..\"" )" 안의 겹따옴표를 잘못 나눈다.
j() {
  python3 -c '
import json, os, re, sys
fill = lambda m: json.dumps(os.environ.get(m.group(1), "").replace("\\n", "\n"))[1:-1]
print(re.sub(r"@([A-Z_]+)@", fill, sys.argv[1]))' "$1"
}
export DEV_ENV_LOAD_PER_CORE=100000  # 이 컴퓨터의 지금 부하와 상관없이 돌게
export LONG="이 일은 시험용 지시다. 목표와 범위, 건드리면 안 되는 것, 끝 기준, 확인 방법, 보고 모양을 모두 적었다고 치고 길이를 채운다. 결과는 직접 돌려 보고 사실로 확인한다."

# --- 저장소: main(=origin/main) 위에 지휘 가지 merge/x, 도우미 작업 폴더 둘 ---
R="$T/repo"
git init -q -b main "$R"
cd "$R" || exit 1
git config user.email t@t
git config user.name t
mkdir -p web/src/screens src/app
echo a >web/src/screens/PageEditorParts.tsx
echo b >src/app/server.ts
echo c >README.md
git add -A && git commit -qm init
git update-ref refs/remotes/origin/main HEAD
export LEAD="$R/wt/lead"
git worktree add -q "$LEAD" -b merge/x
git worktree add -q "$R/wt/drafts" -b work/drafts merge/x
(cd "$R/wt/drafts" && echo changed >web/src/screens/PageEditorParts.tsx && git commit -qam drafts)
git worktree add -q "$R/wt/dirty" -b work/dirty merge/x
echo dirty >"$R/wt/dirty/src/app/server.ts"
CLAIMS="$R/.git/work-claims"
launch() { BODY="$1" TYPE="${2:-general-purpose}" j '{"cwd":"@LEAD@","tool_name":"Agent","tool_input":{"subagent_type":"@TYPE@","prompt":"@LONG@\n@BODY@"}}'; }

echo "# launch (PreToolUse Agent)"
launch '고칠 곳: 없음' | DEV_ENV_LOAD_PER_CORE=0.000001 python3 "$GUARD" launch | grep -q '컴퓨터가 넘쳐' &&
  echo "ok   컴퓨터가 넘쳐 있으면 막음" || { echo "FAIL 부하 상한을 넘었는데 막지 않았다"; fail=1; }
expect "짧은 지시는 막음" deny "자로 짧다" launch "$(j '{"cwd":"@LEAD@","tool_input":{"prompt":"고쳐"}}')"
expect "고치는 일인데 줄이 없으면 막음" deny "고칠 곳:" launch "$(launch "")"
expect "고칠 곳만 있고 가지가 없으면 막음" deny "가지:" launch "$(launch "고칠 곳: README.md")"
expect "샘플 일(고칠 곳: 없음)은 통과" allow "" launch "$(launch "고칠 곳: 없음(temp에 샘플만)")"
expect "읽기 전용 에이전트는 줄 없이 통과" allow "" launch "$(launch "" Explore)"
expect "다른 작업 폴더의 커밋과 겹치면 막음" deny "work/drafts" launch "$(launch '가지: work/search\n고칠 곳: web/src/screens/PageEditorParts.tsx')"
expect "글롭으로 겹쳐도 막음" deny "PageEditorParts.tsx" launch "$(launch '가지: work/search\n고칠 곳: `web/src/screens/*.tsx`')"
expect "폴더로 겹쳐도 막음" deny "work/drafts" launch "$(launch '가지: work/search\n고칠 곳: web/src/')"
expect "커밋 전 변경과 겹치면 막음" deny "work/dirty" launch "$(launch '가지: work/meta\n고칠 곳: src/app/server.ts')"
expect "겹치지 않으면 통과" allow "" launch "$(launch '- 가지: `work/readme`\n- 고칠 곳: README.md, docs/new.md')"
[ -f "$CLAIMS/work/readme" ] && echo "ok   맡김을 git 공용 폴더에 적음" || { echo "FAIL 맡김 파일이 없다"; fail=1; }
expect "맡김(가지가 아직 없음)과 겹치면 막음" deny "work/readme" launch "$(launch '가지: work/other\n고칠 곳: docs/')"
expect "겹침 허락 줄이 있으면 통과" allow "겹침을 알고 띄움" launch "$(launch '가지: work/other\n고칠 곳: docs/\n겹침 허락: 같은 문서의 다른 절이라 합칠 때 순서만 맞춘다')"
expect "같은 가지를 다시 맡기면 자기 맡김과는 견주지 않음" allow "" launch "$(launch '가지: work/readme\n고칠 곳: README.md')"
rm -f "$CLAIMS/work/other"
# work/readme가 일을 하고 main에 합쳐지면 그 맡김은 더는 막지 않는다.
git worktree add -q "$R/wt/readme" -b work/readme merge/x
(cd "$R/wt/readme" && echo new >README.md && git commit -qam readme)
expect "합쳐지기 전 맡김은 막음" deny "work/readme" launch "$(launch '가지: work/third\n고칠 곳: README.md')"
git worktree remove "$R/wt/readme"
git merge -q --no-edit work/readme && git update-ref refs/remotes/origin/main HEAD
expect "main에 합쳐진 가지의 맡김은 무시, 맡기는 쪽이 main보다 뒤면 알림" allow "보다 뒤다" launch "$(launch '가지: work/third\n고칠 곳: README.md')"
[ ! -f "$CLAIMS/work/readme" ] && echo "ok   합쳐진 맡김 파일을 치움" || { echo "FAIL 합쳐진 맡김이 남았다"; fail=1; }
rm -f "$CLAIMS/work/third"
(cd "$LEAD" && git merge -q --no-edit origin/main)
expect "다른 작업 폴더 절대 경로로 적어도 저장소 기준으로 견줌" deny "work/drafts" launch "$(launch "가지: work/abs\\n고칠 곳: $R/wt/drafts/web/src/screens/PageEditorParts.tsx")"
expect "괄호 속 쉼표로 나누지 않고, 디스크에 없는 경로는 알림" allow "디스크에 없는 고칠 곳(새 파일이면 괜찮고, 오타면 겹침을 못 본다): docs/a.md, docs/b.md." launch "$(launch '가지: work/paren\n고칠 곳: docs/a.md(설명, 쉼표 포함), docs/b.md')"
rm -f "$CLAIMS/work/paren"
# main에 같은 내용으로 옮겨 붙인(cherry-pick) 커밋은 그 가지의 일로 안 본다.
git worktree add -q "$R/wt/picked" -b work/picked merge/x
(cd "$R/wt/picked" && echo picked >src/app/picked.ts && git add -A && git commit -qm picked)
git cherry-pick work/picked >/dev/null && git update-ref refs/remotes/origin/main HEAD
(cd "$LEAD" && git merge -q --no-edit origin/main)
expect "main에 옮겨 붙인 커밋은 겹침으로 안 봄" allow "" launch "$(launch '가지: work/pick2\n고칠 곳: src/app/picked.ts')"
rm -f "$CLAIMS/work/pick2"
# 하루 넘게 손대지 않은 작업 폴더는 겹침으로 세지 않고 치울 대상으로 보인다.
git worktree add -q "$R/wt/old" -b work/old merge/x
OLD=$(($(date +%s) - 172800))
(cd "$R/wt/old" && echo o >src/app/old.ts && git add -A && GIT_COMMITTER_DATE="@$OLD +0000" GIT_AUTHOR_DATE="@$OLD +0000" git commit -qm old && echo o2 >src/app/old2.ts && touch -t 202001010000 src/app/old2.ts)
expect "오래된 작업 폴더는 막지 않고 알림" allow "오래된 작업 폴더" launch "$(launch '가지: work/new-old\n고칠 곳: src/app/old.ts, src/app/old2.ts')"
rm -f "$CLAIMS/work/new-old"

echo "# handback (PreToolUse SubagentHandback, SubagentStop)"
(cd "$LEAD" && git merge -q --no-edit origin/main)
expect "도우미 맡김" allow "" launch "$(launch '가지: work/help\n고칠 곳: src/app/new.ts')"
git worktree add -q "$R/wt/help" -b work/help merge/x
(cd "$R/wt/help" && echo n >src/app/new.ts && git add -A && git commit -qm help)
export TR="$T/proj/sess.jsonl" SUB="$T/proj/sess/subagents/agent-h1.jsonl"
mkdir -p "$T/proj/sess/subagents"
: >"$TR"
BODY='가지: work/help\n고칠 곳: src/app/new.ts' j '{"type":"user","message":{"role":"user","content":"@LONG@\n@BODY@"}}' >"$SUB"
hb() { MSG="$1" ID="${2:-h1}" j '{"hook_event_name":"PreToolUse","tool_name":"SubagentHandback","agent_id":"@ID@","cwd":"@LEAD@","transcript_path":"@TR@","tool_input":{"message":"@MSG@"}}'; }
stop() { ACTIVE="$1" j '{"hook_event_name":"SubagentStop","agent_id":"h1","cwd":"@LEAD@","transcript_path":"@TR@","agent_transcript_path":"@SUB@","stop_hook_active":@ACTIVE@}'; }
expect "바탕이 그대로면 보고 통과" allow "" handback "$(hb "끝")"
(cd "$LEAD" && echo moved >>README.md && git commit -qam lead-moved)
expect "지휘 가지가 움직였으면 보고를 막음" deny "merge/x" handback "$(hb "끝")"
expect "SubagentStop도 막음" block "merge/x" handback "$(stop false)"
expect "한 번 막힌 뒤(stop_hook_active)는 놓아 줌" allow "" handback "$(stop true)"
expect "못 합친 까닭을 적으면 통과" allow "" handback "$(hb '바탕 못 합침: 지휘 가지가 반쯤 고친 상태')"
# 그 보고 뒤 SubagentStop에는 보고 글이 없다. 대화 기록의 마지막 보고에서 탈출 줄을 읽어 다시 막지 않는다.
MSG='바탕 못 합침: 지휘 가지가 반쯤 고친 상태' j '{"type":"assistant","message":{"role":"assistant","content":[{"type":"tool_use","name":"SubagentHandback","input":{"message":"@MSG@"}}]}}' >>"$SUB"
expect "탈출 줄로 보고한 뒤 SubagentStop은 통과" allow "" handback "$(stop false)"
expect "메인 세션(agent_id 없음)은 보지 않음" allow "" handback "$(j '{"hook_event_name":"SubagentStop","cwd":"@LEAD@"}')"
(cd "$R/wt/help" && git merge -q --no-edit merge/x)
expect "합친 뒤에는 통과" allow "" handback "$(hb "끝")"
echo m2 >>src/app/server.ts && git commit -qam main-moved && git update-ref refs/remotes/origin/main HEAD
expect "origin/main이 움직였으면 막음" deny "origin/main" handback "$(hb "끝")"
# 작업 폴더를 붙여 띄운 도우미(isolation: worktree)는 meta.json의 worktreePath로 찾는다.
git worktree add -q "$R/wt/iso" -b worktree-agent-i1 merge/x
(cd "$R/wt/iso" && echo i >src/app/iso.ts && git add -A && git commit -qm iso)
export ISO="$T/proj/sess/subagents/agent-i1.jsonl"
BODY='고칠 곳: src/app/iso.ts' j '{"type":"user","message":{"role":"user","content":[{"type":"text","text":"@LONG@\n@BODY@"}]}}' >"$ISO"
WT="$R/wt/iso" j '{"worktreePath":"@WT@","worktreeBranch":"worktree-agent-i1"}' >"${ISO%.jsonl}.meta.json"
expect "작업 폴더 도우미도 바탕이 낡았으면 막음" deny "origin/main" handback "$(hb "끝" i1)"
# 읽기만 한 도우미(자기 커밋 없음)는 막지 않는다.
git worktree add -q "$R/wt/read" -b work/read merge/x
BODY='가지: work/read\n고칠 곳: 없음' j '{"type":"user","message":{"role":"user","content":"@LONG@\n@BODY@"}}' >"$T/proj/sess/subagents/agent-r1.jsonl"
expect "자기 커밋이 없으면 통과" allow "" handback "$(hb "끝" r1)"

echo "# scratch (PreToolUse Write·Edit·Bash)"
export S="$T/scratchpad"
mkdir -p "$S"
w() { ID="$1" FP="$2" TOOL="${3:-Write}" j '{"tool_name":"@TOOL@","agent_id":"@ID@","scratchpad_dir":"@S@","tool_input":{"file_path":"@FP@"}}'; }
b() { ID="$1" CMD="$2" j '{"tool_name":"Bash","agent_id":"@ID@","scratchpad_dir":"@S@","tool_input":{"command":"@CMD@"}}'; }
expect "도우미가 scratchpad 맨 위에 쓰면 막음" deny "맨 위" scratch "$(w a1 "$S/msg1.txt")"
expect "자기 칸에 쓰면 통과(칸 주인이 됨)" allow "" scratch "$(w a1 "$S/drafts/msg1.txt")"
expect "다른 도우미의 칸에 쓰면 막음" deny "다른 도우미" scratch "$(w a2 "$S/drafts/msg1.txt" Edit)"
expect "다른 도우미는 자기 칸에 씀" allow "" scratch "$(w a2 "$S/search/msg1.txt")"
expect "메인 세션은 맨 위에 써도 됨" allow "" scratch "$(FP="$S/plan.md" j '{"tool_name":"Write","scratchpad_dir":"@S@","tool_input":{"file_path":"@FP@"}}')"
expect "Bash로 맨 위에 쓰면 막음" deny "맨 위" scratch "$(b a1 "cat > $S/msg.txt <<'EOF'
x
EOF")"
expect "Bash로 남의 칸에 tee 하면 막음" deny "다른 도우미" scratch "$(b a1 "echo x | tee -a '$S/search/log.txt'")"
expect "Bash로 자기 칸에 쓰면 통과" allow "" scratch "$(b a1 "git log >$S/drafts/log.txt 2>&1")"
expect "Bash로 읽기만 하면 통과" allow "" scratch "$(b a2 "git commit -F $S/drafts/msg1.txt; cat $S/msg1.txt")"

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
