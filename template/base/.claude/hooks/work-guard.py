#!/usr/bin/env python3
"""여러 도우미(서브에이전트)가 같은 저장소에서 동시에 일할 때 부딪히지 않게 막는 훅.

글로 적은 지휘 원칙은 바쁠 때 안 지켜진다(meta/cases/2026-10-25-parallel-helpers-collide.md). 그래서 순간마다 기계가 본다.

  launch    PreToolUse(Agent): 띄우기 전 점검과 지금 부하를 보이고, 컴퓨터가 넘쳐 있을 때(부하가 코어의 1.5배 초과),
            불완전한 지시, "고칠 곳"이 다른 일과 겹치는 지시를 막는다.
            코드를 고치는 지시는 `가지: <가지>`와 `고칠 곳: <경로, 경로>` 줄을 쓴다(읽기·샘플만이면 `고칠 곳: 없음`).
            겹침은 (가) 다른 작업 폴더에서 실제로 바뀐 파일, (나) 아직 합쳐지지 않은 다른 맡김과 견준다.
            맡김은 $(git rev-parse --git-common-dir)/work-claims/<가지>에 훅만 쓴다. 알고도 띄우려면 `겹침 허락: <까닭>`.
  handback  PreToolUse(SubagentHandback)·SubagentStop: 도우미가 보고하기 전에 바탕(origin/main, 맡긴 쪽 가지)의 최신을
            자기 가지에 한 번 합치게 한다. 충돌은 맥락이 있는 도우미가 푼다. 못 합치면 보고에 `바탕 못 합침: <까닭>`.
  scratch   PreToolUse(Write·Edit·NotebookEdit·Bash): 도우미는 세션 scratchpad 맨 위나 다른 도우미의 칸에 쓰지 않는다.
            scratchpad/<이름>/에 처음 쓴 도우미가 그 칸의 주인이 된다(scratchpad/.owners/<이름>).

훅이 깨져도 일을 막지 않는다(예외는 삼키고 통과).
"""
import json
import os
import re
import subprocess
import sys
import time
from concurrent.futures import ThreadPoolExecutor

REMINDER = (
    "띄우기 전 점검(docs/agents.md): "
    "1) 사용자가 요청한 결과에 필요한 일인가(넓히려면 묻기). "
    "2) 고칠 곳 겹침은 훅이 `가지:`·`고칠 곳:` 줄로 살아 있는 가지·맡김과 견준다. DB·포트·잠금 겹침은 직접 본다. "
    "3) 사람의 판단도 좁은 자원이다: 결정을 기다리는 일을 몇 개 쌓고 있나(e2e·전체 시험은 scripts/heavy/slot.sh가 자리 수만큼만 돌린다). "
    "4) 일의 무게에 맞는 절차인가(비싼 확인은 모아서 한 번). "
    "5) 끝나면 바로 합칠 단위인가(오래 사는 통합 가지를 쌓지 않는다). "
    "6) 프롬프트에 작업 폴더·바탕·금지·끝 기준·보고 모양과 \"사실로 확인\" 지시가 있는가."
)
MIN_LENGTH = 80
# 컴퓨터가 이미 넘쳐 있으면 더 띄우지 않는다. 1분·5분 평균 중 낮은 쪽이라 잠깐 튄 부하에도, 끝난 뒤 남은 평균에도 막지 않는다.
LOAD_PER_CORE = float(os.environ.get("DEV_ENV_LOAD_PER_CORE", "1.5"))  # 시험에서만 바꾼다
# 고치는 도구 없이 도는 내장 에이전트. 프로젝트 에이전트는 .claude/agents/<이름>.md의 tools 줄로 본다.
READ_ONLY_TYPES = {"Explore", "Plan", "claude-code-guide", "statusline-setup"}
WRITE_TOOLS = re.compile(r"\b(Edit|Write|NotebookEdit|MultiEdit)\b")
FIELD = re.compile(r"^[\s>*\-•`]*(가지|고칠 곳|겹침 허락|바탕 못 합침)\s*[:：]\s*(.*?)[\s`]*$", re.M)
UNCLAIMED_GRACE = 2 * 3600  # 맡긴 뒤 가지가 아직 안 생긴 맡김을 살아 있다고 보는 시간
IDLE_GRACE = 24 * 3600  # 가지는 생겼는데 커밋이 하나도 없는 맡김


def emit(obj):
    print(json.dumps(obj, ensure_ascii=False))


