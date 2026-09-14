/// จัดรูป URL ที่เซิร์ฟเวอร์ตอบกลับมาให้ใช้งานได้
///
/// เซิร์ฟเวอร์ตอบลิงก์รูปมาไม่สะอาด เจอทั้งแบบไม่มี scheme นำหน้า
/// และแบบมี slash ซ้อนกันใน path (เกิดจากการต่อ path ฝั่งหลังบ้าน)
/// ฟังก์ชันนี้จึงถูกเรียกทุกจุดที่รับ URL เข้ามา ทั้งตอนอ่านข้อมูลเดิม
/// ตอนรับผลอัปโหลด และตอน parse ผลบันทึก
///
/// ไม่ throw ในทุกกรณี ถ้าแก้ไม่ได้จะคืนค่าที่ trim แล้วกลับไปเฉย ๆ
String normalizeUrl(String url) {
  final raw = url.trim();
  if (raw.isEmpty) return '';

  try {
    // ยังไม่มี scheme (เช่น "147.50.36.66:1152/img/a.jpg") ให้เติม http ให้
    final hasScheme = RegExp(r'^[a-zA-Z][a-zA-Z0-9+\-.]*://').hasMatch(raw);
    final withScheme = hasScheme ? raw : 'http://$raw';

    // บีบ slash ซ้อนเฉพาะส่วนหลัง "://" เพื่อไม่ให้ scheme พัง
    final sep = withScheme.indexOf('://');
    final scheme = withScheme.substring(0, sep);
    final rest = withScheme
        .substring(sep + 3)
        .replaceAll(RegExp(r'/{2,}'), '/');

    return '$scheme://$rest';
  } catch (_) {
    return raw;
  }
}

/// URL ที่ใช้แสดงรูปได้จริงหรือไม่
///
/// เซิร์ฟเวอร์ใช้ทั้ง "" / 0 / "0" / null สื่อว่า "ไม่มีรูป" ต้องกรองออกให้หมด
/// ไม่งั้นหน้าจอจะพยายามโหลดรูปจาก URL ที่เป็นเลข 0
String? resolveImageUrl(dynamic value) {
  if (value == null) return null;

  final raw = value.toString().trim();
  if (raw.isEmpty || raw == '0' || raw == 'null' || raw == 'false') return null;

  final normalized = normalizeUrl(raw);
  // เติม scheme แล้วยังเหลือแค่ host ว่าง ๆ ถือว่าใช้ไม่ได้
  if (normalized.isEmpty || normalized == 'http://') return null;

  return normalized;
}
