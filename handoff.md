# Handoff — Night Hunter (7 Nights Hunter)

> สำหรับคนหรือ AI ที่มารับงานต่อ อ่านไฟล์นี้ก่อน แล้วค่อยอ่าน [plan.md](plan.md) และ [docs/playable-v1.md](docs/playable-v1.md)
> อัปเดตล่าสุด: 2026-10-08

## โปรเจคนี้คืออะไร
โปรเจคจบ ป.ตรี วิทยาการคอมพิวเตอร์ (ทีม 3 คน, เหลือเวลา ~2–3 เดือน): เกม Roblox co-op สยองขวัญ 1–4 คน รอดให้ครบ 7 คืนในบ้านร้าง
จุดเด่นทางวิชาการคือ **ปีศาจที่ไม่โกง** ติดตามผู้เล่นด้วย particle filter (เวอร์ชันใหม่: จากเสียงอย่างเดียว) เทียบกับปีศาจแบบ rule-based ด้วยตัวจำลองและ playtest
ผู้ใช้เป็นนักศึกษา (สื่อสารภาษาไทย), ใช้ AI ช่วยเขียนเป็นหลัก, เน้นให้ระบบหลังบ้าน/เทคนิคลึกและวัดผลได้

## ตอนนี้อยู่ตรงไหน
- เสร็จ: สปายก์ particle filter, ตัวจำลอง + บอท 4 นิสัย, วงจรคืน (กลางวัน/กลางคืน/รายงาน), เก็บลัง, ล้ม/ช่วยฟื้น, รังสุ่ม, เส้นความยาก 7 คืน, บ้าน 9 ห้องตกแต่งด้วย part
- เสร็จ (2026-10-08): **Playable v1 / M1** ปีศาจตาบอดฟังเสียง (`Acoustics.luau`), มุมมองบุรุษที่ 1, ไฟฉาย + แบต, วิ่ง/ย่อง/สตามินา (`PlayerKit.luau`), jumpscare + ขอบจอแดง ผลอยู่ใน [docs/playable-v1.md](docs/playable-v1.md)
- เสร็จ (2026-10-08): **M2** บ้าน 16 ห้อง, เฟอร์นิเจอร์จาก Creator Store (ตรวจแล้ว ดู [docs/assets.md](docs/assets.md)), เสียง (`Sounds.luau`)
- เสร็จ (2026-10-08): โมเดลปีศาจใหม่ (`AssetLibrary.HunterRig` + ท่าทางขยับข้อต่อฝั่ง client)
- เสร็จ (2026-10-08): **M3** หน้าเริ่มเกม (PLAY / วิธีเล่น / สถิติ), ร้านค้าตอนกลางวัน + ไอเทม 3 อย่าง, เหรียญ, ภารกิจ 3 แบบ (ลัง / ฟิวส์ / กุญแจ + หนีออกประตูหน้า คืน 7), บันทึกความคืบหน้าด้วย DataStore
- เสร็จ (2026-10-08): **M4 (ส่วนโค้ด)** POMCP, opponent model, telemetry, backend (`backend/`), ชุดทดลองในตัวจำลอง — ผลอยู่ใน [docs/m4-research.md](docs/m4-research.md)
- เสร็จ (2026-10-09): **ระบบที่ซ่อนใหม่** ตู้ประตูเปิดปิดได้ + โต๊ะผ้าคลุม, แอบมอง, กลั้นหายใจ, เสียงเข้าที่ซ่อนบอกตำแหน่ง, ปีศาจค้นเมื่อสงสัย — [docs/hiding.md](docs/hiding.md); ไฟล์ deploy Render: `render.yaml` + [docs/deploy.md](docs/deploy.md)
- ยังไม่ทำ: deploy backend + เปิด HttpService + playtest กับคนจริง ([docs/playtest.md](docs/playtest.md))