def pretool(decision=None, reason=None, context=None):
    out = {"hookEventName": "PreToolUse"}
    if decision:
        out["permissionDecision"] = decision
        out["permissionDecisionReason"] = reason
    if context:
        out["additionalContext"] = context
    emit({"hookSpecificOutput": out})


def git(cwd, *args, ok_codes=(0,)):
    """git을 부르고 표준 출력을 돌려준다. 실패하면 None. 남의 작업 폴더의 색인을 잠그지 않는다."""
    try:
        p = subprocess.run(
            ["git", "--no-optional-locks", "-C", cwd, *args],
            capture_output=True,
            text=True,
            timeout=10,
        )
    except Exception:
        return None
    return p.stdout if p.returncode in ok_codes else None


def is_ancestor(cwd, a, b):
    try:
        return subprocess.run(["git", "-C", cwd, "merge-base", "--is-ancestor", a, b], capture_output=True, timeout=10).returncode == 0
    except Exception:
        return False


def fields_of(text):
    found = {}
    for key, value in FIELD.findall(text or ""):
        found.setdefault(key, value.strip())
    return found


def split_paths(value, top):
    """`고칠 곳:` 값을 경로 목록으로. "없음"이면 빈 목록."""
    if value is None:
        return None
    if value.startswith("없음"):
        return []
    paths = []
    for raw in re.split(r"[,、]", value):
        p = raw.strip().strip("`'\"").strip()
        p = re.sub(r"\s*\(.*\)$", "", p)  # "web/x.ts(상품 블록)" 같은 설명을 뗀다
        if not p:
            continue
        if top and p.startswith(top.rstrip("/") + "/"):
            p = p[len(top.rstrip("/")) + 1 :]
        if p.startswith("./"):
            p = p[2:]
        paths.append(p)
    return paths


# --- 경로 겹침: 정확한 경로, 폴더(밑의 모든 것), 글롭(*, **, ?) ---
GLOB_CHAR = re.compile(r"[*?\[]")


def glob_regex(pattern):
    out, i = "", 0
    while i < len(pattern):
        c = pattern[i]
        if pattern.startswith("**/", i):
            out, i = out + "(?:.*/)?", i + 3
        elif pattern.startswith("**", i):
            out, i = out + ".*", i + 2
        elif c == "*":
            out, i = out + "[^/]*", i + 1
        elif c == "?":
            out, i = out + "[^/]", i + 1
        else:
            out, i = out + re.escape(c), i + 1
    return re.compile(out.rstrip("/") + "(?:/.*)?")


def overlaps(a, b):
    """두 경로·글롭이 같은 파일을 가리킬 수 있으면 참. 글롭끼리는 앞쪽 글자 부분으로 넉넉히 본다."""
    ga, gb = bool(GLOB_CHAR.search(a)), bool(GLOB_CHAR.search(b))
    if not ga and not gb:
        a, b = a.rstrip("/"), b.rstrip("/")
        return a == b or a.startswith(b + "/") or b.startswith(a + "/")
    if ga and gb:
        pa, pb = GLOB_CHAR.split(a)[0], GLOB_CHAR.split(b)[0]
        return pa.startswith(pb) or pb.startswith(pa)
    lit, pat = (a, b) if gb else (b, a)
    lit = lit.rstrip("/")
    prefix = GLOB_CHAR.split(pat)[0]
    return bool(glob_regex(pat).fullmatch(lit)) or prefix.startswith(lit + "/")


# --- 저장소 사정 ---
def worktrees(cwd):
    text = git(cwd, "worktree", "list", "--porcelain") or ""
    result = []
    for block in text.strip().split("\n\n"):
        wt = {}
        for line in block.splitlines():
            key, _, value = line.partition(" ")
            wt[key] = value
        if "worktree" in wt and "prunable" not in wt:
            wt["branch"] = wt.get("branch", "").removeprefix("refs/heads/")
            result.append(wt)
    return result


def default_ref(cwd):
    head = (git(cwd, "symbolic-ref", "-q", "refs/remotes/origin/HEAD", ok_codes=(0, 1)) or "").strip()
    for ref in [head, "refs/remotes/origin/main", "refs/remotes/origin/master", "refs/heads/main", "refs/heads/master"]:
        if ref and git(cwd, "rev-parse", "--verify", "-q", ref):
            return ref
    return None


def short(ref):
    return re.sub(r"^refs/(heads|remotes)/", "", ref)


def common_dir(cwd):
    d = (git(cwd, "rev-parse", "--git-common-dir") or "").strip()
    return os.path.normpath(os.path.join(cwd, d)) if d else None


