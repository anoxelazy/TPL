# วิธี build แอป TPL

## คีย์ที่ต้องใส่ตอน build

`SUPABASE_ANON_KEY` ไม่ได้เก็บไว้ในโค้ดเพราะ repo นี้เป็น public
ต้องส่งเข้าไปตอน build ทุกครั้ง ไม่งั้น **ระบบแจ้งซ่อม ทะเบียนเครื่อง
และป้ายอันดับจะไม่ทำงาน** (ส่วนอื่นของแอปใช้งานได้ปกติ)

ขอคีย์จาก Supabase Dashboard → Project Settings → API Keys → `publishable`

## คำสั่ง

```bash
# APK สำหรับแจกให้พนักงาน
flutter build apk --release --dart-define=SUPABASE_ANON_KEY=<คีย์>

# รันบนเครื่องทดสอบ
flutter run --dart-define=SUPABASE_ANON_KEY=<คีย์>
```

## ใส่ครั้งเดียวไม่ต้องพิมพ์ซ้ำ

สร้างไฟล์ `env.json` ไว้ในเครื่อง (มีใน .gitignore แล้ว ไม่ถูกอัปขึ้น git)

```json
{ "SUPABASE_ANON_KEY": "<คีย์>" }
```

แล้วสั่ง

```bash
flutter build apk --release --dart-define-from-file=env.json
flutter run --dart-define-from-file=env.json
```

## ห้ามเด็ดขาด

อย่าเอาคีย์ที่ขึ้นต้นด้วย `sb_secret_` มาใส่ในแอปหรือใน env.json
คีย์นั้นข้าม policy ทุกอย่างของฐานข้อมูล มีไว้ใช้ฝั่งเซิร์ฟเวอร์เท่านั้น
