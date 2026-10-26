// @ts-check
// 모듈 경계 검사(스튜디오 code-rules.md 2절·8절).
// 1) 모듈(src/packages/<모듈>)은 입구 파일(바로 아래 파일)로만 부른다. 속(하위 폴더)은 그 모듈만 쓴다.
// 2) 아래층 모듈은 위층 모듈을 부르지 않는다. 층은 quality/layers.json.
// 3) 모듈은 앱 층(src/app)을 부르지 않는다.
// 4) 화면(web/)은 API 클라이언트(src/app/client.ts)만 부른다.
// 5) 순환 금지.

const R = "src/packages";
const PACKAGE_INTERNALS = `^${R}/[^/]+/[^/]+/`;

// 모듈 이름 → 층. 원본은 quality/layers.json. 새 모듈을 만들면 거기에 넣는다. 없는 모듈은 검사가 실패한다.
const { layers: LAYERS } = require("./quality/layers.json");
const known = Object.values(LAYERS).flat();
const oneOf = (names) => `(${names.join("|")})`;

const layerRules = Object.entries(LAYERS)
  .map(([level, names]) => {
    const higher = Object.entries(LAYERS)
      .filter(([other]) => Number(other) > Number(level))
      .flatMap(([, list]) => list);
    if (higher.length === 0) return null;
    return {
      name: `layer-${level}-may-not-call-up`,
      comment: `층 ${level} 모듈은 위층 모듈을 부르지 않는다.`,
      severity: "error",
      from: { path: `^${R}/${oneOf(names)}/` },
      to: { path: `^${R}/${oneOf(higher)}/` },
    };
  })
  .filter((rule) => rule !== null);

/** @type {import('dependency-cruiser').IConfiguration} */
module.exports = {
  forbidden: [
    {
      name: "entrypoint-boundary-from-outside",
      comment: "모듈 밖에서는 입구 파일만 부른다. 하위 폴더는 그 모듈의 속이다.",
      severity: "error",
      from: { pathNot: `^${R}/` },
      to: { path: PACKAGE_INTERNALS },
    },
    {
      name: "entrypoint-boundary-across-packages",
      comment: "다른 모듈의 속을 부르지 않는다. 같은 모듈 안에서는 자유롭다.",
      severity: "error",
      from: { path: `^${R}/([^/]+)/`, pathNot: `^${R}/[^/]+/tests/` },
      to: { path: PACKAGE_INTERNALS, pathNot: `^${R}/$1/` },
    },
    {
      name: "tests-through-entrypoints",
      comment: "테스트도 입구로만 부른다. 자기 모듈의 속도 부르지 않는다.",
      severity: "error",
      from: { path: `^${R}/([^/]+)/tests/` },
      to: { path: PACKAGE_INTERNALS, pathNot: `^${R}/$1/tests/` },
    },
    {
      name: "tests-folder-is-private",
      comment: "tests/ 폴더는 테스트만 부른다.",
      severity: "error",
      from: { pathNot: `^${R}/[^/]+/tests/` },
      to: { path: `^${R}/[^/]+/tests/` },
    },
    {
      name: "unknown-module",
      comment: "층이 정해지지 않은 모듈. quality/layers.json에 넣는다.",
      severity: "error",
      from: {},
      to: { path: `^${R}/[^/]+/`, pathNot: `^${R}/${oneOf(known)}/` },
    },
    {
      name: "packages-may-not-call-app",
      comment: "모듈은 앱 층을 부르지 않는다. 여러 모듈을 잇는 일은 앱 층이 한다.",
      severity: "error",
      from: { path: `^${R}/` },
      to: { path: "^src/app/" },
    },
    {
      name: "web-only-through-client",
      comment: "화면은 API 클라이언트(src/app/client.ts)만 부른다. 서버 모듈을 직접 부르지 않는다.",
      severity: "error",
      from: { path: "^web/" },
      to: { path: "^src/", pathNot: "^src/app/client\\.ts$" },
    },
    ...layerRules,
    {
      name: "no-circular",
      severity: "error",
      from: {},
      to: { circular: true },
    },
  ],
  options: {
    doNotFollow: { path: "node_modules" },
    // dependency-cruiser는 아직 TypeScript 7을 읽지 못해 swc로 읽는다(docs/stack.md).
    parser: "swc",
    // 화면의 API 클라이언트는 서버의 타입만 가져올 수 있다. 타입만 쓰는 import는 경계 검사에서 뺀다.
    tsPreCompilationDeps: false,
    tsConfig: { fileName: "tsconfig.json" },
    enhancedResolveOptions: { extensions: [".ts", ".tsx", ".js", ".json"] },
  },
};