def changed_files(wt_path, known):
    """작업 폴더의 가지에만 있는 커밋이 바꾼 파일 + 아직 커밋하지 않은 파일.
    known(맡기는 쪽 HEAD, origin/main)에 이미 있는 커밋은 빼서, 바탕을 받아 합친 것을 그 가지의 일로 보지 않는다."""
    files = set()
    log = git(wt_path, "log", "--no-renames", "--name-only", "--format=", "HEAD", "--not", *[r for r in known if r]) or ""
    files.update(f for f in log.splitlines() if f)
    status = git(wt_path, "status", "--porcelain", "--no-renames", "-z") or ""
    files.update(entry[3:] for entry in status.split("\0") if len(entry) > 3)
    return files


def read_claims(common):
    root = os.path.join(common, "work-claims")
    claims = []
    for dirpath, _, names in os.walk(root):
        for name in names:
            path = os.path.join(dirpath, name)
            try:
                claim = json.load(open(path))
            except Exception:
                continue
            claim["file"] = path
            claim["branch"] = os.path.relpath(path, root)
            claims.append(claim)
    return claims


def claim_active(cwd, claim, refs):
    tip = (git(cwd, "rev-parse", "--verify", "-q", "refs/heads/" + claim["branch"]) or "").strip()
    age = time.time() - float(claim.get("created", 0))
    if not tip:
        return age < UNCLAIMED_GRACE
    base = claim.get("base_sha")
    if base and is_ancestor(cwd, tip, base):
        return age < IDLE_GRACE
    return not any(is_ancestor(cwd, tip, r) for r in refs if r)


# --- launch ---
def read_only_agent(kind, top):
    if kind in READ_ONLY_TYPES:
        return True
    for d in [os.environ.get("CLAUDE_PROJECT_DIR"), top]:
        if not d or not kind:
            continue
        path = os.path.join(d, ".claude", "agents", kind + ".md")
        if os.path.exists(path):
            head = open(path).read().split("---")
            front = head[1] if len(head) > 2 else ""
            tools = re.search(r"^tools\s*:(.*)$", front, re.M)
            return bool(tools) and not WRITE_TOOLS.search(tools.group(1))
    return False


