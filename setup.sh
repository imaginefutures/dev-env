#!/usr/bin/env bash
# dev-env 틀(프로젝트 환경)을 프로젝트에 깐다. 다시 돌리면 틀 파일이 최신으로 바뀐다.
# 공통 개발 규칙·스킬·팀 훅은 스튜디오 플러그인이 맡는다. 이 스크립트는 그 플러그인을 켜고, 예전 틀이 깔아 둔 사본을 걷어낸다.
#
#   ./setup.sh                    템플릿으로 만든 새 저장소 안에서: 이 폴더에 깔고 setup.sh·template/를 지운다
#   ./setup.sh --into <폴더>      이미 있는 프로젝트에 깔거나 업데이트한다(이 폴더는 그대로 둔다)
#   --base                        기본 틀만(TS 웹 서비스 묶음 없이)
#   --no-graphify                 graphify 설치를 건너뛴다
#
# 파일 주인:
#   틀    항상 덮어쓴다      docs/stack.md, .editorconfig, .claude/hooks/worktree-guard.sh,
#                            scripts/heavy/{slot,vitest}.sh, scripts/git/{ship,sync-root}.sh
#   프로젝트  없을 때만 만든다  CLAUDE.md, README.md, CONTRIBUTING.md, docs/project.md, mise.toml, compose.yaml, .env.example
#   합침   빠진 것만 더한다    .gitignore, .claude/settings.json, CLAUDE.md의 묶음 줄
#   걷어냄  예전 틀의 사본    스튜디오로 옮긴 문서·스킬·훅(RETIRED), 그 훅 줄, CLAUDE.md의 옛 줄과 antislop 블록
set -euo pipefail

SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET=""
PRESET="ts-web"
GRAPHIFY=1

while [[ $# -gt 0 ]]; do
  case "$1" in
    --into) TARGET="${2:?--into 뒤에 폴더를 준다}"; shift 2 ;;
    --base) PRESET=""; shift ;;
    --no-graphify) GRAPHIFY=0; shift ;;
    -h|--help) sed -n '2,15p' "$0"; exit 0 ;;
    *) echo "모르는 옵션: $1" >&2; exit 2 ;;
  esac
done

SELF=0
if [[ -z "$TARGET" ]]; then
  SELF=1
  TARGET="$SRC"
  # dev-env 원본에서 돌리면 template/이 지워지므로 막는다.
  origin="$(git -C "$SRC" remote get-url origin 2>/dev/null || true)"
  if [[ "$(basename "$SRC")" == "dev-env" || "$origin" == *"/dev-env" || "$origin" == *"/dev-env.git" ]]; then
    echo "여기는 dev-env 원본이다. 새 프로젝트는 템플릿으로 만든 저장소 안에서 돌리거나 --into <폴더>를 쓴다." >&2
    exit 1
  fi
fi

mkdir -p "$TARGET"
TARGET="$(cd "$TARGET" && pwd)"
LAYERS=("$SRC/template/base")
[[ -n "$PRESET" ]] && LAYERS+=("$SRC/template/$PRESET")

for layer in "${LAYERS[@]}"; do
  [[ -d "$layer" ]] || { echo "틀 폴더가 없다: $layer" >&2; exit 1; }
done

python3 - "$TARGET" "$SELF" "${LAYERS[@]}" <<'PY'
import json, os, re, shutil, sys

target, self_mode, layers = sys.argv[1], sys.argv[2] == "1", sys.argv[3:]
TEMPLATE_OWNED = {"docs/stack.md", ".editorconfig",
                  ".claude/hooks/worktree-guard.sh",
                  "scripts/heavy/slot.sh",
                  "scripts/heavy/vitest.sh",
                  "scripts/git/ship.sh",
                  "scripts/git/sync-root.sh"}
MERGED = {".gitignore", ".claude/settings.json"}
SPECIAL = {"CLAUDE.preset.md"}
# 스튜디오 플러그인으로 옮긴 것. 예전 틀이 프로젝트에 깔아 둔 사본을 걷어낸다(두 번 읽히지 않게).
RETIRED_FILES = ["docs/code-rules.md", "docs/agents.md", "docs/skills.md", "docs/web.md",
                 ".claude/hooks/work-guard.py", ".claude/hooks/agent-launch-guard.sh"]
RETIRED_SKILLS = ["antislop", "antislop-code", "antislop-copywriting", "antislop-human", "antislop-layoutmobile",
                  "antislop-ui", "codebase-design", "deprecation-and-migration", "domain-modeling", "fix",
                  "grill-with-docs", "grilling", "karpathy-guidelines", "setup-ts-deep-modules", "tdd"]
