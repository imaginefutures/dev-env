# 스킬 지도

언제 어떤 스킬을 쓰는지 정한 문서다. 이 프로젝트의 단계별 스킬 표는 [project.md](project.md)에 있다. 화면이 있는 프로젝트의 스킬은 `web.md`에 있다.

부르는 법은 둘이다. **자동**은 Claude가 상황을 보고 알아서 쓴다(`/이름`으로 직접 불러도 된다). **사람만**은 사람이 `/이름`을 쳐야 돌아간다. Claude는 그 때가 오면 "`/이름`으로 시작할까요?"라고 먼저 권한다.

## 1. 언제 무엇을

| 때 | 스킬 | 남는 것 |
|---|---|---|
| 코드를 쓰고 고칠 때마다 | `karpathy-guidelines` | 없음(태도) |
| 설계·계획을 정할 때 | `/grill-with-docs`(사람만) | `GLOSSARY.md`, `docs/adr/` |
| 생각만 점검할 때 | `grilling` | 없음 |
| 용어가 흔들릴 때, 이름을 정할 때 | `domain-modeling` | `GLOSSARY.md`, `docs/adr/` |
| 모듈의 입구와 경계를 정할 때 | `codebase-design` | 없음(용어 기준) |
| 기능을 만들 때 | `tdd` | 테스트가 붙은 기능 |
| 버그가 나면 | `/fix` | 근본 원인 고침 |
| 옛것을 새것으로 바꿀 때, 저장 구조를 운영 중에 바꿀 때 | `deprecation-and-migration` | 옮기기 계획 |
| 처음 보는 코드를 파악할 때 | `graphify`(깔려 있으면) | `graphify-out/` 그래프 |
| 기능 하나를 끝낼 때 | `/code-review`, `/simplify`(Claude Code 기본) | 고침 |

## 2. 스킬별 메모

- **grill-with-docs**: 설계를 질문으로 끝까지 파고들고, 답이 정해지는 대로 용어집과 결정 기록에 적는다. 안에서 `grilling`과 `domain-modeling`을 부른다. ADR에 있는 결정은 새 사실이 나왔을 때만 다시 연다.
- **grilling**: 정할 것들을 나무 모양으로 펼쳐 놓고, 지금 답할 수 있는 질문을 한 번에 묶어 권장안과 함께 묻는다. 찾아볼 수 있는 사실은 묻지 않고 직접 찾는다.
- **domain-modeling**: 말이 용어집과 어긋나면 바로 짚는다. 표·모듈 이름이 곧 용어다.
- **codebase-design**: "작은 입구 뒤에 많은 동작"이 목표다. `tdd`가 이 스킬을 불러 쓴다.
- **tdd**: 테스트 하나 → 코드 하나씩 번갈아 만든다. 테스트를 쓰기 전에 어느 입구를 시험할지 먼저 사람과 정한다.
- **fix**: 3번(사실의 주인 확인)이 "사실마다 주인 하나"를 지키는 자리다. 외부 출처가 아니라 dev-env에서 만든 스킬이라 `skills-lock.json`에 없다.
- **deprecation-and-migration**: 옛것을 감싸 조금씩 바꾸기, 넓혔다 좁히기, 옛 코드 정리.
- **graphify**: 코드·문서·SQL을 읽어 "무엇이 무엇을 부르는지" 그래프로 만든다. 코드는 이 컴퓨터 안에서만 읽는다. 만든 뒤에는 파일을 뒤지는 대신 `graphify query "질문"`으로 묻는다. **결과 폴더가 대상 폴더 안에 생기므로, 남의 저장소나 읽기만 할 저장소는 복사본에서 돌린다.** 유료 클라우드는 쓰지 않는다.

## 3. 설치와 관리

- 스킬은 **프로젝트 안에** 깐다: `.claude/skills/`. 출처와 버전은 `skills-lock.json`.
- 이 파일과 `.claude/skills/`의 틀 스킬은 dev-env가 주인이다. dev-env의 `setup.sh`를 다시 돌리면 최신 틀로 바뀐다.
- 외부 스킬 새 버전: `npx skills update -p`. 받은 뒤에는 바뀐 내용을 읽고 나서 커밋한다(스킬은 Claude와 같은 권한으로 돈다). 괜찮으면 dev-env에도 같은 변경을 올린다.
- graphify는 실행 프로그램이 필요하다: `uv tool install "graphifyy[sql]"` 뒤 `graphify install --project`. 새 버전: `uv tool upgrade graphifyy`.
