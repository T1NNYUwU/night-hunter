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
- ยังไม่ทำ: POMCP / hybrid hunter, opponent model, telemetry backend, ชุดทดลอง, playtest (M4)

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
| `src/server/NightCycle.luau` | 〃 | เฟส Waiting/Day/Night/Report, ตารางภารกิจ 7 คืน (ลัง/ฟิวส์/กุญแจ), ล้ม/ฟื้น, รัง, ความยากรายคืน, ปุ่ม debug ใน Studio |
| `src/server/Economy.luau` | 〃 | เหรียญ, ซื้อของ (กลางวัน), ใช้ของ (กลางคืน): Noise Maker / Battery / Adrenaline |
| `src/server/Progress.luau` | 〃 | DataStore: คืนที่ไปได้ไกลสุด + จำนวนครั้งที่หนีรอด |
| `src/server/HunterService.luau` | 〃 | ปีศาจในเกมจริง: ประสาทสัมผัส, เดิน, จับ |
| `src/server/HouseBuilder.luau` | 〃 | สร้างโครงบ้าน, แสงตอนรัน, รัง, ensure() |
| `src/server/HouseDecor.luau` | 〃 | ธีมห้อง, เฟอร์นิเจอร์, หน้าต่าง, โคมไฟ |
| `src/server/PlayerKit.luau` | 〃 | ท่าทาง/ความเร็ว/สตามินา, ไฟฉาย + แบตเตอรี่ |
| `src/client/Client.client.luau` | StarterPlayerScripts.NightHunter | มุมมองบุรุษที่ 1, ปุ่มควบคุม, HUD, jumpscare, ขอบจอแดง, ลำแสงไฟฉายของตัวเอง, ไฟกะพริบ |
| `src/client/TitleScreen.luau` | 〃 | หน้าเริ่มเกม: PLAY, วิธีเล่น, สถิติที่บันทึกไว้ |
| `src/client/ShopPanel.luau` | 〃 | ร้านค้าตอนกลางวัน (ปุ่ม V / SHOP) |
| `plan.md` | — | แผนทั้งโปรเจค, ผลสปายก์, ปัญหาที่เคยเจอ |
| `docs/*.md` | — | บันทึกแต่ละช่วง + ผลทดลอง |

## วิธีรัน
1. `start-rojo.bat` (พอร์ต 34872) → ใน Studio กด Connect ที่ปลั๊กอิน Rojo
2. แมพบน Roblox: **7 Nights Hunter** (placeId 137354108090781) บ้านถูกบันทึกในแมพ (`Workspace.NightHunterHouse`)
3. ถ้าแก้กราฟหรือของตกแต่ง ให้สร้างบ้านใหม่จาก command bar:
   `require(game.ServerScriptService.NightHunter.HouseBuilder).build(require(game.ReplicatedStorage.NightHunter.HouseGraph).build())`
4. ตัวจำลอง (command bar, ใช้สำเนาเพื่อเลี่ยง cache ของ require):
   `print(require(game.ReplicatedStorage.NightHunter:Clone().Sim).report({ episodes = 100 }))`

## ข้อควรระวัง (เคยพังมาแล้ว)
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

## งานถัดไป (เรียงตามลำดับ)
1. ให้คนเล่นจริงลอง M3 (หน้าตา, ร้าน, ความยากของคืนฟิวส์/กุญแจ) และทดสอบช่วยฟื้นด้วย 2 คน
2. M4: POMCP / hybrid hunter, opponent model, telemetry backend, ชุดทดลอง, playtest 15–30 คน