def launch(data):
    ti = data.get("tool_input") or {}
    prompt = ti.get("prompt") if isinstance(ti.get("prompt"), str) else ""
    text = prompt.strip()
    cores = os.cpu_count() or 1
    load = min(os.getloadavg()[:2])
    reminder = REMINDER + f" 지금 부하 {load:.0f}, 코어 {cores}개."
    if load > cores * LOAD_PER_CORE:
        return pretool("deny", f"컴퓨터가 넘쳐 있다(부하 {load:.0f}, 코어 {cores}개, 상한 {cores * LOAD_PER_CORE:.0f}). 더 띄우면 모든 일의 검사가 함께 느려진다. 돌고 있는 일이 끝나기를 기다렸다가 띄우거나, 이 일을 끝나는 쪽에 이어 맡긴다. (docs/agents.md)")
    if len(text) < MIN_LENGTH:
        return pretool("deny", f"지시가 {len(text)}자로 짧다. 목표·범위·건드리면 안 되는 것·끝 기준·확인 방법·보고 모양을 쓰거나, 긴 공통 지시는 파일로 빼고 \"그 파일을 먼저 읽어라\"와 이 일만의 차이를 쓴다. (docs/agents.md)")
    if re.search(r"\{\{[^}\n]{1,60}\}\}", text) or re.fullmatch(r"[A-Z][A-Z0-9_]{5,}", text):
        return pretool("deny", "지시에 채우지 않은 자리표시가 남아 있다. 실제 내용을 넣어 다시 부른다. (docs/agents.md)")

    cwd = data.get("cwd") or os.getcwd()
    top = (git(cwd, "rev-parse", "--show-toplevel") or "").strip()
    if read_only_agent(ti.get("subagent_type") or "", top):
        return pretool(context=reminder)
    f = fields_of(text)
    paths = split_paths(f.get("고칠 곳"), top)
    if paths is None:
        return pretool("deny", "고치는 일을 맡기는 지시에는 `가지: <가지 이름>`과 `고칠 곳: <경로, 폴더/, 글롭>` 줄을 넣는다(훅이 다른 일과 겹치는지 견준다). 읽기·샘플·조사만이면 `고칠 곳: 없음`. (docs/agents.md 원칙 4)")
    if not paths or not top:
        return pretool(context=reminder)
    branch = f.get("가지", "").strip("`'\" ")
    if not branch:
        return pretool("deny", "`고칠 곳:`을 적었으면 도우미가 만들 가지도 `가지: <가지 이름>`으로 적는다(맡김을 가지로 기록한다). (docs/agents.md 원칙 4)")

    common = common_dir(cwd)
    head = (git(cwd, "rev-parse", "HEAD") or "").strip()
    main_ref = default_ref(cwd)
    hits = {}  # 가지 → (어디서, 겹친 파일)

    others = [w for w in worktrees(cwd) if os.path.realpath(w["worktree"]) != os.path.realpath(top) and w.get("branch") != branch and w.get("branch")]
    claims = [c for c in read_claims(common) if c["branch"] != branch] if common else []
    with ThreadPoolExecutor(max_workers=8) as pool:
        changes = list(pool.map(lambda w: changed_files(w["worktree"], [head, main_ref]), others))
        alive = list(pool.map(lambda c: claim_active(cwd, c, [main_ref, head]), claims))
    for w, files in zip(others, changes):
        hit = sorted(x for x in files if any(overlaps(x, p) for p in paths))
        if hit:
            hits.setdefault(w["branch"], ("작업 폴더에서 바뀜", hit))
    for c, live in zip(claims, alive):
        if not live:
            try:
                os.remove(c["file"])
            except OSError:
                pass
            continue
        hit = sorted(p for p in c.get("paths", []) if any(overlaps(p, q) for q in paths))
        if hit and c["branch"] not in hits:
            hits[c["branch"]] = ("맡긴 고칠 곳", hit)

    parts = [f"{b}({where}): {', '.join(files[:6])}{' 외' if len(files) > 6 else ''}" for b, (where, files) in hits.items()]
    summary = "; ".join(parts[:8]) + (f"; 그 밖에 가지 {len(parts) - 8}개" if len(parts) > 8 else "")
    allow = f.get("겹침 허락")
    if hits and not allow:
        return pretool("deny", f"막음: 고칠 곳이 다른 일과 겹친다 — {summary}. 그 가지가 합쳐진 뒤 띄우거나, 겹치는 일을 한 도우미에게 순서대로 맡긴다. 알고도 띄우려면 `겹침 허락: <까닭>` 줄을 넣는다. (docs/agents.md 원칙 4)")

    if common:
        claim_path = os.path.join(common, "work-claims", branch)
        os.makedirs(os.path.dirname(claim_path), exist_ok=True)
        base_branch = (git(cwd, "symbolic-ref", "-q", "--short", "HEAD", ok_codes=(0, 1)) or "").strip()
        claim = {"paths": paths, "base_sha": head, "base_branch": base_branch, "created": time.time()}
        if allow:
            claim["overlap_allowed"] = allow
        json.dump(claim, open(claim_path, "w"), ensure_ascii=False)
    note = f" 겹침을 알고 띄움({allow}): {summary}." if hits else ""
    return pretool(context=reminder + note)


# --- handback ---
def dispatch_prompt(transcript):
    """도우미 대화 기록에서 맡긴 지시를 찾는다: `가지:`·`고칠 곳:` 줄이 있는 첫 사람 쪽 글(포크는 앞 대화를 물려받는다)."""
    first = ""
    try:
        with open(transcript) as fh:
            for line in fh:
                if '"user"' not in line:
                    continue
                entry = json.loads(line)
                if entry.get("type") != "user":
                    continue
                content = (entry.get("message") or {}).get("content")
                if isinstance(content, list):
                    content = "\n".join(b.get("text", "") for b in content if isinstance(b, dict) and b.get("type") == "text")
                if not isinstance(content, str) or not content:
                    continue
                first = first or content
                if FIELD.search(content):
                    return content
    except Exception:
        pass
    return first


def agent_transcript(data, agent):
    path = data.get("agent_transcript_path")
    if path:
        return path
    main = data.get("transcript_path") or ""
    if os.path.basename(main).startswith("agent-"):
        return main
    return os.path.join(main.removesuffix(".jsonl"), "subagents", f"agent-{agent}.jsonl") if main else ""


