class AppConfig {
  const AppConfig._();
  /// API หลักตัวเดียวกับพอร์ต 1152 แต่เป็น HTTPS (ใบรับรอง *.thaiparcels.com)
  /// ใบรับรองหมดอายุ 28 ธ.ค. 2026 ถ้าไม่ต่ออายุจะล้มไปใช้ตัวสำรองทุก request
  static const String primaryBaseUrl = 'https://internal.thaiparcels.com:1162';

  /// สำรองด้วย IP ตรง ไม่ผ่าน DNS และไม่ขึ้นกับใบรับรอง จึงยังใช้ได้ตอน
  /// ตัวหลักล่มทั้งสองแบบ ต้องคง usesCleartextTraffic ไว้เพราะเป็น HTTP
  static const String fallbackBaseUrl = 'http://147.50.36.66:1152';
  static const String baseUrl = primaryBaseUrl;
  static const String supportLineUrl = 'https://line.me/ti/p/PNRwPCKVLh';
  static const String repairLineOaUrl = 'https://line.me/R/ti/p/%40402lodyc';
  static const String supportWebUrl = 'https://internal.thaiparcels.com:1150/';
}
