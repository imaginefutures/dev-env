# dev-env

새 프로젝트의 **프로젝트 환경** 틀이다. 받아서 `./setup.sh` 한 번이면 문서 뼈대, 안전 설정, 저장소 장치, 실행 환경이 깔린다.

어떻게 개발하는지(일하는 법, 코드 규칙, 팀 원칙, 스킬, 팀 규칙 훅)는 여기 없다. 개발 스튜디오(`hack-collaboration-studio`)의 플러그인 `studio`가 맡고, `setup.sh`가 그 플러그인을 프로젝트에 켠다.

목표는 **빅테크 상위 개발자들과 일하는 수준이되 가볍게**다. 기계가 자동으로 막아 주는 장치는 넣고, 일을 느리게 하거나 사람이 손으로 돌려야 하는 절차는 넣지 않는다.

## 프로젝트를 시작하는 순서

1. 폴더를 만든다(아래 "새 프로젝트 시작").
2. dev-env를 깐다(`./setup.sh`). 스튜디오 플러그인도 이때 켜진다.
3. 스튜디오에서 그 폴더를 연결한다.
4. 개발을 시작한다. VS Code에서 그 폴더를 열어 Claude를 써도 같은 팀 문서·스킬·훅이 붙는다.

## 컴퓨터에 한 번

| 도구 | 깔기 | 쓰는 곳 |
|---|---|---|
| git, python3, gh | macOS 기본 + `brew install gh` 뒤 `gh auth login`. SSH 키가 다른 GitHub 계정에 묶여 있으면 `gh config set git_protocol https` | setup.sh, 저장소 만들기 |
| 스튜디오 플러그인 | 스튜디오 저장소를 받은 뒤 `claude plugin marketplace add <스튜디오 폴더>` | 공통 개발 환경 |
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

다시 돌리면 틀 파일이 최신으로 바뀌고, 예전 틀이 깔아 둔 공통 문서·스킬·훅 사본(지금은 스튜디오 플러그인이 맡는 것)을 걷어낸다. 프로젝트 파일은 건드리지 않는다. 걷어낸 것은 git 변경으로 보이니 확인하고 커밋한다.

## 두 겹

| 겹 | 폴더 | 들어 있는 것 |
|---|---|---|
| 기본(모든 프로젝트) | `template/base/` | `CLAUDE.md`·`README.md` 뼈대, `docs/project.md`(빈 양식), `CONTRIBUTING.md`(확인받고 하는 일), `.claude/settings.json`(`.env` 읽기 금지, push는 물어보기, 스튜디오 플러그인 켜기), 저장소 폴더 지키기 훅, `scripts/git/ship.sh`·`sync-root.sh`, `scripts/heavy/slot.sh`, `.gitignore`, `.editorconfig` |
| TS 웹 서비스 | `template/ts-web/` | `docs/stack.md`(도구 선택과 속도 기준), `mise.toml`(Node 26, pnpm 12), `compose.yaml`(Postgres 18), `.env.example`, `scripts/heavy/vitest.sh` |

## 파일 주인

| 주인 | 파일 | setup.sh가 하는 일 |
|---|---|---|
| 틀 | `docs/stack.md`, `.editorconfig`, `.claude/hooks/worktree-guard.sh`, `scripts/heavy/slot.sh`·`vitest.sh`(TS 웹), `scripts/git/ship.sh`·`sync-root.sh` | 항상 덮어쓴다 |
| 프로젝트 | `CLAUDE.md`, `README.md`, `CONTRIBUTING.md`, `docs/project.md`, `mise.toml`, `compose.yaml`, `.env.example` | 없을 때만 만든다 |
| 합침 | `.gitignore`, `.claude/settings.json`, `CLAUDE.md`의 묶음 문서 줄 | 빠진 것만 더한다 |

틀 파일을 고칠 일이면 프로젝트가 아니라 이 저장소에서 고치고, 프로젝트마다 `setup.sh --into`를 다시 돌린다. 프로젝트에만 맞는 값은 그 프로젝트의 `docs/project.md`에 쓴다. 공통 개발 규칙은 스튜디오 저장소의 `plugin/`에서 고친다.

## 아직 넣지 않은 것

lint·포맷·타입·git 훅·CI 설정 파일은 넣지 않았다. 실제 코드에서 돌려 보지 않은 설정을 틀에 넣으면 프로젝트마다 깨진 채 복사된다. 첫 프로젝트가 코드 뼈대를 만들 때 `docs/stack.md` 2절대로 깔고 돌려 본 뒤, 그 설정을 이 틀에 올린다.

## dev-env를 고칠 때

규칙을 더하거나 바꾸기 전에 스튜디오 `plugin/meta/GOVERNANCE.md`를 먼저 읽는다(규칙 관리 기록은 스튜디오 한 곳에 둔다). 틀 훅(`template/base/.claude/hooks/`)이나 `template/*/scripts/`를 고치면 `tests/hooks.sh`를 돌린다.

이 저장소는 비공개로 둔다.
