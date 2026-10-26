#!/usr/bin/env bash
# setup.sh --into를 이미 있는 TS 프로젝트에 돌려, 프로젝트 파일을 덮지 않고 빠진 것만 더하는지 본다.
# 임시 폴더에서만 돈다. 실행: tests/setup.sh   (실패가 있으면 exit 1)
set -u
HERE="$(cd "$(dirname "$0")/.." && pwd)"
T="$(mktemp -d "${TMPDIR:-/tmp}/dev-env-setup.XXXXXX")"
trap 'rm -rf "$T"' EXIT
fail=0
check() { # check <이름> <조건 결과 0/1>
  if [ "$2" = 0 ]; then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi
}

echo "# package.json 합치기, 프로젝트 파일, 뼈대"
P="$T/proj"
mkdir -p "$P/src"
cat >"$P/package.json" <<'EOF'
{
  "name": "proj",
  "scripts": {
    "test": "vitest run",
    "check": "pnpm test"
  },
  "devDependencies": {
    "vitest": "4.0.0"
  }
}
EOF
echo '{ "rules": {} }' >"$P/.oxlintrc.json"
out="$("$HERE/setup.sh" --into "$P" --no-graphify 2>&1)"
pkg() { python3 -c 'import json,sys; d=json.load(open(sys.argv[1])); print(d.get(sys.argv[2], {}).get(sys.argv[3], ""))' "$P/package.json" "$1" "$2"; }
check "있는 script·버전은 그대로" "$([ "$(pkg scripts test)" = "vitest run" ] && [ "$(pkg scripts check)" = "pnpm test" ] && [ "$(pkg devDependencies vitest)" = "4.0.0" ] && echo 0 || echo 1)"
check "빠진 script·devDependency는 더함" "$([ "$(pkg scripts knip)" = knip ] && [ -n "$(pkg devDependencies oxlint)" ] && echo 0 || echo 1)"
check "더한 이름을 알림(있던 것은 안 적음)" "$(printf '%s' "$out" | grep -q 'package.json(더함: .*scripts.knip' && ! printf '%s' "$out" | grep -q 'scripts.check' && echo 0 || echo 1)"
check "있는 검사 설정은 덮지 않음" "$([ "$(cat "$P/.oxlintrc.json")" = '{ "rules": {} }' ] && echo 0 || echo 1)"
check "없는 검사 설정은 만듦" "$([ -f "$P/.dependency-cruiser.cjs" ] && [ -f "$P/quality/layers.json" ] && echo 0 || echo 1)"
check "src/가 있으면 뼈대 코드를 깔지 않음" "$([ ! -e "$P/src/app/client.ts" ] && [ ! -e "$P/web" ] && echo 0 || echo 1)"
before="$(cat "$P/package.json")"
"$HERE/setup.sh" --into "$P" --no-graphify >/dev/null 2>&1
check "다시 돌려도 package.json이 그대로" "$([ "$(cat "$P/package.json")" = "$before" ] && echo 0 || echo 1)"

exit "$fail"