## โครงสร้างไฟล์ (Rojo project: `default.project.json`)
| ที่อยู่ | ใน Studio | หน้าที่ |
|---|---|---|
| `src/shared/HouseGraph.luau` | ReplicatedStorage.NightHunter | กราฟบ้าน (ห้อง + ตู้), ระยะทาง, ลายเซ็นของ layout |
| `src/shared/ParticleFilter.luau` | 〃 | particle filter ต่อผู้เล่นหนึ่งคน |
| `src/shared/HunterBrain.luau` | 〃 | สมอง `belief` และ `rule` (ใช้ทั้งในเกมและตัวจำลอง) |
| `src/shared/Sim.luau` | 〃 | ตัวจำลองไม่มีภาพ + บอท + ตารางเปรียบเทียบ |
| `src/shared/Sounds.luau` | 〃 | ไอดีเสียงทั้งหมดของเกม |
| `src/shared/Acoustics.luau` | 〃 | โมเดลเสียง: ความดัง, การลดทอนข้ามห้อง, ความเร็วแต่ละท่า (ใช้ทั้งเกมและตัวจำลอง) |
| `src/server/Main.server.luau` | ServerScriptService.NightHunter | จุดเริ่ม: สร้าง/ใช้บ้าน → NightCycle |
| `src/shared/Items.luau` | 〃 | ไอเทมในร้าน (ราคา, จำนวนสูงสุด, ปุ่ม) และเหรียญรางวัลแต่ละภารกิจ |
| `src/shared/OpponentModel.luau` | 〃 | โมเดลการเคลื่อนที่ของผู้เล่น (fit / step / evaluate) — มี port Python ใน `backend/app/opponent_model.py` |
| `src/shared/Pomcp.luau` | 〃 | Monte Carlo tree search บนความเชื่อ (งบเวลา 4 ms ในเกม) |
| `src/shared/DefaultModel.luau` | 〃 | opponent model เริ่มต้น (ฝึกจากบอท) ใช้เมื่อยังไม่มีโมเดลจาก backend |
| `src/server/Config.luau` | ServerScriptService.NightHunter | ตารางสมองปีศาจรายคืน (story) / เงื่อนไข A/B (experiment) |
| `src/server/Telemetry.luau` | 〃 | บันทึกทุกคืนแบบไม่ระบุตัวตน ส่ง backend, โหลดโมเดลล่าสุด |
| `backend/` | — | FastAPI + DB: รับ telemetry, ฝึก/เปิดใช้โมเดล, สถิติ, dashboard (ดู backend/README.md) |
| `src/server/NightCycle.luau` | 〃 | เฟส Waiting/Day/Night/Report, ตารางภารกิจ 7 คืน (ลัง/ฟิวส์/กุญแจ), ล้ม/ฟื้น, รัง, ความยากรายคืน, ปุ่ม debug ใน Studio |
| `src/server/Economy.luau` | 〃 | เหรียญ, ซื้อของ (กลางวัน), ใช้ของ (กลางคืน): Noise Maker / Battery / Adrenaline |
| `src/server/Progress.luau` | 〃 | DataStore: คืนที่ไปได้ไกลสุด + จำนวนครั้งที่หนีรอด |
| `src/server/HunterService.luau` | 〃 | ปีศาจในเกมจริง: ประสาทสัมผัส, เดิน, จับ |
| `src/server/HouseBuilder.luau` | 〃 | สร้าง **Shell** (พื้น กำแพง วงกบ+ประตู) และเรียกสร้างเฟอร์นิเจอร์; แสงตอนรัน; รัง; `ensure()` (ไม่แตะเฟอร์นิเจอร์ที่ทีมแก้) |
| `src/server/HouseDecor.luau` | 〃 | ธีมห้อง, ฉาบผนัง, หน้าต่าง, เพดาน+โคมไฟ, ประตูหน้า, รังปีศาจ (ส่วนของ Shell) |
| `src/server/HouseKit.luau` | 〃 | เครื่องมือสร้างร่วม (box, light, สี) + ค่าความสว่างของโคมทั้งบ้านที่เดียว |
| `src/server/Furniture.luau` | 〃 | เฟอร์นิเจอร์: แคตตาล็อกบล็อกหยาบ, สร้างทีละชิ้นเป็นโมเดลเดี่ยว, ที่ซ่อน, `seed()` |
| `src/server/FurnitureLayout.luau` | 〃 | **ผังเฟอร์นิเจอร์เริ่มต้น** ต่อห้อง (ชนิด ตำแหน่ง หมุน) |
| `src/server/PlayerKit.luau` | 〃 | ท่าทาง/ความเร็ว/สตามินา, ไฟฉาย + แบตเตอรี่ |
| `src/client/Client.client.luau` | StarterPlayerScripts.NightHunter | มุมมองบุรุษที่ 1, ปุ่มควบคุม, HUD, jumpscare, ขอบจอแดง, ลำแสงไฟฉายของตัวเอง, ไฟกะพริบ |
| `src/client/TitleScreen.luau` | 〃 | หน้าเริ่มเกม: PLAY, วิธีเล่น, สถิติที่บันทึกไว้ |
| `src/client/ShopPanel.luau` | 〃 | ร้านค้าตอนกลางวัน (ปุ่ม V / SHOP) |
| `src/client/HideView.luau` | 〃 | มุมมองตอนซ่อน (ช่องประตู/ใต้ผ้า), แถบหายใจ + ความสงสัย, ปุ่ม LEAVE/BREATH |
| `src/server/HideService.luau` | ServerScriptService.NightHunter | ที่ซ่อน: เข้า/ออก, เสียงตามความเร็ว, หายใจ/หอบ, เปิดตู้ตอนปีศาจค้น |
| `plan.md` | — | แผนทั้งโปรเจค, ผลสปายก์, ปัญหาที่เคยเจอ |
| `docs/*.md` | — | บันทึกแต่ละช่วง + ผลทดลอง |

