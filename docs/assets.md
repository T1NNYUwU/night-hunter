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

## ไฟฉายจาก Creator Store (2026-10-10): ตรวจแล้ว ไม่นำมาใช้
ค้นคำว่า flashlight ใส่ในโฟลเดอร์กักกัน (ServerStorage ที่สคริปต์ไม่ทำงาน) แล้วตรวจ 3 ตัว:
| asset id | ชื่อ | ผลตรวจ |
|---|---|---|
| 18848750594 | Realistic Flashlight Horror V2 (tunology) | สคริปต์ 2 ตัวสั้น (README + LocalScript ไฟฉาย) ไม่มี pattern อันตราย; ไฟ 2 ดวง: กว้าง 45° สว่าง 1 + แคบ 9° สว่าง 1.5; ตัวโมเดลเป็น Part ก้อนเดียว |
| 94663809346544 | PS1 Realistic Horror Flashlight System (Piquin0000) | มี Script + RemoteEvent (ฝั่ง server) กรวยกว้าง 90° ระยะ 20; ไม่ได้ตรวจเจาะลึก |
| 113167408851721 | realistic flashlight for horror games (Kcyber_Roblox) | กรวยกว้าง 100° ระยะ 45 + เงา; ไม่ได้ตรวจเจาะลึก |
เหตุผลที่ไม่ใช้: ไม่ได้ให้โมเดลที่สวยกว่า (Part ก้อนเดียว) และเกมเรามีระบบไฟฉายที่ต้องผูกกับแบตเตอรี่/เสียงที่ผีได้ยิน/มุมมองบุคคลที่ 1 อยู่แล้ว
สิ่งที่หยิบมาเป็นแนวคิด (เขียนเองทั้งหมด ไม่ได้นำสคริปต์เข้า): แกนแคบสว่าง + รัศมีกว้างจาง, ลำแสงตามกล้องช้ากว่าเล็กน้อย

## ไฟฉายที่ใช้จริง (2026-10-14)
ทีมหามาให้ 3 แบบ + dummy แอนิเมชัน (อยู่ใน StarterPack) ตรวจสคริปต์ทั้งหมดแล้ว **ไม่มี pattern อันตราย** (สคริปต์ไฟฉาย R6 เก่าสั้น ๆ ไม่มีเครือข่าย/โค้ดปิดบัง) แต่ลบสคริปต์ทิ้งทั้งหมด (10 ตัว) เพราะระบบเกมคุมไฟฉายเอง
| รุ่น | หน้าตา | ผล |
|---|---|---|
| Flashlight (คลาสสิก, เมช 115955313) | เหลืองสดแบบของเล่น | ไม่เข้าธีม |
| Advanced Flashlight (Union) | แท่งหนาสีน้ำเงินเข้ม | ไม่เลือก |
| Flashlight System V2 / Dummy (เมช **186494905**, เท็กซ์เจอร์ 186494927) | **โลหะดำทรง Maglite** | **เลือก** ใช้เป็น `StarterPack.Flashlight` |
- เสียงคลิก: `rbxassetid://115959318` (มากับไฟฉายคลาสสิก)
- เมชและเสียงเป็นของผู้สร้างอื่น ถ้าถูกลบ ไฟฉายจะมองไม่เห็น/เงียบ ต้องหาตัวแทน (เกมไม่พัง)
- แอนิเมชัน dummy (`CF` 0.83 วิ: ชักไฟฉายจากข้างตัวมาหน้าลำตัว แล้วยกมือสูง, `Hf` 2 วิ: ค้างยกมือสูง) เป็นของ R6 ไม่ได้ใช้

## ของตกแต่งวิกตอเรียน (2026-10-15): ตรวจแล้ว ใช้ได้
ชุด "Roblox No-Blox Revolution" โดย **ValyziaFortens** (ผู้สร้างคนเดียวกันทั้งชุด สไตล์เข้ากัน) นำเข้าโฟลเดอร์กักกันก่อน ตรวจทุกชิ้น: **ไม่มีสคริปต์เลย** (มีแค่ MeshPart, Part, Decal, Texture, ParticleEmitter/PointLight ของเปลวเทียน)
| asset id | ชิ้น | ใช้เป็น |
|---|---|---|
| 4871652182 | Victorian Wall Wallpaper | ใช้เฉพาะ **ลายเท็กซ์เจอร์ 6 ลาย** (4871615427, 4871616234, 4871637380, 4871614772, 4871614264, 4871613662) บนวอลเปเปอร์ทุกห้อง |
| 4871246790 | Victorian Frame Painting | `AssetLibrary.Decor_Frame` (รูปแขวน) |
| 4871337268 | Victorian Wall Mirror | `Decor_Mirror` |
| 4871293389 | Victorian Antler Plaque | `Decor_Antlers` |
| 4797665994 | Victorian Candlesticks | `Decor_Candlesticks` |
| 4798097924 | Victorian Statuette | `Decor_Statuette` |
| 4883328544, 4883315392 | Victorian Sofa / Big Sofa | **ไม่ใช้**: ชิ้นยาว ~24–27 studs และมี Decal/Texture 400–700 ชิ้นต่อโซฟา หนักเกินไป |
- ทุกชิ้นปรับเป็นมาตรฐาน AssetLibrary: Anchored, ไม่ชน, pivot (ของแขวน: กลางชิ้น หน้าไปทาง −Z; ของตั้ง: กลางฐาน), Attribute `Size`, `AssetId`, `Creator`, `Audit`
- ไม่ได้เปิด HttpService หรือสิทธิ์อะไรเพิ่มเพราะ asset เหล่านี้
