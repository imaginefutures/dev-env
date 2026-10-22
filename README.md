# dev-env

새 프로젝트의 기본 개발 환경 틀이다. 받아서 `./setup.sh` 한 번이면 일하는 방법, 코드 규칙, Claude Code 스킬과 설정, 저장소 기본 파일이 깔린다.

목표는 **빅테크 상위 개발자들과 일하는 수준이되 가볍게**다. 기계가 자동으로 막아 주는 장치는 넣고, 일을 느리게 하거나 사람이 손으로 돌려야 하는 절차는 넣지 않는다.

## 컴퓨터에 한 번

| 도구 | 깔기 | 쓰는 곳 |
|---|---|---|
| git, python3, gh | macOS 기본 + `brew install gh` 뒤 `gh auth login`. SSH 키가 다른 GitHub 계정에 묶여 있으면 `gh config set git_protocol https` | setup.sh, 저장소 만들기 |
| mise | `brew install mise` 뒤 `~/.zshrc`에 `eval "$(mise activate zsh)"` | TS 웹: Node·pnpm 버전 고정 |
| Docker + compose | Colima를 쓰면 `brew install docker-compose` 뒤 `~/.docker/config.json`의 `cliPluginsExtraDirs`에 `/opt/homebrew/lib/docker/cli-plugins` | TS 웹: 로컬 Postgres |
| graphify(선택) | `uv tool install "graphifyy[sql]"` | 코드 지도 |

`setup.sh`가 끝날 때 빠진 도구를 알려 준다.

## 새 프로젝트 시작

```bash
gh repo create imaginefutures/<새이름> --private --template imaginefutures/dev-env --clone
cd <새이름>
./setup.sh            # TS 웹 서비스면 이대로. 기본 틀만이면 ./setup.sh --base
```

`setup.sh`가 끝나면 `template/`과 `setup.sh`는 지워지고 프로젝트 파일만 남는다. 그다음 `CLAUDE.md`, `README.md`, `docs/project.md`의 `<...>`를 채운다.

## 이미 있는 프로젝트에 깔기·업데이트

```bash
~/Projects/dev-env/setup.sh --into ~/Projects/<프로젝트>          # TS 웹 서비스
~/Projects/dev-env/setup.sh --into ~/Projects/<프로젝트> --base   # 기본 틀만
```

다시 돌리면 틀 문서와 틀 스킬이 최신으로 바뀐다. 프로젝트 파일은 건드리지 않는다.

## 두 겹

| 겹 | 폴더 | 들어 있는 것 |
|---|---|---|
| 기본(모든 프로젝트) | `template/base/` | `CONTRIBUTING.md`(일하는 방법), `docs/code-rules.md`(코드 규칙), `docs/agents.md`(서브에이전트), `docs/skills.md`(스킬 지도), `docs/project.md`(빈 양식), `CLAUDE.md`·`README.md` 뼈대, `.claude/settings.json`(`.env` 읽기 금지, push는 물어보기), `.gitignore`, `.editorconfig`, 스킬 8개 |
| TS 웹 서비스 | `template/ts-web/` | `docs/web.md`(화면 샘플 먼저, 타입·SQL DB·테스트 규칙), `docs/stack.md`(도구 선택과 속도 기준), `mise.toml`(Node 26, pnpm 12), `compose.yaml`(Postgres 18), `.env.example`, 스킬 7개 |

스킬:

- 기본: `karpathy-guidelines`, `grilling`, `grill-with-docs`, `domain-modeling`, `codebase-design`, `tdd`, `deprecation-and-migration`, `fix`. graphify는 실행 프로그램이 있으면 `setup.sh`가 `graphify install --project`로 깐다.
- TS 웹: `antislop` 6개, `setup-ts-deep-modules`.

## 파일 주인

| 주인 | 파일 | setup.sh가 하는 일 |
|---|---|---|
| 틀 | `CONTRIBUTING.md`, `docs/code-rules.md`·`agents.md`·`skills.md`·`web.md`·`stack.md`, `.editorconfig`, 틀 스킬 | 항상 덮어쓴다 |
| 프로젝트 | `CLAUDE.md`, `README.md`, `docs/project.md`, `mise.toml`, `compose.yaml`, `.env.example` | 없을 때만 만든다 |
| 합침 | `.gitignore`, `.claude/settings.json`, `skills-lock.json`, `CLAUDE.md`의 묶음 문서 줄과 antislop 블록 | 빠진 것만 더한다 |

틀 문서를 고칠 일이면 프로젝트가 아니라 이 저장소에서 고치고, 프로젝트마다 `setup.sh --into`를 다시 돌린다. 프로젝트에만 맞는 값은 그 프로젝트의 `docs/project.md`에 쓴다.

## 아직 넣지 않은 것

lint·포맷·타입·git 훅·CI 설정 파일은 넣지 않았다. 실제 코드에서 돌려 보지 않은 설정을 틀에 넣으면 프로젝트마다 깨진 채 복사된다. 첫 프로젝트가 코드 뼈대를 만들 때 `docs/stack.md` 2절대로 깔고 돌려 본 뒤, 그 설정을 이 틀에 올린다.

## 출처

외부 스킬은 원래 저장소에서 복사했고 출처와 해시는 `skills-lock.json`에 있다. mattpocock/skills, addyosmani/agent-skills, miqdadbadjuber/anti-slop은 MIT다. multica-ai/andrej-karpathy-skills는 저장소에 LICENSE 파일이 없다(스킬 파일 머리말에는 MIT라고 적혀 있다). 이 저장소는 비공개로 둔다.
