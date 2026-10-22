# <프로젝트 이름>

<한 줄 설명>

## 일을 시작하기 전에

1. **지금 단계를 본다.** [README.md](README.md)의 "상태" 줄.
2. **[docs/project.md](docs/project.md)를 본다.** 이 프로젝트의 층·부품·데이터 규칙과 단계별 스킬이 있다. 일반 가이드와 부딪히면 project.md가 이긴다.
3. **설계를 건드리는 일이면 설계 문서를 먼저 읽는다.** 정한 것이 바뀌면 코드보다 설계 문서를 먼저 고친다.
4. **용어는 `GLOSSARY.md`를 따른다**(생기면). 결정과 이유는 `docs/adr/`에 남긴다.

## 작업 태도

1. **생각하고, 요청한 만큼만, 수술하듯, 목표로 검증한다.** 원본은 `karpathy-guidelines` 스킬이다.
2. 가정은 답변 첫머리에 적는다. 결과가 갈릴 때만 권장안을 표시한 객관식으로 하나씩 묻는다.
3. 끝낼 때 현재 상태·남은 일·확인 못 한 것을 먼저 적는다. 돌리지 않은 확인은 돌리지 않았다고 쓴다.
4. 버그는 `/fix`로 고친다.

## 검증 명령

<코드가 생기면 채운다. 예: `pnpm test`(단위), `pnpm typecheck`(타입), `pnpm lint`>

## 지킬 것

- 확인받고 하는 일은 [CONTRIBUTING.md](CONTRIBUTING.md) 4절이다.
- 이 프로젝트에서 더 지킬 것은 [docs/project.md](docs/project.md) 7절이다.
- 단계가 끝나면 README의 "상태" 줄을 다음 단계로 고친다.

## 문서 지도

주제를 다루는 문서가 있으면 먼저 읽고 따른다. "틀"은 dev-env가 주인이라 이 저장소에서 고치지 않는다(고칠 일이면 dev-env에서 고친다).

| 문서 | 주인 | 볼 때 |
|---|---|---|
| [README.md](README.md) | 프로젝트 | 지금 단계, 문서 목록 |
| [docs/project.md](docs/project.md) | 프로젝트 | 이 프로젝트의 값과 규칙, 단계별 스킬 |
| [CONTRIBUTING.md](CONTRIBUTING.md) | 틀 | 일하는 순서, 커밋 줄, 확인받는 일, 새 기능 점검표 |
| [docs/code-rules.md](docs/code-rules.md) | 틀 | 사실의 주인, 부르는 방향, 두 번 돌아도 안전하게, 권한 경계, 테스트 층 |
| [docs/agents.md](docs/agents.md) | 틀 | 서브에이전트로 나눠 일하기 |
| [docs/skills.md](docs/skills.md) | 틀 | 언제 어떤 스킬을 쓰나 |
<!-- dev-env:preset-docs -->
| `GLOSSARY.md` | 프로젝트 | 용어(생기면) |
| `docs/adr/` | 프로젝트 | 되돌리기 어려운 결정(생기면) |
