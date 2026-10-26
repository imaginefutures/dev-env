// 화면 입구. 서버는 src/app/client.ts로만 부른다.
import { getHealth } from "../../src/app/client.ts";

const status = await getHealth();
document.body.textContent = status.ok ? "ok" : "down";
