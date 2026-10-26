// API 규격(Zod). 문마다 이름·경로·입력·출력을 여기서 한 번만 정하고, 서버의 입출력 검사와 화면 타입을 모두 여기서 끌어온다
// (스튜디오 code-rules.md 8절).
import { z } from "zod";

export const health = {
  method: "GET",
  path: "/health",
  output: z.object({ ok: z.boolean() }),
} as const;
