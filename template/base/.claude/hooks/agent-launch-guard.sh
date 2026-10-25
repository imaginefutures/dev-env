#!/usr/bin/env bash
# 서브에이전트를 띄우기 직전(PreToolUse, Agent): 점검과 부하를 보이고, 컴퓨터가 넘쳤을 때·불완전한 지시·고칠 곳이 겹치는 지시를 막는다.
# 본체는 work-guard.py launch다. 이 파일은 이미 깔린 프로젝트의 settings.json 줄을 그대로 쓰려고 남긴다.
exec python3 "$(dirname "$0")/work-guard.py" launch