## วิธีรัน
1. `start-rojo.bat` (พอร์ต 34872) → ใน Studio กด Connect ที่ปลั๊กอิน Rojo
2. แมพบน Roblox: **7 Nights Hunter** (placeId 137354108090781) บ้านถูกบันทึกในแมพ (`Workspace.NightHunterHouse`)
3. ถ้าแก้กราฟ/กำแพง/แสง ให้สร้าง **Shell** ใหม่ (เฟอร์นิเจอร์ที่ทีมแก้ไว้ไม่ถูกแตะ); ถ้าจะล้างเฟอร์นิเจอร์กลับผังเริ่มต้นต้องใส่ `{ furniture = "reseed" }` ดูขั้นตอนใน [docs/teamwork.md](docs/teamwork.md)
4. ตัวจำลอง (command bar, ใช้สำเนาเพื่อเลี่ยง cache ของ require):
   `print(require(game.ReplicatedStorage.NightHunter:Clone().Sim).report({ episodes = 100 }))`

## ข้อควรระวัง (เคยพังมาแล้ว)
- **เฟอร์นิเจอร์อยู่ในไฟล์แมพ ไม่ใช่ใน git** (ทีมย้ายด้วยมือได้) `ensure()` จะไม่ตัดสินใจแทน ถ้ากราฟเปลี่ยนจนที่ซ่อนไม่ตรง เกมจะเตือนใน Output ให้ reseed
- `UIGradient.Transparency` บน Frame ทึบทำให้เห็นฉากทะลุ (เคยทำให้บานประตูตอนซ่อนโปร่ง) → ใช้ Frame ทึบ ๆ แทน
- **ไฟฉายเป็นไอเทม (Tool)**: `StarterPack.Flashlight` อยู่ในไฟล์แมพ (ไม่อยู่ใน git) ผู้เล่นทุกคนเกิดมาถืออยู่ ประกอบด้วย `Handle` (เมชไฟฉายดำ) + `Beam` (แกนแคบ 24°) + `Halo` (รัศมีจาง 48°) + `Click` (เสียง) **ไม่มีสคริปต์** — `PlayerKit.luau` เปิด/ปิดไฟกับแบตให้ แก้หน้าตา/แสงได้ใน Studio ตรง ๆ (ถ้าไม่มี Tool นี้ในแมพ PlayerKit สร้างอันง่าย ๆ ให้เอง) Tool อื่นที่เอามาใส่ StarterPack จะถูกลบทิ้งตอนเกิด
- ไฟฉาย: Roblox SpotLight ไม่มีขอบนุ่ม กรวยกว้างเดียวส่องผนังทั้งห้อง (24 studs) จอขาว → ใช้แกนแคบ + รัศมีจาง และ `PlayerKit` ตั้ง `CastShadow=false` ให้ตัวละคร ไม่งั้นแขนบังกรวย
- ของที่ทีมหามาลองจาก Creator Store เก็บไว้ที่ `ServerStorage.Reference_Flashlights` (ลบสคริปต์แล้ว) ไม่ได้ใช้งานจริง: ไฟฉาย 3 แบบ + dummy ที่มี KeyframeSequence R6 (`AnimSaves`: CF, Hf) ตัวละครเกมเป็น **R15** เล่นของ R6 ตรง ๆ ไม่ได้
- หน้า Title เคยทึบ 92% ทำให้ "เริ่มเกมแล้วมืดทั้งจอ" ตอนนี้โปร่ง 50% และกลางวัน/กลางคืนใช้แสงต่างกัน (`NightCycle.setMood`)
- **ห้ามใช้ MCP `screen_capture` แบบกำหนดตำแหน่งกล้องในโหมด Edit** ถ้าหมดเวลากลางคัน กล้องจะเสียและติดไปกับไฟล์ แก้โดยลบ `Workspace.Camera` แล้ว Save (รายละเอียดใน plan.md หัวข้อ 10.1)
- `require()` ในโหมด Edit จะ cache โมดูลรุ่นเก่า ให้ `:Clone()` โฟลเดอร์ก่อน require
- `HouseBuilder.build()` ห้ามตั้งแสง (โหมด Edit จะมืด) แสงกลางคืนตั้งใน `ensure()` ตอนรันเท่านั้น
- ตัวเลขความยากทั้งหมดมาจากตัวจำลอง ยังไม่ได้ยืนยันกับคนเล่นจริง
- การช่วยฟื้นยังไม่เคยทดสอบด้วยผู้เล่นจริง 2 คน
- เป็น git repo ในเครื่องแล้ว (branch `main`) **ยังไม่มี remote / ยังไม่ได้เชื่อม GitHub**
- **asset จาก Creator Store อยู่ใน `ServerStorage.AssetLibrary` ของแมพ ไม่ได้อยู่ใน git** ถ้าเปิดในแมพอื่น บ้านจะใช้กล่องแทน (ดูวิธีสร้าง library ใหม่ใน docs/assets.md)
- เครื่องมือ `screen_capture` ให้ภาพขาวถ้าหน้าต่าง Studio ไม่ได้แสดงอยู่ อย่าสรุปจากภาพขาว

