# 변경 기록

한 줄: 날짜 / 사례 / 진단 / 더한 것·뺀 것 / 총량 변화.

- 2026-10-25 / local-only-skill 2건 / 진단 2(기존 문장이 틀림) / web.md 1절에서 `visual-explain` 언급을 뺌 / 규칙 수 변화 없음
- 2026-10-25 / 체계 처음 도입 / 해당 없음 / `meta/` 신설(뿌리 P1~P5, 진단·통과 조건·도입 심사·가지치기·다시 짓기, 가설 H1), `setup.sh` 정리 목록에 `meta/`, README에 안내 한 단락 / 기준선을 아래에 기록
- 2026-10-25 / shared-checkout 4건 / 진단 1(5절이 글이라 안 지켜짐)+2(차례 번호 규칙이 동시 작업에서 틀림) / CONTRIBUTING 5절의 손 점검 셋(`git status` 비교, `git diff --cached` 확인, `-F` 커밋 메시지)을 빼고 장치로: 작업 폴더 훅(`worktree-guard.sh`, SessionStart·PreToolUse), "차례 번호를 쓰지 않는다" 한 줄; `setup.sh`가 훅을 사건마다 합치게 / 5절 규칙 6 → 5(−1)
- 2026-10-25 / shared-checkout(이어서) / 진단 3(5절 "차례 번호를 쓰지 않는다"와 9절 "번호는 차례대로"가 부딪힘) / 9절 결정 기록 이름을 시각+슬러그로, 대체 표시를 이름으로; 외부 스킬(domain-modeling, 해시 고정)은 고치지 않고 9절이 이긴다고 적음 / 규칙 수 변화 없음
- 2026-10-25 / unread-orchestration 2건 / 진단 1(docs/agents.md 원칙이 글이라 띄우는 순간 안 보임) / 서브에이전트를 띄울 때 점검을 보이고 불완전한 지시를 막는 훅(`agent-launch-guard.sh`, PreToolUse Agent), agents.md 점검 제목에 훅 안내 한 줄 / 규칙 글 수 변화 없음
- 2026-10-25 / unread-orchestration(이어서) / 진단 1(원칙 4 "좁은 자원에 용량만큼만"을 보이기만 해서는 기계가 아는 값 하나, 컴퓨터 부하를 쓰지 않음) / `agent-launch-guard.sh`가 부하(1분·5분 평균 중 낮은 쪽)가 코어의 1.5배를 넘으면 띄우기를 막고, 보일 때 지금 부하를 붙임, agents.md 안내 한 줄 고침 / 규칙 글 수 변화 없음
- 2026-10-25 / parallel-helpers-collide 4건 / 진단 1(agents.md 원칙 4·8과 일 목록의 겹침 칸이 글이라 안 지켜짐; scratchpad는 shared-checkout과 같은 구조의 두 번째 사례) / 장치: `work-guard.py`(띄울 때 `가지:`·`고칠 곳:` 겹침 검사와 맡김 기록, 보고 전 바탕 검사 SubagentHandback·SubagentStop, scratchpad 칸 검사), `scripts/heavy/slot.sh`(e2e·시험 자리), `tests/hooks.sh`; `agent-launch-guard.sh`는 본체로 넘기는 한 줄; agents.md 원칙 4·8·10과 점검 2를 장치 안내로 바꿔 씀 / 원칙 수 10 그대로, 규칙 글 수 변화 없음
- 2026-10-25 / stale-root-checkout 1건 / 진단 1(장치가 있었는데 훅을 읽는 저장소 폴더가 옛 가지라 안 돎) / `scripts/git/ship.sh`(빨리감기 확인·올리기·저장소 폴더 맞추기)·`sync-root.sh`, SessionStart에서 저장소 폴더가 main이 아니거나 뒤면 알림(worktree-guard), 올리기 스크립트를 묻고 돌게 permissions.ask, CONTRIBUTING 5절 push 줄을 스크립트 안내로 바꿔 씀, tests/hooks.sh 9개 / 규칙 글 수 변화 없음

## 숫자 (기준선: 2026-10-25)

- 뿌리 원칙: 5
- 체계 규칙(GOVERNANCE 1~6절): 6절
- 예외 문구: 0
- 가설 규칙: 1 (H1 세션 로그)
