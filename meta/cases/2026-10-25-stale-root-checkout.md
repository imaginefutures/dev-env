# 사례: 훅을 읽는 저장소 폴더가 옛 가지에 머물러 새 장치가 하나도 돌지 않음

종류: 장치(훅·설정)를 main에 올렸는데, 그 장치를 읽는 자리(저장소 폴더, 처음 clone한 곳)가 main을 따라가지 않아 장치가 꺼진 채로 일이 돈다.

**사례 1** (marketing-with-ai, 2026-10-25)
- 입력: Claude Code 세션은 훅과 `.claude/settings.json`을 저장소 폴더에서 읽는다. 저장소 폴더는 하루 종일 옛 통합 가지(merge/b6)에 있었다. 작업 폴더 훅(worktree-guard)과 띄우기 전 훅(agent-launch-guard)은 main과 작업 폴더에만 있었다.
- 결과: 그날의 겹침·과부하 사건([parallel-helpers-collide](2026-10-25-parallel-helpers-collide.md), [unread-orchestration](2026-10-25-unread-orchestration.md) 사례 2) 동안 막는 장치가 한 번도 돌지 않았다. 지휘 세션이 띄울 때 점검을 본 적이 없다는 데서 드러났다.
- 맞는 결과: main에 올릴 때마다 저장소 폴더가 따라오고, 어긋나 있으면 세션이 시작될 때 알린다.

진단: 1(장치가 있었는데 안 돎, docs/agents.md 원칙 7 "장치를 고친다"). 규칙 글은 더하지 않는다. 올리기를 스크립트 하나(`scripts/git/ship.sh`: 빨리감기 확인 → 올리기 → `sync-root.sh`로 저장소 폴더 맞추기)로 두고, CONTRIBUTING 5절의 손 점검 줄(`git log origin/<브랜치>..HEAD`)을 그 스크립트 안내로 바꾼다. 어긋남은 SessionStart 훅(worktree-guard session)이 이 컴퓨터의 origin/main으로 보고 알린다. 저장소 폴더에서 손으로 git 쓰기는 그대로 막는다. 뿌리 연결: P2(같은 실수가 장치를 꺼 둔 채 되풀이됐다), P5(한 사람이 "올린 뒤 저장소 폴더도 맞춘다"를 기억하는 데 기대지 않는다).
