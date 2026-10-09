# Third-party assets (Creator Store) — audit log

ทุกชิ้นนำเข้าผ่านโฟลเดอร์กักกัน `ServerStorage.AssetQuarantine` (สคริปต์ใน ServerStorage ไม่รัน)
ตรวจหา pattern อันตราย (`require`, `getfenv`, `loadstring`, `HttpService`, `InsertService`, `MarketplaceService`,
`DataStore`, `TeleportService`, `RemoteEvent`, `string.char`, ...) อ่านทุกสคริปต์ แล้ว **ลบสคริปต์ทั้งหมด** เก็บไว้เฉพาะ part/mesh
ไม่ได้เปิด HttpService หรือตั้งค่าความปลอดภัยใด ๆ เพิ่ม (HttpEnabled = false ตลอด)

ของที่ผ่านอยู่ใน **`ServerStorage.AssetLibrary` ของแมพ 7 Nights Hunter** (ไม่ได้อยู่ใน git ถ้าเปิดแมพอื่น
HouseDecor จะใช้กล่องแทนให้อัตโนมัติ) ทุกชิ้นมีชิ้น `Root` ที่ฐานตรงกลาง ไม่หมุน และ attribute `Size` (ขนาดตามแกนโลก)

## ผ่าน (ใช้ในบ้าน)
| ชื่อใน library | asset id | ชื่อเดิม / ผู้สร้าง | สคริปต์ที่ติดมา | หมายเหตุ |
|---|---|---|---|---|
| Furniture_Shelf, _Chair, _Cabinet, _Table, _Bed, _Drawer | 11377510804 | "Optimized Origianl Victorian Era Furniture pack" / Borbe_JonesGrandpa | ไม่มี | mesh ไม้เก่าสีเข้ม ด้านหน้าหัน -Z (ยืนยันจากหมอนของเตียงที่อยู่ฝั่ง +Z) |
| Cobwebs | 12588797614 | "cobwebs" / pizzaandalemonade | ไม่มี | ย่อ 0.45–0.5 วางใต้เพดาน |
| Candelabra | 13543144177 | "Candelabra" / zzz_1551 | ไม่มี | ย่อให้สูง 3.2 studs แล้วเติมแสงเทียนเอง |
| Chandelier | 5672333071 | "Chandelier with Burning Candles" / senji_nsic | ไม่มี | 86 mesh ใช้ 3 ห้อง ย่อ 0.6 |
| Bathtub | 12828025147 | "Bathtub" / Zipperishappy | ไม่มี | ของเดิมยาว 186 studs ย่อเหลือ 7 |
| HunterRig | 14055842958 | "Blind Monster 1, morph" (ตัวละคร "VoidReaver2") / ExterNorer_Roblox | 4 ตัว: แท่นเปลี่ยนร่าง, ปุ่ม UI 2 ตัว, ตัวเล่นอนิเมชัน — ไม่มี pattern อันตราย → ลบทั้งหมด พร้อม Humanoid, อนิเมชัน, เสียง, GUI | rig R6 สัตว์ประหลาดไร้ตา ย่อ 0.85 (สูง ~7.9 ลอดวงกบประตูได้), จุดอ้างอิงที่เท้า, ราก anchored ขาแขนห้อยด้วย Motor6D, ท่าทางทำเองฝั่ง client เพราะอนิเมชันที่แถมมาไม่ใช่ของเกมนี้ (Roblox ไม่ให้เล่น) |
| Wardrobe | 111630714523203 | "Wooden Wardrobe closet storage" / Skycho4196 | `qPerfectionWeld` (Quenty, สคริปต์เชื่อมชิ้นส่วนที่ใช้กันแพร่หลาย ไม่มี pattern อันตราย) → ลบ | ประตูอยู่ฝั่ง +Z จึงหมุน 180° (`ASSET_YAW`), ขยาย 1.3 เท่า, ปิดการชน ให้ผู้เล่นเข้าไปซ่อนได้ |

| HideWardrobe | 10846091949 | "Closet with Jack" / PeppaTheGoober | ไม่มี | (2026-10-09) ตู้สองบานที่ **บานประตูแยกชิ้น** เปิดปิดได้จริง: ลบรูป "Jack" ข้างใน, สร้างบานขวาใหม่โดยสะท้อนบานซ้าย (ของเดิมเปิดค้าง), ใส่จุดบานพับ (Hinge) ให้แต่ละบาน, ทาสีไม้เข้มแทนสีส้ม, ย่อให้สูง 7.8 |
| HideTable | 504075042 | "Table With Tablecloth" / ElderSquirrelsSkyrim | ไม่มี | (2026-10-09) โต๊ะกลมผ้าคลุมยาวเกือบถึงพื้น (ช่องใต้ผ้า ~0.6 stud ให้แอบมอง), เปลี่ยนผ้าเป็นสีผ้าเก่า, ไม้เข้ม |

## ไม่ผ่าน / ไม่ใช้
| asset id | ชื่อ | เหตุผล |
|---|---|---|
| 140625855630237 | Wardrobe Clothes Modern Doors (SparkB8Build3rf17126) | **ปฏิเสธ (ความปลอดภัย)**: ในตู้มีสคริปต์ "LightConfig" ที่แก้ค่า Lighting ของทั้งเกม + ไลบรารีที่เรียก MarketplaceService — ไม่เกี่ยวกับตู้เลย เป็นรูปแบบที่ใช้ซ่อน backdoor; สไตล์โมเดิร์นก็ไม่เข้ากับบ้าน |
| 16086774748 | Noble Table with Tablecloth | ไม่มีสคริปต์ แต่ผ้าเป็นแค่ผ้าพาดกลางโต๊ะ ไม่คลุมถึงพื้น ซ่อนใต้ไม่ได้ |
| 4868032679 | Victorian Furniture Pack (CalicoFerret) | ไม่มีสคริปต์ แต่สไตล์การ์ตูนกลม ๆ สีสด ไม่เข้ากับเกม |
| 13172503911 | asrX's Horror Kit | ไม่มีสคริปต์ แต่เป็นของแนวโรงงาน/ถนน (รั้ว กรวยจราจร) ไม่เข้ากับบ้าน |
| 10697910367 | Old Upright Piano | สคริปต์เล่นเพลงตอนนั่ง (ไม่อันตราย) แต่มี 2,481 ชิ้น หนักเกินไปสำหรับมือถือ |
| หลายรายการ | ของอัปโหลดซ้ำที่ใส่แท็กสแปม | ไม่นำเข้าเลย |

## เสียง (Sounds.luau)
| ใช้เป็น | asset id | ที่มา | ตรวจแล้ว |
|---|---|---|---|
| บรรยากาศกลางคืน | 138890398994853 | "Horror Cinematic Dark Scary Ambience" — DistrokidOfficial | โหลดได้ ยาว 199.7 วิ |
| หัวใจเต้น | 9043365842 | "HEARTBEAT 02 96BPM" — APM Music | โหลดได้ ยาว 60.1 วิ |
| ฝีเท้าปีศาจ | 9114166413 | "Dragon Footsteps 23" — Pro Sound Effects | โหลดได้ ยาว 0.6 วิ (วนซ้ำ) |
| คำราม / jumpscare | 2184044761 | "Monster Growl" — อัปโหลดโดย WesFluff จาก Freesound (ztrees1) | โหลดได้ ยาว 4.4 วิ |

ถ้าจะเผยแพร่เกมจริง ควรตรวจสัญญาอนุญาตของเสียงจาก Freesound อีกครั้ง หรือเปลี่ยนเป็นเสียงจากไลบรารีทางการ
