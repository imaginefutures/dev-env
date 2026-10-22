# 도구 선택 (TS 웹 서비스)

TS 웹 서비스 묶음이 쓰는 도구다. 고른 기준은 하나다: **기계가 자동으로 막아 주되, 일을 느리게 하지 않는다.** 버전은 dev-env를 고칠 때 npm과 공식 일정에서 확인한 값이다.

## 1. 지금 들어 있는 것

| 파일 | 하는 일 |
|---|---|
| `mise.toml` | Node·pnpm 버전을 고정한다. `mise install` 한 번으로 같은 버전이 깔린다 |
| `compose.yaml` | Postgres를 `docker compose up -d` 한 번으로 띄운다. `127.0.0.1`에만 열린다. 포트는 `.env`의 `DB_PORT` |
| `.env.example` | 환경 변수 목록. 복사해서 `.env`를 만든다 |

## 2. 코드 뼈대를 만들 때 깔 것

뼈대를 처음 만드는 날 한 번에 깔고, 설정을 실제로 돌려 본 뒤 dev-env에도 올린다.

| 할 일 | 도구 | 고른 이유 | 버린 대안 |
|---|---|---|---|
| 실행 | Node 26(LTS, 2029-04까지), 빌드 없이 TS 실행(타입 지우기) | 부품이 하나 준다 | tsx·tsc 빌드: 단계가 하나 는다 |
| 타입 | TypeScript 7 | 이전보다 8~12배 빠르고 strict가 기본 | 6.x: 느리다 |
| 패키지 | pnpm 12 | package.json에 없는 패키지 import를 막고, 새로 올라온 버전은 하루 기다린다 | npm: 그런 기본값이 없다 |
| 구조 | package.json 하나, 폴더로 층을 나눈다 | 설정이 하나 | workspace: 패키지마다 설정이 는다 |
| 마이그레이션 | dbmate(순수 SQL) | 파일 하나 = 트랜잭션 하나, `schema.sql`로 구조 변화가 리뷰에 보인다 | ORM 마이그레이션: 스키마 주인이 둘이 된다 |
| DB 접근 | Kysely + kysely-codegen | DB에서 타입을 만들어 DB가 사실의 주인이 된다. 뷰도 타입이 생긴다 | Drizzle·Prisma: 스키마를 코드로 다시 쓴다 |
| 입구 검사 | Zod 4 | 서버·화면이 같은 스키마를 쓴다 | Valibot: 덜 알려졌다 |
| 테스트 | Vitest 5 + Playwright | 서버·화면을 한 러너로, TS를 그대로 읽는다 | node:test: 화면 테스트가 약해 러너가 둘이 된다 |
| lint | oxlint + oxlint-tsgolint | 타입까지 보면서 빠르다. anti-slop 플러그인도 oxlint용 | ESLint: 느리고 TS 7을 아직 못 쓴다 |
| 포맷 | Prettier 3 | 가장 널리 쓰인다 | oxfmt: 아직 beta(호환되니 나중에 바꾸기 쉽다) |
| 층·입구 검사 | dependency-cruiser(`parser: "swc"`) | 부르는 방향과 "입구 파일만"을 막는다 | 손 검토 |
| 안 쓰는 코드 | knip 6 | 남은 파일·export·의존을 찾는다 | – |
| 사실의 주인·복사 금지 | Vitest 테스트로 직접 | 맞는 도구가 없다 | – |
| git 훅 | lefthook | 파일 하나, 병렬, 바뀐 파일만 | husky: 셸 파일이 여러 개 |
| 비밀값 | gitleaks(커밋 전) | 키·토큰이 커밋되기 전에 막는다 | – |
| CI | GitHub Actions 파일 하나, job 둘(검사 / DB 붙인 테스트) | action은 커밋 SHA로 고정 | – |
| 의존 갱신 | Dependabot(묶어서, 대기 기간 기본) | GitHub에 들어 있다 | Renovate: 앱과 설정이 더 든다 |
| 로그 | pino(JSON 한 줄) | 모든 줄에 요청 id를 남긴다 | – |

속도 기준:

- 커밋 전 훅은 **바뀐 파일만** 본다(gitleaks, 포맷, lint). 1~2초 안.
- push 전 훅은 타입 검사와 빠른 단위 테스트만. 30초 안.
- DB 테스트와 e2e는 CI에서 돈다. 로컬은 필요할 때만.
- Claude Code 훅은 고친 파일 하나만 lint·포맷한다. 전체 테스트를 매번 거는 훅은 두지 않는다.

## 3. 넣지 않는 것

| 것 | 이유 |
|---|---|
| devcontainer | 컴퓨터 한 대에서 일하고, 에이전트가 호스트에서 돈다 |
| 에러 추적(Sentry) | 첫 배포 때 넣는다. 전화번호 같은 개인정보는 보내기 전에 지운다 |
| mutation 테스트 | 규칙 파일에만 가끔 손으로. CI에 넣으면 느리다 |
| 전체 coverage 기준 | 규칙 폴더에만 기준을 둔다 |
| 커밋 형식 강제(Conventional Commits) | CONTRIBUTING의 `문서:`·`검증:` 줄로 충분하다 |
| Postgres·브라우저 MCP | `psql`과 Playwright CLI로 충분하다. 옛 Postgres MCP는 읽기 전용이 뚫리는 문제가 있었다 |
| 리뷰·테스트 전용 서브에이전트 | 기본 `/code-review`와 `tdd` 스킬과 겹친다 |
| 모델 추천 훅, 지시 기록 훅 | 매 요청 소음이다 |
