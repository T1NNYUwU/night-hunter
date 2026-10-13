# ทำงานเป็นทีม: GitHub + Studio (Team Create)

ในโปรเจคนี้ของอยู่ 2 ที่ ต้องรู้ว่าอะไรอยู่ที่ไหน:

| อะไร | อยู่ที่ไหน | ใช้อะไรแชร์ | ใครแก้ |
|---|---|---|---|
| โค้ดทั้งหมด (`src/`), backend, เอกสาร | **GitHub** | git + Rojo | คนเขียนโค้ด |
| บ้านที่สร้างแล้ว, **เฟอร์นิเจอร์**, ที่ซ่อน, AssetLibrary (โมเดลจาก Creator Store), แสง | **ไฟล์แมพบน Roblox** (ไม่อยู่ใน git) | **Team Create** | คนทำแมพ |

## 1. เปิด Team Create (ครั้งเดียว)
1. เปิดแมพใน Studio แล้ว **Publish** ก่อน (ถ้ายังไม่ได้ทำ)
2. แท็บ **Home → Team Create → Turn On** (ถ้าไม่เห็น: View → Team Create)
3. ใน Team Create กด **Invite** (หรือ Creator Hub → Experience → Permissions) ใส่ชื่อ Roblox ของเพื่อน ให้สิทธิ์ **Edit**
4. เพื่อนเปิด Studio → My Games / Shared with me → เปิดแมพเดียวกัน จะเห็นการแก้ของกันและกันแบบสด

เปลี่ยนแมพเป็น Private ได้ ไม่กระทบ Team Create (คนที่มีสิทธิ์ Edit เล่นได้เสมอ)

## 2. Rojo กับ Team Create: ระวังสคริปต์ทับกัน
Rojo เขียนทับสคริปต์ใน Studio ด้วยไฟล์ใน git ส่วน Team Create แชร์สคริปต์ที่เห็นใน Studio ให้ทุกคนสด ๆ ผลคือ:
- **ให้คนเขียนโค้ดเป็นคนต่อ Rojo** (ครั้งละคน) แล้วทุกคนจะเห็นสคริปต์ใหม่ทันที
- **คนทำแมพ ห้ามแก้สคริปต์ใน Studio** ถ้าแก้ Rojo จะเขียนทับตอนซิงก์ครั้งต่อไป ถ้าอยากเปลี่ยนโค้ด ให้แก้ไฟล์ใน repo
- ถ้าสองคนต่อ Rojo พร้อมกันบนแมพเดียวกัน อาจเขียนทับกัน (ผมไม่ได้ทดสอบเคสนี้ เลี่ยงไว้ก่อน)
- ถ้าอยากแก้โค้ดโดยไม่กวนใคร: ต่อ Rojo กับ **สำเนาของแมพในเครื่อง** (File → Save to File As) แล้วเอาผลกลับเข้า git ไม่ต้องแตะแมพกลาง

## 3. ขั้นตอนใช้ git (สำหรับโค้ด)
```bash
git clone https://github.com/T1NNYUwU/night-hunter.git
```
```bash
git checkout -b feature/ชื่อสิ่งที่ทำ
```
ทำงาน → `git add` → `git commit` → `git push -u origin feature/ชื่อสิ่งที่ทำ` → เปิด Pull Request บน GitHub ให้เพื่อนรีวิวก่อน merge เข้า `main`
- ดึงของใหม่ก่อนเริ่มทำเสมอ: `git pull`
- **อย่า commit ไฟล์แมพ** (`*.rbxl`, `*.rbxlx`) และ **อย่า commit คีย์ลับ** (`.env`, GAME_API_KEY, ลิงก์ฐานข้อมูล) — ตั้งไว้ใน `.gitignore` แล้ว
- ชวนเพื่อนเข้า repo: GitHub → Settings → Collaborators → Add people

