import { describe, expect, it } from "vitest";
import { health } from "../index.ts";

describe("health 규격", () => {
  it("ok 칸이 참·거짓이면 받고, 없으면 거절한다", () => {
    expect(health.output.safeParse({ ok: true }).success).toBe(true);
    expect(health.output.safeParse({}).success).toBe(false);
  });
});
