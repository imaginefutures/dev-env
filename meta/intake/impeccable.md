# impeccable

판정: 안 받음
날짜: 2026-10-25
출처: pbakaus/impeccable (marketing-with-ai의 같은 날 판정과 같다)

이유:
- 화면 규칙이 TS 웹 묶음의 `antislop-ui`·`antislop-copywriting`·`antislop-human`·`antislop-layoutmobile`과 거의 1:1로 겹친다.
- `DESIGN.md`를 코드에서 AI가 만들어 쓴다. antislop은 사람이 쓰고 AI는 받아 적기만 한다(소유권 충돌).
- `.claude/settings.local.json`에 훅을 써넣고, `PRODUCT.md`가 `docs/project.md`와 겹친다(P3).
- 새 디자인을 시작할 때마다 impeccable.style로 요청을 보내고, 익명 통계도 기본으로 켜져 있다.

가져올 만한 것: AI 없이 도는 기계 검사기(`npx impeccable detect`, 규칙 62개).
못 본 것: 검사기 규칙이 antislop 규칙과 어긋나는지.
다시 심사할 조건: 검사기만 CI에 넣는 안(P2에 맞음)을 시험할 때.