## การตัดสินใจที่ตกลงกับผู้ใช้แล้ว
- ไอเดียหลักหลังเทียบมาหลายรอบ: co-op 7 คืน + ปีศาจ AI (ไอเดียที่ทิ้งและเหตุผล อยู่ใน plan.md หัวข้อ 2)
- ปีศาจต้องไม่เป็น rule-based → particle filter + (ภายหลัง) POMCP + opponent model
- ปีศาจตาบอดแต่หูดี วิ่งไวขึ้น ฉลาดขึ้น / ผู้เล่นมุมมองบุรุษที่ 1 + ไฟฉาย (2026-10-08)
- ใช้ asset ฟรีจาก Creator Store ได้ ถ้าตรวจความปลอดภัยแล้ว หรือทำเองแต่ต้องดูดี ไม่เหลี่ยมแบบ AI ทำ

## ทดสอบเร็วใน Studio (ตอน Play, รันฝั่ง Server)
- ข้ามไปคืนที่ n: `workspace.NightHunterState:SetAttribute("DebugJumpToNight", n)`
- จบกลางวัน/รายงานทันที: `workspace.NightHunterState:SetAttribute("DebugSkipPhase", os.clock())`
- ทดสอบ ProximityPrompt ด้วยสคริปต์: ในมุมมองบุรุษที่ 1 ตัวละครหันตามกล้อง ต้องหันกล้อง (`Camera.CFrame`) ไปที่ของก่อน prompt ถึงจะขึ้น
- DataStore ใน Studio จะเตือน 1 ครั้งถ้ายังไม่เปิด "Enable Studio Access to API Services" (เกมยังเล่นได้)
- ดู telemetry คืนล่าสุด: `workspace.NightHunterState:SetAttribute("DebugDumpTelemetry", os.clock())` แล้วอ่าน attribute `DebugTelemetryJson`
- ทดสอบที่ซ่อน (Studio): `NightHunterState:SetAttribute("DebugHideSlam", <node>)` = ปีศาจได้ยินเสียงกระแทกจากที่ซ่อนนั้น; attribute `DebugRecentSpeed` บนผู้เล่น = ความเร็วที่เซิร์ฟเวอร์จำไว้
- ทดสอบด้วย MCP: `execute_luau` จะรีเซ็ตกล้องเป็น Custom หลังรัน (HideView ตั้งกลับให้เอง) และ `Humanoid:Move` จากสคริปต์ทดสอบโดน ControlModule ทับ — ใช้ `MoveTo` ฝั่ง server หรือ attribute debug แทน
- **โหมดสงบ** (ปิดผี/เพลง/เวลาไม่หมด): กด P ตอน Play ใน Studio หรือ ServerStorage attribute `PeaceMode=true` (ต้องปิดก่อน Publish)
- ปุ่ม M ใน Studio: สลับสมอง rule → belief → pomcp → pomcp+model
- ตัวจำลองเทียบสมอง (command bar): `print(require(game.ReplicatedStorage.NightHunter:Clone().Sim).report({ episodes = 100, brains = {"rule","belief","pomcp"}, lair = "random", wakeTicks = 16, yield = true }))`
- Telemetry ไม่ได้ตั้ง URL จะเตือน 1 ครั้ง "Telemetry offline (game unaffected)" — ปกติ
- backend: `cd backend && uv sync --group dev && uv run pytest`

## งานถัดไป (เรียงตามลำดับ)
1. Deploy backend เป็น HTTPS (เช่น Render / Railway / Fly) → ตั้ง ServerStorage `TelemetryUrl`, secret `nighthunter_api_key`, เปิด Allow HTTP Requests
2. ให้คนเล่นจริงลอง (story mode) เพื่อเก็บ trajectory → `POST /v1/train` ได้โมเดลจากคนจริงตัวแรก
3. Playtest experiment mode 15–30 คน + แบบสอบถาม ([docs/playtest.md](docs/playtest.md))
4. ทดสอบช่วยฟื้นด้วย 2 คน, ดูหน้าตา UI บนมือถือ
5. (ถ้ามีเวลา) ใส่เสียงใน observation ของ POMCP, opponent model รายคน, สถิติแบบ paired
