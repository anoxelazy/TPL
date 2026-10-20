import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:claim/page/asset/asset_models.dart';

/// ของจริงที่ `/api/AssetTransfer/me` ตอบกลับมาเมื่อ 23 ก.ย. 2026
///
/// เก็บไว้ทั้งก้อนไม่ตัดช่องไหนออก เพราะประเด็นของเทสต์ชุดนี้คือชื่อช่องที่
/// backend ใช้จริง ไม่ใช่ชื่อที่เราเดาไว้ตอนเขียนโมเดล
const _meJson = '''
{
  "emp_id": "68148",
  "emp_fullname": "นายพัฒนพงษ์ อุ่นทรัพย์",
  "dept_code": "F0001",
  "dept_name": "โปรแกรมเมอร์",
  "branch_id": "BKK10",
  "branch_name": "สำนักงานลาดกระบัง(สำนักงานใหญ่)",
  "position_name": "เจ้าหน้าที่โปรแกรมเมอร์",
  "position_level": 1,
  "permissions": [
    "ASSET_CREATE",
    "ASSET_EDIT",
    "TRANSFER_CREATE",
    "TRANSFER_DISPATCH",
    "TRANSFER_RECEIVE"
  ],
  "my_approvers": [
    {
      "dept_code": "F0001",
      "approver_id": "63205",
      "approver_name": "น.ส.พัชรินทร์ ผิวหลง",
      "approver_position": "ผู้จัดการฝ่ายเทคโนโลยีสารสนเทศ",
      "approve_order": 1
    }
  ]
}
''';

const _branchJson = '''
{
  "branch_id": "NE2",
  "branch_name": "HUB ขอนแก่น",
  "branch_type_id": 2,
  "branch_type_name": "ศูนย์กระจายสินค้า",
  "region_name": "ภาคอีสาน",
  "city_name": "ขอนแก่น",
  "staff_count": 5
}
''';

const _employeeJson = '''
{
  "emp_id": "90026",
  "emp_fullname": "น.ส.นวพร ทรงศรี",
  "dept_code": "A0000",
  "dept_name": "ฝ่ายบริหาร",
  "branch_id": "BKK10",
  "position_name": "ประธานเจ้าหน้าที่สายงานการเงินและบัญชี",
  "position_level": 6
}
''';

Map<String, dynamic> _decode(String source) =>
    jsonDecode(source) as Map<String, dynamic>;