## 4. แก้บ้านและเฟอร์นิเจอร์ใน Studio (คนทำแมพ)
โครงสร้างใน `Workspace.NightHunterHouse`:
```
NightHunterHouse
├─ Shell        พื้น เพดาน กำแพง วงกบ+ประตู บันได ราว ฉาบผนัง หน้าต่าง โคมไฟ เสากลางโถง   ← สร้างจากโค้ด อย่าแก้ด้วยมือ
├─ Furniture    เฟอร์นิเจอร์ทุกชิ้น แยกเป็นโมเดลเดี่ยว จัดตามห้อง    ← แก้ได้เต็มที่
│   └─ Kitchen / Library / ...   (ชื่อห้อง)
│        └─ Bed, Chair, Drawer, Hiding wardrobe, ...
└─ Belief*, NightHunterSpawn    ตัวช่วยของเกม
```
- **ย้าย/หมุน/ย่อขยาย/ลบ/เพิ่ม** เฟอร์นิเจอร์ได้ตามสบาย จุดหมุนของแต่ละชิ้นอยู่กลางพื้นใต้ชิ้นนั้น ด้านหน้าคือ −Z
- ทุกชิ้นมี Attribute `Kind` (ชนิด) และ `Room` (ห้อง) ชิ้นสีบล็อกมี `Placeholder = true` ไว้ให้รู้ว่ายังเป็นของชั่วคราว
- **เปลี่ยนเป็นโมเดลสวย:** วางโมเดลทับแล้วลบบล็อกเดิม (ตั้งชื่อให้เหมือนกันก็ดี) โมเดลที่เอามาจาก Creator Store **ต้องลบสคริปต์ออกและตรวจก่อนทุกครั้ง** (ดู [assets.md](assets.md))
- **ที่ซ่อน** (`Hiding wardrobe`, `Hiding table`) ผูกกับ node ของห้องนั้น ย้ายได้แต่ **ต้องอยู่ในห้องเดิม** ห้ามเปลี่ยน/ลบ Attribute `Node` และชิ้นลูก `PromptPart`, `Inside`, `Eye` ถ้าลบที่ซ่อนทิ้ง ผู้เล่นจะใช้ node นั้นซ่อนไม่ได้ (เกมจะเตือนใน Output)
- แก้เสร็จ Team Create บันทึกให้เอง; **ให้คนเดียวเป็นคนกด Publish**
- เฟอร์นิเจอร์ไม่อยู่ใน git: ถ้าเผลอลบ/พัง ย้อนได้จาก Version History ของแมพ (Creator Hub → Experience → Version History)

## 5. สร้างบ้านใหม่จากโค้ด (เมื่อผังบ้านหรือกำแพงเปลี่ยน)
เปิดแถบ Command Bar (View → Command Bar) ใน **Edit mode**:
```lua
local rs = game.ReplicatedStorage.NightHunter
local copy = rs:Clone() rs.Parent = nil copy.Parent = game.ReplicatedStorage
local graph = require(copy.HouseGraph).build()
local HB = require(game.ServerScriptService.NightHunter:Clone().HouseBuilder)
HB.build(graph)  -- สร้างกำแพง/ประตู/แสงใหม่ เฟอร์นิเจอร์ที่คุณแก้ไว้ "ไม่ถูกแตะ"
copy:Destroy() rs.Parent = game.ReplicatedStorage
```
- ใส่ `HB.build(graph, { furniture = "reseed" })` = **ล้างเฟอร์นิเจอร์ทั้งหมดกลับเป็นผังเริ่มต้น** (การแก้ด้วยมือหายหมด)
- ผังบ้าน (ห้อง ชั้น ประตู บันได ที่ซ่อน) อยู่ที่ `src/shared/HouseGraph.luau` อ่านภาพรวมที่ [mansion.md](mansion.md)
- ผังเริ่มต้นอยู่ที่ `src/server/FurnitureLayout.luau` (ตำแหน่ง/ชนิด ต่อห้อง) ชนิดที่มีอยู่ดูที่ `Furniture.luau`

## 6. โหมดสงบ: ปิดผีและเพลงตอนแก้แมพ
- **ตอน Play ใน Studio:** กดปุ่ม **P** (มีป้ายสีเขียวบนจอ) = ผีหลับ, ไม่มีเพลง/เสียงหัวใจ, ตอนกลางคืนเวลาไม่หมด
- **เปิดไว้ทั้งเซสชัน:** `ServerStorage` Attribute `PeaceMode` = true (ตอนนี้ตั้งไว้ในแมพแล้ว) มีผล **เฉพาะตอนเล่นใน Studio** เซิร์ฟเวอร์จริงไม่สนใจค่านี้ ถ้าจะทดสอบผีให้กด P ปิด หรือตั้งเป็น false
- ปิด **ทุกเสียง** (เพลง หัวใจ ฝีเท้า เสียงคลิก) ไม่ใช่แค่เพลง
- ในโหมดสงบ ภารกิจ/ร้านค้า/ไอเทมยังใช้ได้ปกติ
- ปุ่มดีบักอื่น (เฉพาะ Studio): G ปาของล่อ, M เปลี่ยนสมองปีศาจ, B โชว์ความเชื่อของปีศาจ
