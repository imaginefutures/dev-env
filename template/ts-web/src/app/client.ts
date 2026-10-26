// 화면이 서버를 부르는 유일한 길. 화면 코드(web/)는 fetch를 직접 쓰지 않는다(.oxlintrc.json, .dependency-cruiser.cjs).
// 주소·방법·출력 검사는 규격(contract)에서 끌어온다.
import type { z } from "zod";
import { health } from "../packages/contract/index.ts";

export async function getHealth(): Promise<z.infer<typeof health.output>> {
  const response = await fetch(health.path, { method: health.method });
  return health.output.parse(await response.json());
}
