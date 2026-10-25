#!/usr/bin/env bash
# dev-env 틀을 프로젝트에 깐다. 다시 돌리면 틀 문서와 틀 스킬이 최신으로 바뀐다.
#
#   ./setup.sh                    템플릿으로 만든 새 저장소 안에서: 이 폴더에 깔고 setup.sh·template/를 지운다
#   ./setup.sh --into <폴더>      이미 있는 프로젝트에 깔거나 업데이트한다(이 폴더는 그대로 둔다)
#   --base                        기본 틀만(TS 웹 서비스 묶음 없이)
#   --no-graphify                 graphify 설치를 건너뛴다
#
# 파일 주인:
#   틀    항상 덮어쓴다      CONTRIBUTING.md, docs/{code-rules,agents,skills,web,stack}.md, .editorconfig, 틀 스킬
#   프로젝트  없을 때만 만든다  CLAUDE.md, README.md, docs/project.md, mise.toml, compose.yaml, .env.example
#   합침   빠진 것만 더한다    .gitignore, .claude/settings.json, skills-lock.json, CLAUDE.md의 묶음 줄
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
import json, os, shutil, sys

target, self_mode, layers = sys.argv[1], sys.argv[2] == "1", sys.argv[3:]
TEMPLATE_OWNED = {"CONTRIBUTING.md", "docs/code-rules.md", "docs/agents.md", "docs/skills.md",
                  "docs/web.md", "docs/stack.md", ".editorconfig",
                  ".claude/hooks/worktree-guard.sh",
                  ".claude/hooks/agent-launch-guard.sh"}
MERGED = {".gitignore", ".claude/settings.json", "skills-lock.json"}
SPECIAL = {"CLAUDE.preset.md", "CLAUDE.antislop.md"}
report = {"새로 만듦": [], "틀로 바꿈": [], "합침": [], "그대로 둠(프로젝트 파일)": []}

def rel_files(layer):
    for root, dirs, files in os.walk(layer):
        dirs[:] = [d for d in dirs if d != "skills"] if os.path.relpath(root, layer) == ".claude" else dirs
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

for layer in layers:
    # 틀 스킬: 폴더째 바꾼다.
    sk = os.path.join(layer, ".claude", "skills")
    if os.path.isdir(sk):
        for name in sorted(os.listdir(sk)):
            dst = os.path.join(target, ".claude", "skills", name)
            existed = os.path.exists(dst)
            if existed:
                shutil.rmtree(dst)
            shutil.copytree(os.path.join(sk, name), dst)
            report["틀로 바꿈" if existed else "새로 만듦"].append(f".claude/skills/{name}/")
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
        elif rel == "skills-lock.json":
            a = json.load(open(dst)) if existed else {"version": 1, "skills": {}}
            a.setdefault("skills", {}).update(json.load(open(src))["skills"])
            a["skills"] = dict(sorted(a["skills"].items()))
            json.dump(a, open(dst, "w"), indent=2)
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

    # CLAUDE.md에 묶음 문서 줄과 antislop 블록을 더한다(없을 때만).
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
        anti = os.path.join(layer, "CLAUDE.antislop.md")
        if os.path.exists(anti) and "<!-- antislop:start -->" not in text:
            text = text.rstrip("\n") + "\n" + open(anti).read()
            changed = True
        if changed:
            open(claude, "w").write(text)
            report["합침"].append("CLAUDE.md(묶음 줄)")

for k, v in report.items():
    if v:
        print(f"[{k}] " + ", ".join(dict.fromkeys(v)))
PY

if [[ ! -d "$TARGET/.git" ]]; then
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
  rm -rf "$SRC/template" "$SRC/meta" "$SRC/setup.sh"
  echo "[정리] template/, meta/, setup.sh를 지웠다. 틀을 업데이트할 때는 dev-env의 setup.sh --into 로 돌린다"
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
