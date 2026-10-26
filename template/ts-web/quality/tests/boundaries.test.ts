// 부르는 방향 검사(.dependency-cruiser.cjs)가 위반을 실제로 잡는지 본다.
// 규칙마다 그 규칙 하나만 어기는 작은 저장소를 임시 폴더에 만들고, 같은 설정 파일에 시험용 층 지도를 붙여 검사한다.
import { copyFile, mkdir, mkdtemp, realpath, rm, writeFile } from "node:fs/promises";
import { createRequire } from "node:module";
import { tmpdir } from "node:os";
import { dirname, join } from "node:path";
import { cruise, type IConfiguration, type ICruiseResult } from "dependency-cruiser";
import { afterEach, describe, expect, it } from "vitest";

// 시험용 층 지도: 층마다 모듈 하나 이상. 프로젝트의 층 지도와 따로 둬서 모듈이 늘어도 시험이 그대로다.
const TEST_LAYERS = { "0": ["contract", "db"], "1": ["orders"], "2": ["reports"] };
const CONFIG = join(import.meta.dirname, "../../.dependency-cruiser.cjs");

function isConfiguration(value: unknown): value is IConfiguration {
  return (
    typeof value === "object" && value !== null && "forbidden" in value && Array.isArray(value.forbidden)
  );
}

let root: string | undefined;

afterEach(async () => {
  if (root) await rm(root, { recursive: true, force: true });
  root = undefined;
});

// files: 경로 → 그 파일이 부르는 경로 목록. 부르는 게 없으면 빈 목록.
async function violatedRules(files: Record<string, string[]>): Promise<string[]> {
  // macOS 임시 폴더는 바로가기(/var → /private/var)라 진짜 경로로 바꿔야 경로 규칙이 맞는다.
  root = await realpath(await mkdtemp(join(tmpdir(), "boundaries-")));
  await mkdir(join(root, "quality"));
  await writeFile(join(root, "quality/layers.json"), JSON.stringify({ layers: TEST_LAYERS }));
  await copyFile(CONFIG, join(root, ".dependency-cruiser.cjs"));
  const loaded: unknown = createRequire(import.meta.url)(join(root, ".dependency-cruiser.cjs"));
  if (!isConfiguration(loaded) || !loaded.forbidden?.length)
    throw new Error("검사 규칙(forbidden)을 읽지 못했다");
  for (const [path, imports] of Object.entries(files)) {
    const full = join(root, path);
    await mkdir(dirname(full), { recursive: true });
    const lines = imports.map((target, index) => {
      const relative = join(
        ...path
          .split("/")
          .slice(0, -1)
          .map(() => ".."),
        target,
      );
      return `import * as m${index} from "./${relative}";\nvoid m${index};`;
    });
    await writeFile(full, `${lines.join("\n")}\nexport const here = 1;\n`);
  }
  const result = await cruise(
    ["src", "web"].filter((top) => Object.keys(files).some((path) => path.startsWith(`${top}/`))),
    {
      baseDir: root,
      validate: true,
      ruleSet: { forbidden: loaded.forbidden },
      parser: "swc",
      tsPreCompilationDeps: false,
      doNotFollow: { path: "node_modules" },
    },
    { extensions: [".ts", ".tsx"] },
  );
  const output: string | ICruiseResult = result.output;
  if (typeof output === "string") throw new Error("검사 결과가 객체가 아니다");
  return [...new Set(output.summary.violations.map((violation) => violation.rule.name))].toSorted();
}

describe("부르는 방향 검사", () => {
  it("규칙을 지킨 저장소는 통과한다(대조군)", async () => {
    expect(
      await violatedRules({
        "src/packages/reports/index.ts": ["src/packages/orders/index.ts"],
        "src/packages/orders/index.ts": [],
        "src/app/main.ts": ["src/packages/reports/index.ts"],
        "web/main.ts": ["src/app/client.ts"],
        "src/app/client.ts": [],
      }),
    ).toEqual([]);
  });

  it("아래층 모듈이 위층 모듈을 부르면 실패한다", async () => {
    expect(
      await violatedRules({
        "src/packages/db/index.ts": ["src/packages/orders/index.ts"],
        "src/packages/orders/index.ts": [],
      }),
    ).toEqual(["layer-0-may-not-call-up"]);
  });

  it("다른 모듈의 속 파일을 부르면 실패한다", async () => {
    expect(
      await violatedRules({
        "src/packages/reports/index.ts": ["src/packages/orders/lib/rules.ts"],
        "src/packages/orders/lib/rules.ts": [],
      }),
    ).toEqual(["entrypoint-boundary-across-packages"]);
  });

  it("모듈 밖에서 모듈의 속 파일을 부르면 실패한다", async () => {
    expect(
      await violatedRules({
        "src/app/main.ts": ["src/packages/orders/lib/rules.ts"],
        "src/packages/orders/lib/rules.ts": [],
      }),
    ).toEqual(["entrypoint-boundary-from-outside"]);
  });

  it("모듈이 앱 층을 부르면 실패한다", async () => {
    expect(
      await violatedRules({
        "src/packages/orders/index.ts": ["src/app/server.ts"],
        "src/app/server.ts": [],
      }),
    ).toEqual(["packages-may-not-call-app"]);
  });

  it("화면이 서버 모듈을 직접 부르면 실패한다", async () => {
    expect(
      await violatedRules({
        "web/main.ts": ["src/packages/orders/index.ts"],
        "src/packages/orders/index.ts": [],
      }),
    ).toEqual(["web-only-through-client"]);
  });

  it("층이 정해지지 않은 모듈을 부르면 실패한다", async () => {
    expect(
      await violatedRules({
        "src/packages/reports/index.ts": ["src/packages/mystery/index.ts"],
        "src/packages/mystery/index.ts": [],
      }),
    ).toEqual(["unknown-module"]);
  });

  it("같은 층끼리 서로 부르면(순환) 실패한다", async () => {
    expect(
      await violatedRules({
        "src/packages/contract/index.ts": ["src/packages/db/index.ts"],
        "src/packages/db/index.ts": ["src/packages/contract/index.ts"],
      }),
    ).toEqual(["no-circular"]);
  });
});
