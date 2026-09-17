import 'package:flutter_test/flutter_test.dart';

import 'package:claim/page/dashboard/line_invite_banner.dart';
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

  group('คีย์จำว่ากดปิดแถบแล้ว', () {
    test('แยกตามรหัสพนักงาน', () {
      expect(
        lineBannerDismissKey('69053'),
        isNot(lineBannerDismissKey('68224')),
        reason: 'เครื่องเดียวมีคนใช้หลายคน คนแรกกดปิดแล้วคนถัดไปต้องยังเห็น',
      );
    });

    test('รูปแบบคีย์ตรงกับที่เอกสารกำหนด', () {
      expect(lineBannerDismissKey('69053'), 'line_banner_dismissed_69053');
    });
  });
}