void main() {
  group('AssetBranch', () {
    test('อ่านสาขาจากของจริงได้ครบทุกช่อง', () {
      final branch = AssetBranch.fromJson(_decode(_branchJson));

      expect(branch.id, 'NE2');
      expect(branch.name, 'HUB ขอนแก่น');
      expect(branch.typeId, 2);
      expect(branch.typeName, 'ศูนย์กระจายสินค้า');
      expect(branch.cityName, 'ขอนแก่น');
      expect(branch.regionName, 'ภาคอีสาน');
      expect(branch.staffCount, 5);
    });

    test('ป้ายชื่อมีรหัสต่อท้ายให้เทียบกับเอกสารได้', () {
      final branch = AssetBranch.fromJson(_decode(_branchJson));

      expect(branch.label, 'HUB ขอนแก่น (NE2)');
      expect(branch.placeLabel, 'ศูนย์กระจายสินค้า · ขอนแก่น · ภาคอีสาน');
    });

    test('ไม่มีชื่อสาขาก็ยังโชว์รหัส ไม่ใช่ช่องว่าง', () {
      const branch = AssetBranch(id: 'NE2');

      expect(branch.label, 'NE2');
      expect(branch.placeLabel, '');
    });

    test('ข้อความไว้ค้นรวมรหัส ชื่อ และพื้นที่ เป็นตัวพิมพ์เล็กทั้งหมด', () {
      final index = AssetBranch.fromJson(_decode(_branchJson)).searchIndex;

      // คนพิมพ์ "hub" ตัวเล็กต้องเจอสาขาที่ชื่อ "HUB ขอนแก่น"
      expect(index.contains('hub'), isTrue);
      expect(index.contains('ne2'), isTrue);
      expect(index.contains('ขอนแก่น'), isTrue);
    });
  });

  group('AssetEmployee', () {
    test('อ่านพนักงานจากของจริงได้ครบทุกช่อง', () {
      final employee = AssetEmployee.fromJson(_decode(_employeeJson));

      expect(employee.id, '90026');
      expect(employee.fullName, 'น.ส.นวพร ทรงศรี');
      expect(employee.deptCode, 'A0000');
      expect(employee.deptName, 'ฝ่ายบริหาร');
      expect(employee.branchId, 'BKK10');
      expect(employee.positionLevel, 6);
    });

    test('บรรทัดรองบอกตำแหน่ง แผนก และสาขา', () {
      final employee = AssetEmployee.fromJson(_decode(_employeeJson));

      expect(
        employee.roleLabel,
        'ประธานเจ้าหน้าที่สายงานการเงินและบัญชี · ฝ่ายบริหาร · BKK10',
      );
    });

    test('มีแต่รหัสก็ไม่พัง ช่องที่ขาดกลายเป็นค่าว่าง', () {
      final employee = AssetEmployee.fromJson(
        _decode('{"emp_id": "90026"}'),
      );

      expect(employee.label, '90026');
      expect(employee.roleLabel, '');
      expect(employee.positionLevel, 0);
    });
  });

  group('AssetProfile', () {
    test('อ่าน /me ของจริงได้ทั้งสิทธิ์และผู้อนุมัติ', () {
      final profile = AssetProfile.fromJson(_decode(_meJson));

      expect(profile.empId, '68148');
      expect(profile.fullName, 'นายพัฒนพงษ์ อุ่นทรัพย์');
      expect(profile.deptCode, 'F0001');
      expect(profile.branchId, 'BKK10');
      expect(profile.branchLabel, 'สำนักงานลาดกระบัง(สำนักงานใหญ่) (BKK10)');
      expect(profile.permissions, hasLength(5));
      expect(profile.can(kAssetPermCreate), isTrue);
      expect(profile.can(kAssetPermTransferReceive), isTrue);
      expect(profile.can('ASSET_DELETE'), isFalse);
    });

    test('ผู้อนุมัติของแผนกตัวเองติดมากับ /me เลย', () {
      final profile = AssetProfile.fromJson(_decode(_meJson));

      expect(profile.approvers, hasLength(1));

      final approver = profile.approvers.single;
      expect(approver.id, '63205');
      expect(approver.name, 'น.ส.พัชรินทร์ ผิวหลง');
      expect(approver.deptCode, 'F0001');
      expect(approver.order, 1);
      expect(approver.label, 'น.ส.พัชรินทร์ ผิวหลง (63205)');
    });

    test('ไม่มีช่อง permissions / my_approvers ก็ได้ลิสต์ว่าง ไม่ใช่ crash', () {
      final profile = AssetProfile.fromJson(_decode('{"emp_id": "68148"}'));

      expect(profile.permissions, isEmpty);
      expect(profile.approvers, isEmpty);
      expect(profile.can(kAssetPermCreate), isFalse);
    });

    test('ผู้อนุมัติที่ไม่มีรหัสถูกคัดทิ้ง ไม่เอาไปโชว์เป็นแถวเปล่า', () {
      final profile = AssetProfile.fromJson(
        _decode('''
        {
          "emp_id": "68148",
          "my_approvers": [
            {"approver_name": "ไม่มีรหัส"},
            {"approver_id": "63205", "approver_name": "มีรหัส"}
          ]
        }
        '''),
      );

      expect(profile.approvers, hasLength(1));
      expect(profile.approvers.single.id, '63205');
    });
  });

  group('Asset', () {
    test('ชื่อประเภทจาก asset_type_desc ของจริงต้องอ่านออก', () {
      // เคยพลาดมาแล้ว: ตอนเขียนครั้งแรกเดาว่าเป็น `type_desc` เลยได้แต่รหัส
      // ประเภท ("GAMING") โชว์แทนชื่อไทย
      final asset = Asset.fromJson(
        _decode('''
        {
          "asset_id": "OHM",
          "asset_name": "ohm",
          "asset_type": "GAMING",
          "asset_type_desc": "ตามาร",
          "status_id": "IN_USE",
          "status_desc": "กำลังใช้งาน",
          "current_site_id": "BKK10",
          "current_custodian": "68148"
        }
        '''),
      );

      expect(asset.typeLabel, 'ตามาร');
      expect(asset.statusLabel, 'กำลังใช้งาน');
      expect(asset.siteId, 'BKK10');
      expect(asset.custodian, '68148');
    });
  });

  group('AssetLookup', () {
    test('ชื่อช่องของ assettypelist กับ statuslist ที่ยิงมาได้จริง', () {
      final type = AssetLookup.fromJson(
        _decode(
          '{"type_id": "IT-TEST-01", "desc_th": "ทดสอบ", "desc_en": "TEST"}',
        ),
      );
      final status = AssetLookup.fromJson(
        _decode(
          '{"status_id": "IN_STOCK", "desc_th": "อยู่ในคลัง IT",'
          ' "desc_en": "In Stock"}',
        ),
      );

      expect(type.code, 'IT-TEST-01');
      expect(type.label, 'ทดสอบ');
      expect(status.code, 'IN_STOCK');
      expect(status.detailLabel, 'อยู่ในคลัง IT (IN_STOCK)');
    });
  });
}
