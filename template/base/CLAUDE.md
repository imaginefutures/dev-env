# <프로젝트 이름>

<한 줄 설명>

## 일을 시작하기 전에

1. **지금 단계를 본다.** [README.md](README.md)의 "상태" 줄.
2. **[docs/project.md](docs/project.md)를 본다.** 이 프로젝트의 층·부품·데이터 규칙과 단계별 스킬이 있다. 일반 가이드와 부딪히면 project.md가 이긴다.
3. **설계를 건드리는 일이면 설계 문서를 먼저 읽는다.** 정한 것이 바뀌면 코드보다 설계 문서를 먼저 고친다.
4. **용어는 `GLOSSARY.md`를 따른다**(생기면). 결정과 이유는 `docs/adr/`에 남긴다.

## 검증 명령

<코드가 생기면 채운다. 예: `pnpm test`(단위), `pnpm typecheck`(타입), `pnpm lint`>

## 지킬 것

- 확인받고 하는 일은 [CONTRIBUTING.md](CONTRIBUTING.md)다.
- 이 프로젝트에서 더 지킬 것은 [docs/project.md](docs/project.md) 7절이다.
- 단계가 끝나면 README의 "상태" 줄을 다음 단계로 고친다.

## 문서 지도

주제를 다루는 문서가 있으면 먼저 읽고 따른다. "틀"은 dev-env가, "스튜디오"는 스튜디오가 주인이라 이 저장소에서 고치지 않는다(고칠 일이면 그 저장소에서 고친다).

| 문서 | 주인 | 볼 때 |
|---|---|---|
| [README.md](README.md) | 프로젝트 | 지금 단계, 문서 목록 |
| [docs/project.md](docs/project.md) | 프로젝트 | 이 프로젝트의 값과 규칙, 단계별 스킬 |
| [CONTRIBUTING.md](CONTRIBUTING.md) | 프로젝트 | 하기 전에 확인받는 일 |
| 스튜디오 팀 문서 | 스튜디오 | 일하는 순서·커밋 줄·새 기능 점검표(work), 코드 규칙(code-rules), 서브에이전트(agents), 스킬 지도(skills), 화면·TS·SQL(web). 위치는 세션 시작 때 알림 |
<!-- dev-env:preset-docs -->
| `GLOSSARY.md` | 프로젝트 | 용어(생기면) |
| `docs/adr/` | 프로젝트 | 되돌리기 어려운 결정(생기면) |