RETIRED_HOOKS = ("work-guard.py", "agent-launch-guard.sh")
RETIRED_ROWS = ["| [CONTRIBUTING.md](CONTRIBUTING.md) | 틀 | 일하는 순서, 커밋 줄, 확인받는 일, 새 기능 점검표 |",
                "| [docs/code-rules.md](docs/code-rules.md) | 틀 | 사실의 주인, 부르는 방향, 두 번 돌아도 안전하게, 권한 경계, 테스트 층 |",
                "| [docs/agents.md](docs/agents.md) | 틀 | 서브에이전트로 나눠 일하기 |",
                "| [docs/skills.md](docs/skills.md) | 틀 | 언제 어떤 스킬을 쓰나 |",
                "| [docs/web.md](docs/web.md) | 틀 | 화면 샘플 먼저, 점검표 추가 질문, 타입·SQL DB·테스트 규칙, 화면 스킬 |"]
report = {"새로 만듦": [], "틀로 바꿈": [], "합침": [], "걷어냄(스튜디오로 옮김)": [], "그대로 둠(프로젝트 파일)": []}

def rel_files(layer):
    for root, dirs, files in os.walk(layer):
        for f in files:
            yield os.path.relpath(os.path.join(root, f), layer)

def merge_json_settings(dst, src):
    a = json.load(open(dst)) if os.path.exists(dst) else {}
    b = json.load(open(src))
    for k, v in b.items():
        if k == "permissions":
            p = a.setdefault("permissions", {})
            for kind, rules in v.items():
                cur = p.setdefault(kind, [])
                cur.extend(r for r in rules if r not in cur)
        elif k == "hooks":
            # 훅은 사건(SessionStart 등)마다 틀의 줄을 더한다. 같은 명령이 이미 있으면 두지 않는다.
            h = a.setdefault("hooks", {})
            for event, entries in v.items():
                cur = h.setdefault(event, [])
                have = {x.get("command") for e in cur for x in e.get("hooks", [])}
                cur.extend(e for e in entries if not {x.get("command") for x in e.get("hooks", [])} <= have)
        else:
            a.setdefault(k, v)
    return a

def retire():
    gone = report["걷어냄(스튜디오로 옮김)"]
    for rel in RETIRED_FILES:
        if os.path.isfile(os.path.join(target, rel)):
            os.remove(os.path.join(target, rel))
            gone.append(rel)
    for name in RETIRED_SKILLS:
        d = os.path.join(target, ".claude", "skills", name)
        if os.path.islink(d) or os.path.isfile(d):
            os.remove(d)
            gone.append(f".claude/skills/{name}")
        elif os.path.isdir(d):
            shutil.rmtree(d)
            gone.append(f".claude/skills/{name}/")
    lock = os.path.join(target, "skills-lock.json")
    if os.path.exists(lock):
        a = json.load(open(lock))
        left = {k: v for k, v in a.get("skills", {}).items() if k not in RETIRED_SKILLS}
        if left != a.get("skills", {}):
            if left:
                a["skills"] = left
                json.dump(a, open(lock, "w"), indent=2)
                open(lock, "a").write("\n")
            else:
                os.remove(lock)
            gone.append("skills-lock.json(옮긴 스킬 줄)")
    st = os.path.join(target, ".claude", "settings.json")
    if os.path.exists(st):
        a = json.load(open(st))
        hooks = a.get("hooks", {})
        before = json.dumps(hooks)
        for event in list(hooks):
            hooks[event] = [e for e in hooks[event] if not any(n in x.get("command", "") for x in e.get("hooks", []) for n in RETIRED_HOOKS)]
            if not hooks[event]:
                del hooks[event]
        if json.dumps(hooks) != before:
            json.dump(a, open(st, "w"), ensure_ascii=False, indent=2)
            open(st, "a").write("\n")
            gone.append(".claude/settings.json(팀 훅 줄)")
    claude = os.path.join(target, "CLAUDE.md")
    if os.path.exists(claude):
        text = open(claude).read()
        new = re.sub(r"\n*<!-- antislop:start -->.*?<!-- antislop:end -->\n?", "\n", text, flags=re.S)
        new = "\n".join(l for l in new.split("\n") if l not in RETIRED_ROWS)
        if new != text:
            open(claude, "w").write(new)
            gone.append("CLAUDE.md(옛 문서 줄·antislop 블록)")
    # 예전 틀의 CONTRIBUTING.md(공통 일하는 법 전체)는 틀이 늘 덮어쓰던 파일이라 프로젝트 몫이 없다. 새 양식으로 바꾼다.
    contrib = os.path.join(target, "CONTRIBUTING.md")
    if os.path.exists(contrib) and open(contrib).read().startswith("# 일하는 방법\n") and "## 5. 여러 세션이 같은 저장소를 쓴다" in open(contrib).read():
        os.remove(contrib)
        gone.append("CONTRIBUTING.md(예전 틀, 새 양식으로)")

