import 'package:flutter_test/flutter_test.dart';

import 'package:claim/utils/app_config.dart';

void main() {
  group('ลิงก์เพิ่มเพื่อน LINE ของระบบแจ้งซ่อม', () {
    test('ต้องเป็น https ไม่ใช่ line://', () {
      expect(
        AppConfig.repairLineOaUrl,
        startsWith('https://'),
        reason: 'line:// บนเครื่องที่ไม่มีแอป LINE จะกดแล้วเงียบ ไม่รู้สาเหตุ',
      );
      expect(Uri.tryParse(AppConfig.repairLineOaUrl), isNotNull);
    });

    test('คนละบัญชีกับ LINE ของผู้ดูแลแอป', () {
      expect(
        AppConfig.repairLineOaUrl,
        isNot(AppConfig.supportLineUrl),
        reason: 'ทักผิดบัญชีแล้วบอทไม่ตอบ คนจะนึกว่าระบบเสีย',
      );
    });
  });
}
