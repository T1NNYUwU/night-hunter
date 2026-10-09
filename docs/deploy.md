# Deploy backend: Render (ฟรี) + Neon (ฐานข้อมูลฟรี)

ทำครั้งเดียว ~15 นาที ไม่ต้องใช้บัตรเครดิต

## 1. ฐานข้อมูล Neon
1. สมัคร https://neon.tech (ใช้บัญชี GitHub ได้) → Create project → region **Singapore** (ใกล้ไทย)
2. หน้า Dashboard → **Connection string** → คัดลอก (หน้าตา `postgresql://user:pass@ep-xxx.ap-southeast-1.aws.neon.tech/neondb?sslmode=require`)
   เก็บไว้ อย่าใส่ลง git

## 2. เอาโค้ดขึ้น GitHub
Render ดึงโค้ดจาก GitHub — สร้าง repo ว่าง (Private ก็ได้) แล้ว:
```bash
git remote add origin https://github.com/<ชื่อคุณ>/night-hunter.git
```
```bash
git push -u origin main
```

## 3. Render
1. สมัคร https://render.com ด้วย GitHub → **New → Blueprint** → เลือก repo night-hunter
2. Render อ่าน `render.yaml` เอง → ถามค่า `DATABASE_URL` → วาง connection string จาก Neon → Apply
3. รอ build (~3 นาที) → ได้ URL เช่น `https://night-hunter-api.onrender.com`
4. เปิด `https://<url>/healthz` ต้องเห็น `{"ok":true}` และ `https://<url>/` เป็นหน้า stats
5. หน้า service → **Environment** → คัดลอกค่า `GAME_API_KEY` และ `ADMIN_API_KEY` (Render สุ่มให้แล้ว)

## 4. ต่อกับเกม (Roblox Studio)
1. Game Settings → Security → เปิด **Allow HTTP Requests**
2. Game Settings → Security → Secrets → เพิ่ม `nighthunter_api_key` = ค่า `GAME_API_KEY`
   (ทดสอบใน Studio ถ้า secret ใช้ไม่ได้: ServerStorage → Attributes → `TelemetryKey` = ค่าเดียวกัน **แล้วลบออกก่อน Publish**)
3. ServerStorage → Attributes → เพิ่ม `TelemetryUrl` (string) = URL จากข้อ 3
4. Play 1 คืนจนจบ → เปิดหน้า `/` ของ backend ต้องเห็น 1 night
5. Save / Publish

## 5. ฝึกโมเดลจากผู้เล่นจริง
เมื่อมีข้อมูลสักหลายสิบคืน:
```bash
curl -X POST https://<url>/v1/train -H "X-Api-Key: <ADMIN_API_KEY>"
```
ได้ `"activated": true` = เซิร์ฟเวอร์เกมที่เปิดใหม่จะโหลดโมเดลนี้เอง

## ข้อจำกัดของแบบฟรี
- Render หลับหลังว่าง 15 นาที ครั้งแรกตอบช้า ~1 นาที — เกมรับมือแล้ว (คิวข้อมูลส่งซ้ำ, โหลดโมเดลลองใหม่ 3 ครั้ง)
- Neon: compute 100 ชม./เดือน, พื้นที่ ~0.5–1 GB (ข้อมูลคืนละ ~5 KB → เก็บได้หลายแสนคืน)
