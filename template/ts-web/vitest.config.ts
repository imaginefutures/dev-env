import { globSync, readFileSync } from "node:fs";
import { join } from "node:path";
import { defineConfig } from "vitest/config";

// 시험을 두 묶음으로 나눈다. db: 시험 DB 도움 파일(src/packages/db/testing.ts)을 가져오는 시험. unit: 나머지.
// unit은 DB 없이 돌아 `pnpm test:fast`(push 전 훅)가 이것만 돌린다. DB 시험을 처음 만들 때 db 묶음에 globalSetup(템플릿 DB 준비)을 단다.
const root = import.meta.dirname;
const files = globSync(
  ["src/**/tests/**/*.test.ts", "quality/tests/**/*.test.ts", "web/src/tests/**/*.test.ts"],
  { cwd: root },
);
const usesDb = (file: string) => /from "[^"]*\/db\/testing\.ts"/.test(readFileSync(join(root, file), "utf8"));

export default defineConfig({
  test: {
    // 한 컴퓨터에서 여러 작업 폴더가 동시에 시험을 돌린다. 코어 수만큼 일꾼을 띄우면 서로 느려지니 로컬 기본은 4.
    // 혼자 돌릴 때는 VITEST_MAX_WORKERS로 늘린다. CI는 러너 하나에 일 하나라 그대로.
    maxWorkers: process.env.CI ? undefined : Number(process.env.VITEST_MAX_WORKERS ?? 4),
    projects: [
      { test: { name: "unit", include: files.filter((file) => !usesDb(file)) } },
      {
        test: {
          name: "db",
          include: files.filter(usesDb),
          // DB 시험은 시험 DB를 복제하느라 부하가 높으면 기본 5초·10초를 넘긴다.
          testTimeout: 30_000,
          hookTimeout: 60_000,
        },
      },
    ],
  },
});
