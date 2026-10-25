# caveman

판정: 안 받음
날짜: 2026-10-25
출처: JuliusBrussee/caveman

이유:
- `/caveman-commit`의 한 줄 커밋은 CONTRIBUTING 3절의 `문서:`·`검증:` 줄 규칙과 부딪힌다(P2).
- 작업 방식 스킬 6개(`lean-build`, `surgical-patch`, `verify-and-stop`, `safe-refactor`, `migration`, `investigate-first`)는 `karpathy-guidelines`·`deprecation-and-migration`·`/fix`와 겹친다.
- `/caveman-review`는 기본 `/code-review`와 겹친다. `/caveman-compress`는 `setup.sh`가 덮어쓰는 틀 문서와 맞지 않는다.
- 줄이는 것은 출력 토큰뿐이다. 자체 측정으로도 "간결하게" 지시보다 중간값 약 3% 더 줄이고, 규칙이 입력 토큰 약 1,160개를 더한다.
- 사용 통계를 기본으로 보낸다.

못 본 것: 한국어 답변에서의 절감량, 설치 후 동작.
다시 심사할 조건: 한국어 절감량이 측정으로 나오고, 커밋 규칙을 깨지 않는 구성이 가능할 때.
