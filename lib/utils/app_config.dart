class AppConfig {
  const AppConfig._();
  static const String primaryBaseUrl = 'http://147.50.36.66:1152';
  static const String fallbackBaseUrl = 'http://internal.thaiparcels.com:1152';
  static const String baseUrl = primaryBaseUrl;

  /// ลิงก์เพิ่มเพื่อน LINE ของผู้ดูแลแอป ใช้ทั้งปุ่มเปิด LINE และสร้าง QR
  ///
  /// เปลี่ยนที่นี่ที่เดียว QR สร้างจากลิงก์นี้ตอนรัน ไม่ได้เก็บเป็นไฟล์รูป
  static const String supportLineUrl = 'https://line.me/ti/p/PNRwPCKVLh';

  /// เว็บแจ้งเคสของทีม IT ใช้คู่กับ LINE ส่วนตัว
  ///
  /// ทางนี้เป็นช่องทางที่มีระบบติดตามเคส ต่างจาก LINE ที่เป็นการทักตรง
  static const String supportWebUrl = 'https://internal.thaiparcels.com:1150/';
}