retire()
for layer in layers:
    for rel in sorted(rel_files(layer)):
        if rel in SPECIAL:
            continue
        src, dst = os.path.join(layer, rel), os.path.join(target, rel)
        os.makedirs(os.path.dirname(dst), exist_ok=True)
        existed = os.path.exists(dst)
        if rel == ".gitignore":
            have = open(dst).read().splitlines() if existed else []
            add = [l for l in open(src).read().splitlines() if l.strip() and l not in have]
            if add or not existed:
                with open(dst, "a") as f:
                    if have and have[-1].strip():
                        f.write("\n")
                    f.write("\n".join(add if existed else open(src).read().splitlines()) + "\n")
            report["합침" if existed else "새로 만듦"].append(rel)
        elif rel == ".claude/settings.json":
            json.dump(merge_json_settings(dst, src), open(dst, "w"), ensure_ascii=False, indent=2)
            open(dst, "a").write("\n")
            report["합침" if existed else "새로 만듦"].append(rel)
        elif rel in TEMPLATE_OWNED:
            shutil.copy2(src, dst)
            report["틀로 바꿈" if existed else "새로 만듦"].append(rel)
        elif existed and not (self_mode and rel == "README.md"):
            report["그대로 둠(프로젝트 파일)"].append(rel)
        else:
            shutil.copy2(src, dst)
            report["새로 만듦"].append(rel)

    # CLAUDE.md에 묶음 문서 줄을 더한다(없을 때만).
    claude = os.path.join(target, "CLAUDE.md")
    if os.path.exists(claude):
        text = open(claude).read()
        changed = False
        preset = os.path.join(layer, "CLAUDE.preset.md")
        marker = "<!-- dev-env:preset-docs -->"
        if os.path.exists(preset):
            rows = [r for r in open(preset).read().splitlines() if r.strip() and r not in text]
            if rows:
                if marker in text:
                    text = text.replace(marker, "\n".join(rows) + "\n" + marker)
                else:
                    text = text.rstrip("\n") + "\n\n## dev-env 묶음 문서\n\n| 문서 | 주인 | 볼 때 |\n|---|---|---|\n" + "\n".join(rows) + "\n"
                changed = True
        if changed:
            open(claude, "w").write(text)
            report["합침"].append("CLAUDE.md(묶음 줄)")

for k, v in report.items():
    if v:
        print(f"[{k}] " + ", ".join(dict.fromkeys(v)))
PY

# 작업 폴더(git worktree)는 .git이 폴더가 아니라 파일이다. 폴더 유무가 아니라 git에 물어 이미 저장소인지 본다.
if ! git -C "$TARGET" rev-parse --git-dir >/dev/null 2>&1; then
  git -C "$TARGET" init -q -b main && echo "[git] 새 저장소를 만들었다(main)"
fi

if [[ "$GRAPHIFY" == 1 ]]; then
  if command -v graphify >/dev/null 2>&1; then
    (cd "$TARGET" && graphify install --project >/dev/null) && echo "[graphify] 프로젝트에 깔았다"
    rm -f "$TARGET/.claude/settings.json.graphify-bak"
  else
    echo "[graphify] 실행 프로그램이 없어 건너뛰었다. 깔려면: uv tool install \"graphifyy[sql]\" 뒤 setup.sh를 다시 돌린다"
  fi
fi

if [[ "$SELF" == 1 ]]; then
  rm -rf "$SRC/template" "$SRC/tests" "$SRC/setup.sh"
  echo "[정리] template/, tests/, setup.sh를 지웠다. 틀을 업데이트할 때는 dev-env의 setup.sh --into 로 돌린다"
fi

# 공통 개발 환경(팀 문서·스킬·팀 훅)은 스튜디오 플러그인이다. settings.json이 켜고, 여기서 이 프로젝트에 설치해 둔다.
if command -v claude >/dev/null 2>&1 && grep -q '"hack-collaboration-studio"' "$HOME/.claude/plugins/known_marketplaces.json" 2>/dev/null; then
  (cd "$TARGET" && claude plugin install studio@hack-collaboration-studio --scope project >/dev/null 2>&1) \
    && echo "[스튜디오] 플러그인을 이 프로젝트에 켰다" || echo "[스튜디오] 플러그인 설치 실패: 이 폴더에서 claude plugin install studio@hack-collaboration-studio --scope project"
else
  echo "[스튜디오] 스튜디오 마켓을 모른다. 한 번만: claude plugin marketplace add <스튜디오 폴더> 뒤 setup.sh를 다시 돌린다"
fi

missing=()
for c in git python3 gh; do command -v "$c" >/dev/null 2>&1 || missing+=("$c"); done
if [[ -n "$PRESET" ]]; then
  command -v mise >/dev/null 2>&1 || missing+=("mise")
  docker compose version >/dev/null 2>&1 || missing+=("docker compose")
fi
[[ ${#missing[@]} -gt 0 ]] && echo "[주의] 이 컴퓨터에 없는 도구: ${missing[*]} (dev-env README '컴퓨터에 한 번')"

cat <<EOF

다음 할 일:
  1. CLAUDE.md, README.md, docs/project.md의 <...>를 채운다
$( [[ -n "$PRESET" ]] && echo "  2. mise install && cp .env.example .env && docker compose up -d" )
EOF
