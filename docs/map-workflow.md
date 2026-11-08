# ทำงานทีมแบบ Rojo + Git ทั้งโค้ดและแมพ

แนวคิด: **git เป็นความจริงของทุกอย่าง** ต่างคนต่างทำงานบนสำเนาแมพของตัวเองในเครื่อง ไม่มีแมพกลางให้เขียนทับกัน

ของที่ไม่ได้มาจากโค้ด (อยู่ในไฟล์แมพ) มี 2 อย่าง เราส่งออกเป็นไฟล์ XML ไว้ในโฟลเดอร์ `map/`:

| ไฟล์ | คืออะไร | เอามาจาก |
|---|---|---|
| `map/Furniture.rbxmx` | เฟอร์นิเจอร์และที่ซ่อนทุกชิ้น | `Workspace.NightHunterHouse.Furniture` |
| `map/AssetLibrary.rbxmx` | โมเดลจาก Creator Store (ผีฯลฯ) | `ServerStorage.AssetLibrary` |

ส่วนผนัง พื้น ประตู ฯลฯ (`Shell`) ไม่ต้องส่งออก เพราะโค้ด `HouseBuilder` สร้างใหม่ทุกครั้ง

ใช้ `.rbxmx` (XML) ไม่ใช่ `.rbxm` เพราะ git เทียบความต่างได้ แต่ไฟล์เดียวกัน **ห้ามให้สองคนแก้พร้อมกัน** (ดูกฎด้านล่าง)

## บทบาท

- **เจ้าของแมพ (คนเดียว):** แก้เฟอร์นิเจอร์ใน Studio แล้วส่งออกลง `map/` ใช้ `start-rojo.bat` (ซิงก์เฉพาะโค้ด ไม่ทับแมพของตัวเอง)
- **คนอื่น:** `git pull` แล้วใช้ `start-rojo-with-map.bat` ซึ่งซิงก์ทั้งโค้ดและแมพจาก repo

## เจ้าของแมพ: ส่งออกแมพเข้า git
1. ใน Studio คลิกขวา `Workspace → NightHunterHouse → Furniture` → **Save to File…** เลือกชนิดไฟล์ `.rbxmx` เก็บเป็น `map/Furniture.rbxmx` (ทับของเดิม)
2. คลิกขวา `ServerStorage → AssetLibrary` → **Save to File…** เป็น `.rbxmx` เก็บเป็น `map/AssetLibrary.rbxmx` (ส่งออกเมื่อเพิ่ม/เปลี่ยนโมเดลเท่านั้น)
3. `git pull` → สร้าง branch → `git add map/` → commit → push → เปิด Pull Request
4. บอกทีมในแชตว่า "แมพอัปเดตแล้ว"

## คนอื่น: รับแมพล่าสุด
1. `git pull`
2. เปิดสำเนาแมพของตัวเอง (File → Save to File As เก็บนอก repo ห้าม commit `.rbxl`)
3. ดับเบิลคลิก `start-rojo-with-map.bat` แล้วกด Connect ในปลั๊กอิน Rojo
4. Rojo วางเฟอร์นิเจอร์และ AssetLibrary ลงสำเนาของคุณ และอัปเดตเมื่อ pull ครั้งต่อไป

## กฎ
1. **เฟอร์นิเจอร์มีเจ้าของคนเดียว** ไฟล์ `.rbxmx` merge ไม่ได้ ถ้าสองคนแก้ จะต้องเลือกฝั่งเดียวตอนชน ให้คุยกันก่อนแก้
2. **อย่าแก้เฟอร์นิเจอร์ในสำเนาของคนอื่น** เพราะ Rojo จะเขียนทับด้วยไฟล์ใน repo
3. **อย่าแก้สคริปต์ใน Studio** แก้ไฟล์ใน `src/` เท่านั้น
4. **อย่า commit** `.rbxl`, `.rbxlx`, `.env` และอย่า commit `map/` ที่ยังไม่ได้เทสว่าเปิดได้
5. โมเดลจาก Creator Store ต้องลบสคริปต์ออกและตรวจก่อนทุกครั้ง ดู [assets.md](assets.md)

## หมายเหตุทางเทคนิค
- `with-map.project.json` ตั้ง attribute `Layout = 5` บน `NightHunterHouse` ให้ตรงกับ `LAYOUT` ใน `src/server/HouseBuilder.luau` ถ้าโค้ดเปลี่ยนเลข layout ต้องแก้ไฟล์นี้ตาม ไม่งั้นเกมจะทิ้งบ้านแล้วสร้างใหม่ทั้งหมด
- ถ้ายังไม่มีไฟล์ใน `map/` ให้ใช้ `start-rojo.bat` (ซิงก์โค้ดอย่างเดียว) ไปก่อน
- ถ้ายังอยากใช้ Team Create ตามเดิม ดู [teamwork.md](teamwork.md) ทั้งสองวิธีไม่ควรใช้ปนกันบนแมพเดียว
