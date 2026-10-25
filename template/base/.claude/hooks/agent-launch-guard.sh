#!/usr/bin/env bash
# 서브에이전트를 띄우기 직전(PreToolUse, Agent) docs/agents.md "띄우기 전 점검"을 눈앞에 보인다.
# 원칙 글은 읽어야만 효과가 있고 바쁠 때 안 읽힌다(meta/cases/2026-10-25-unread-orchestration.md). 그래서 띄우는 순간에 보인다.
# 막는 것은 둘이다: 지시가 완결되지 않았을 때(너무 짧거나 채우지 않은 자리표시), 컴퓨터가 이미 넘쳐 있을 때(부하가 코어의 1.5배 초과).
# 부하는 1분·5분 평균 중 낮은 쪽이다: 잠깐 튄 부하에도, 일이 끝난 뒤 남은 평균에도 막지 않는다.
# 부하는 "지금 몇 개가 돌고 있나"를 기계가 볼 수 있는 유일한 값이다. 글로 보이기만 했을 때 12코어에 13개를 띄워 부하 40이 됐다.
# 나머지 판단(범위·순서)은 기계가 못 봐서 보이기만 한다. 훅이 깨져도 일을 막지 않는다.
set -u

input="$(cat)"
printf '%s' "$input" | python3 -c '
import json, os, re, sys

REMINDER = (
    "띄우기 전 점검(docs/agents.md): "
    "1) 사용자가 요청한 결과에 필요한 일인가(넓히려면 묻기). "
    "2) 지금 도는 일과 같은 파일·DB·잠금을 쓰는가(겹치면 순서대로). "
    "3) 좁은 자원(컴퓨터·e2e·사람의 판단)에 용량보다 많이 넣고 있지 않은가: 지금 몇 개가 돌고 있나. "
    "4) 일의 무게에 맞는 절차인가(비싼 확인은 모아서 한 번). "
    "5) 끝나면 바로 합칠 단위인가(오래 사는 통합 가지를 쌓지 않는다). "
    "6) 프롬프트에 작업 폴더·바탕·금지·끝 기준·보고 모양과 \"사실로 확인\" 지시가 있는가."
)
MIN_LENGTH = 80
LOAD_PER_CORE = 1.5

try:
    data = json.load(sys.stdin)
    prompt = (data.get("tool_input") or {}).get("prompt") or ""
    text = prompt.strip() if isinstance(prompt, str) else ""
    cores = os.cpu_count() or 1
    load = min(os.getloadavg()[:2])
    reason = None
    if load > cores * LOAD_PER_CORE:
        reason = f"컴퓨터가 넘쳐 있다(부하 {load:.0f}, 코어 {cores}개, 상한 {cores * LOAD_PER_CORE:.0f}). 더 띄우면 모든 일의 검사가 함께 느려진다. 돌고 있는 일이 끝나기를 기다렸다가 띄우거나, 이 일을 끝나는 쪽에 이어 맡긴다."
    elif len(text) < MIN_LENGTH:
        reason = f"지시가 {len(text)}자로 짧다. 목표·범위·건드리면 안 되는 것·끝 기준·확인 방법·보고 모양을 쓰거나, 긴 공통 지시는 파일로 빼고 \"그 파일을 먼저 읽어라\"와 이 일만의 차이를 쓴다."
    elif re.search(r"\{\{[^}\n]{1,60}\}\}", text) or re.fullmatch(r"[A-Z][A-Z0-9_]{5,}", text):
        reason = "지시에 채우지 않은 자리표시가 남아 있다. 실제 내용을 넣어 다시 부른다."
    if reason:
        out = {"hookSpecificOutput": {"hookEventName": "PreToolUse", "permissionDecision": "deny", "permissionDecisionReason": reason + " (docs/agents.md)"}}
    else:
        out = {"hookSpecificOutput": {"hookEventName": "PreToolUse", "additionalContext": REMINDER + f" 지금 부하 {load:.0f}, 코어 {cores}개."}}
    print(json.dumps(out, ensure_ascii=False))
except Exception:
    pass
'
exit 0
