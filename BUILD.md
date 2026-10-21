# วิธี build แอป TPL

## คีย์ Supabase มาจากลิงก์ ไม่ต้องใส่ตอน build แล้ว

แอปดึง `SUPABASE_ANON_KEY` จากไฟล์นี้เองตอนเปิดแอป

```
https://raw.githubusercontent.com/anoxelazy/API_json/main/key_sapu.json
```

หน้าตาไฟล์

```json
{ "SUPABASE_ANON_KEY": "sb_publishable_..." }
```

**เปลี่ยนคีย์ = แก้ไฟล์นี้ไฟล์เดียว** แอปทุกเครื่องรับคีย์ใหม่ตอนเปิดครั้งถัดไป
ไม่ต้อง build APK ใหม่แล้วไล่ให้พนักงานอัปเดตทีละคน

คีย์ที่โหลดได้ถูก cache ไว้ในเครื่อง เปิดแอปตอนเน็ตไม่ดีจึงยังแจ้งซ่อมได้
ด้วยคีย์เดิม โหลดไม่ได้และไม่เคยมี cache เลยเท่านั้นที่ระบบแจ้งซ่อม
ทะเบียนเครื่อง และป้ายสิทธิ์ IT จะใช้ไม่ได้ (ส่วนอื่นของแอปใช้งานได้ปกติ)

ขอคีย์จาก Supabase Dashboard → Project Settings → API Keys → `publishable`

## คีย์แผนที่ก็มาจากลิงก์เหมือนกัน

หน้าแผนที่เส้นทางใช้คีย์ 2 ตัว แอปอ่านจาก JSON ที่ลิงก์ `kMapKeysUrl`
ใน `lib/utils/map_keys.dart` (ตอนนี้ชี้ไฟล์เดียวกับคีย์ Supabase ข้างบน)
ใส่สองฟิลด์นี้เพิ่มในไฟล์นั้น หรือ host ไฟล์ใหม่แล้วเปลี่ยนลิงก์ก็ได้

```json
{
  "SUPABASE_ANON_KEY": "sb_publishable_...",
  "ORS_API_KEY": "<คีย์ openrouteservice.org>",
  "LONGDO_API_KEY": "<คีย์ map.longdo.com>"
}
```

- `ORS_API_KEY` ใช้ขอเส้นทางตามถนน ไม่มีก็ถอยไปใช้ OSRM สาธารณะ
- `LONGDO_API_KEY` ใช้ภาพแผนที่ Longdo และหาที่อยู่ให้จุดส่งที่ไม่มีที่อยู่
  ไม่มีก็ใช้แผนที่ OSM และไม่แสดงที่อยู่

เปลี่ยนคีย์ = แก้ไฟล์นี้ ไม่ต้อง build ใหม่ คีย์ที่โหลดได้ถูก cache ไว้ในเครื่อง

## คำสั่ง

```bash
# APK สำหรับแจกให้พนักงาน
flutter build apk --release

# AAB สำหรับอัปขึ้น Play Store (เพิ่มเลขหลัง + ใน version ของ pubspec.yaml ก่อน)
flutter build appbundle --release

# รันบนเครื่องทดสอบ
flutter run
```

## อยากทดสอบด้วยคีย์อื่น

ใส่ตอน build ได้ คีย์ที่ใส่เองจะชนะลิงก์เสมอ ไม่ไปกวนคีย์กลางที่คนอื่นใช้อยู่

```bash
flutter run --dart-define=SUPABASE_ANON_KEY=<คีย์>
```

หรือเก็บไว้ใน `env.json` (มีใน .gitignore แล้ว ไม่ถูกอัปขึ้น git)

```json
{ "SUPABASE_ANON_KEY": "<คีย์>" }
```

```bash
flutter run --dart-define-from-file=env.json
```

ใน VS Code มี config ให้แล้วใน `.vscode/launch.json` กด Run ได้เลย

## ห้ามเด็ดขาด

อย่าเอาคีย์ที่ขึ้นต้นด้วย `sb_secret_` มาใส่ในแอป ใน env.json หรือในลิงก์คีย์
คีย์นั้นข้าม policy ทุกอย่างของฐานข้อมูล มีไว้ใช้ฝั่งเซิร์ฟเวอร์เท่านั้น

แอปมีตัวกันไว้อีกชั้น เจอคีย์ที่ขึ้นต้นด้วย `sb_secret_` หรือมีคำว่า
`service_role` จะไม่หยิบมาใช้ ถึงจะมีคนเผลอเอาไปใส่ในลิงก์ก็ตาม
แต่ตัวคีย์ที่หลุดขึ้นไปบน GitHub แล้วก็ต้องไป revoke อยู่ดี

## ป้ายอันดับ

ไม่เกี่ยวกับ Supabase ดึงจาก `rank.json` บน GitHub ผ่าน API หลัก
ไม่มีคีย์ Supabase ก็ยังทำงานปกติ
