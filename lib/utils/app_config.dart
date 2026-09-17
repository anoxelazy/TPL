class AppConfig {
  const AppConfig._();
  static const String primaryBaseUrl = 'http://147.50.36.66:1152';
  static const String fallbackBaseUrl = 'http://internal.thaiparcels.com:1152';
  static const String baseUrl = primaryBaseUrl;
  static const String supportLineUrl = 'https://line.me/ti/p/PNRwPCKVLh';

  /// LINE OA ของระบบแจ้งซ่อม ใช้กับปุ่มเพิ่มเพื่อนเพื่อรับแจ้งเตือนสถานะ
  ///
  /// คนละบัญชีกับ [supportLineUrl] ที่ไว้ทักผู้ดูแลแอป
  ///
  /// ต้องเป็น https ไม่ใช่ line:// เพราะเครื่องที่ไม่มีแอป LINE จะกดแล้วเงียบ
  /// ไม่เกิดอะไรขึ้นและไม่รู้สาเหตุ ส่วน https เปิดหน้าเว็บของ LINE ให้แทน
  /// ซึ่งมีปุ่มติดตั้งแอปต่อ
  ///
  /// ⚠️ ถ้าบริษัทย้าย OA ให้แก้ที่นี่ที่เดียว อย่าไปเขียนซ้ำในหน้าจอ
  static const String repairLineOaUrl = 'https://line.me/R/ti/p/%40402lodyc';
  static const String supportWebUrl = 'https://internal.thaiparcels.com:1150/';
}