def handback(data):
    agent = data.get("agent_id")
    if not agent:
        return
    event = data.get("hook_event_name") or ""
    if event == "SubagentStop" and data.get("stop_hook_active"):
        return  # 한 번 알렸다. 되풀이해 막지 않는다.
    report = ((data.get("tool_input") or {}).get("message")) or ""
    if fields_of(report).get("바탕 못 합침"):
        return

    transcript = agent_transcript(data, agent)
    meta = {}
    try:
        meta = json.load(open(transcript.removesuffix(".jsonl") + ".meta.json"))
    except Exception:
        pass
    declared = fields_of(dispatch_prompt(transcript)).get("가지", "").strip("`'\" ")
    cwd = data.get("cwd") or os.getcwd()
    wt = meta.get("worktreePath")
    if not wt and declared:
        wt = next((w["worktree"] for w in worktrees(cwd) if w.get("branch") == declared), None)
    if not wt or not os.path.isdir(wt):
        return
    branch = (git(wt, "symbolic-ref", "-q", "--short", "HEAD", ok_codes=(0, 1)) or "").strip()
    main_ref = default_ref(wt)
    if not branch or not main_ref or branch == short(main_ref).split("/")[-1]:
        return

    claim = {}
    common = common_dir(wt)
    for name in [declared, branch]:
        try:
            claim = json.load(open(os.path.join(common, "work-claims", name)))
            break
        except Exception:
            continue
    required = [main_ref]
    # 맡긴 쪽 가지(예: 통합 가지) 위에서 시작한 도우미면 그 가지의 최신도 받는다.
    base_branch, base_sha = claim.get("base_branch") or "", claim.get("base_sha") or ""
    if (
        base_branch
        and base_branch != branch
        and base_sha
        and is_ancestor(wt, base_sha, "HEAD")
        and git(wt, "rev-parse", "--verify", "-q", "refs/heads/" + base_branch)
    ):
        required.append("refs/heads/" + base_branch)
    # 이 가지에만 있는 커밋이 없으면(읽기만 했거나 아직 시작 전) 합칠 것도 없다.
    if not (git(wt, "rev-list", "-n1", "HEAD", "--not", f"--exclude={branch}", "--branches", "--remotes") or "").strip():
        return
    stale = [short(r) for r in required if not is_ancestor(wt, r, "HEAD")]
    if not stale:
        return
    refs = " ".join(stale)
    msg = (
        f"보고하기 전에 바탕을 한 번 합친다: 가지 {branch}에 {', '.join(stale)}의 최신이 없다. "
        f"`git -C {wt} merge {refs}` → 충돌은 맥락이 있는 지금 푼다 → 바뀐 곳에 닿는 시험만 다시 돌린다 → 커밋하고 보고한다. "
        "합칠 수 없으면 보고에 `바탕 못 합침: <까닭>` 줄을 넣는다. (docs/agents.md 원칙 8)"
    )
    if event == "SubagentStop":
        emit({"decision": "block", "reason": msg})
    else:
        pretool("deny", msg)


# --- scratch ---
REDIRECT = re.compile(r"(?:>>?|\btee\s+(?:-a\s+)?)\s*['\"]?([^\s'\";|&<>()]+)")


def scratch(data):
    agent = data.get("agent_id")
    root = data.get("scratchpad_dir")
    if not agent or not root:
        return
    root = os.path.realpath(root)
    ti = data.get("tool_input") or {}
    if data.get("tool_name") == "Bash":
        targets = REDIRECT.findall(ti.get("command") or "")
    else:
        targets = [ti.get("file_path") or ti.get("notebook_path") or ""]
    for target in targets:
        if not target.startswith("/"):
            continue
        path = os.path.realpath(target)
        if not path.startswith(root + os.sep):
            continue
        rel = os.path.relpath(path, root)
        if os.sep not in rel:
            return pretool("deny", f"scratchpad 맨 위에는 쓰지 않는다(도우미들이 같이 쓰는 자리라 서로 덮어쓴다). 자기 칸 {root}/<일 이름>/ 밑에 쓴다.")
        name = rel.split(os.sep)[0]
        if name == ".owners":
            return pretool("deny", "scratchpad/.owners는 훅이 쓰는 칸 주인 기록이다.")
        owners = os.path.join(root, ".owners")
        os.makedirs(owners, exist_ok=True)
        owner_file = os.path.join(owners, name)
        try:
            fd = os.open(owner_file, os.O_WRONLY | os.O_CREAT | os.O_EXCL)
            os.write(fd, agent.encode())
            os.close(fd)
            continue
        except FileExistsError:
            owner = open(owner_file).read().strip()
        if owner != agent:
            return pretool("deny", f"{root}/{name}/은 다른 도우미의 칸이다. 자기 일 이름으로 새 칸 {root}/<일 이름>/을 쓴다.")


def main():
    mode = sys.argv[1] if len(sys.argv) > 1 else ""
    try:
        data = json.load(sys.stdin)
        {"launch": launch, "handback": handback, "scratch": scratch}[mode](data)
    except Exception:
        pass


if __name__ == "__main__":
    main()
