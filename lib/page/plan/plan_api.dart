import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:claim/utils/dio_service.dart';

/// ชื่อ module ใน Permissions.Modules ที่ต้องเปิดให้ก่อนใช้ฟีเจอร์นี้
const String planModule = 'lastmile';

/// สถานะของบิลในแผน อ่านจาก Status_Online
enum BillStatus {
  /// ส่งสำเร็จแล้ว (Status_Online = 1)
  success('สำเร็จ'),

  /// ยังไม่ได้ส่ง (Status_Online ว่าง)
  remaining('คงเหลือ'),

  /// ส่งไม่สำเร็จ
  failed('ไม่สำเร็จ');

  final String label;

  const BillStatus(this.label);
}

/// แผนรถ 1 รอบส่งจาก /api/GetPlanJob (Type = Summary)
class PlanJobItem {
  final String driverId;
  final String typeJobId;
  final String truckSendId;
  final int billTotal;
  final int billSuccess;
  final int billRemain;
  final int billFail;
  final double cod;
  final double priceDelivery;
  final DateTime? datePlan;

  const PlanJobItem({
    required this.driverId,
    required this.typeJobId,
    required this.truckSendId,
    required this.billTotal,
    required this.billSuccess,
    required this.billRemain,
    required this.billFail,
    required this.cod,
    required this.priceDelivery,
    required this.datePlan,
  });

  factory PlanJobItem.fromJson(Map<String, dynamic> json) => PlanJobItem(
    driverId: _str(json['driverid']),
    typeJobId: _str(json['typejobid']),
    truckSendId: _str(json['trucksendid']),
    billTotal: _int(json['BillTotal']),
    billSuccess: _int(json['BillSuccess']),
    billRemain: _int(json['BillRemain']),
    billFail: _int(json['BillFail']),
    cod: _double(json['COD']),
    priceDelivery: _double(json['PriceDelivery']),
    datePlan: DateTime.tryParse(_str(json['DatePlan'])),
  );

  /// เก็บเงินรวม = COD + ค่าขนส่ง
  double get totalCollect => cod + priceDelivery;
}

/// บิล 1 ใบในแผนจาก /api/GetBillList (Type = List)
class BillItem {
  final String truckSendId;
  final String a1;
  final String description;
  final String recieptName;
  final String address;
  final String tel;
  final double cod;
  final double deliveryPrice;
  final String typePay;
  final String memo;
  final int qty;
  final String statusOnline;
  final String statusColor;
  final String pod;
  final String refCode;

  const BillItem({
    required this.truckSendId,
    required this.a1,
    required this.description,
    required this.recieptName,
    required this.address,
    required this.tel,
    required this.cod,
    required this.deliveryPrice,
    required this.typePay,
    required this.memo,
    required this.qty,
    required this.statusOnline,
    required this.statusColor,
    required this.pod,
    required this.refCode,
  });

  factory BillItem.fromJson(Map<String, dynamic> json) => BillItem(
    truckSendId: _str(json['trucksendid']),
    a1: _str(json['A1']),
    description: _str(json['Description']),
    recieptName: _str(json['RecieptName']),
    address: _str(json['Address']),
    tel: _str(json['Tel']),
    cod: _double(json['COD']),
    deliveryPrice: _double(json['DeliveryPrice']),
    typePay: _str(json['Typepay']),
    memo: _str(json['Memo']),
    qty: _int(json['Qty']),
    statusOnline: _str(json['Status_Online']),
    statusColor: _str(json['Status_Color']),
    pod: _str(json['POD']),
    refCode: _str(json['RefCode']),
  );

  /// Status_Online = 1 คือส่งสำเร็จ ว่างคือยังไม่ได้ส่ง ค่าอื่นถือว่าไม่สำเร็จ
  BillStatus get status {
    if (statusOnline.isEmpty) return BillStatus.remaining;
    if (statusOnline == '1') return BillStatus.success;
    return BillStatus.failed;
  }

  bool get hasPod => pod.toUpperCase() == 'Y';
}

/// ดึงแผนรถของคนที่ login อยู่
///
/// driverId มาจาก `driverID` ที่บันทึกไว้ตอน login ถ้าส่งค่าว่างเซิร์ฟเวอร์คืน []
Future<List<PlanJobItem>> fetchMyPlans() async {
  final data = await _postPlanApi(
    path: '/api/GetPlanJob',
    type: 'Summary',
    truckSendId: '',
  );
  return _asList(data)
      .whereType<Map>()
      .map((e) => PlanJobItem.fromJson(Map<String, dynamic>.from(e)))
      .toList();
}

/// ดึงบิลทั้งหมดในรอบส่งที่เลือก
Future<List<BillItem>> fetchBillList({required String truckSendId}) async {
  final data = await _postPlanApi(
    path: '/api/GetBillList',
    type: 'List',
    truckSendId: truckSendId,
  );
  return _asList(data)
      .whereType<Map>()
      .map((e) => BillItem.fromJson(Map<String, dynamic>.from(e)))
      .toList();
}

/// สอง endpoint นี้รับ body และคืน error แบบเดียวกัน
Future<dynamic> _postPlanApi({
  required String path,
  required String type,
  required String truckSendId,
  String searchText = '',
}) async {
  final prefs = await SharedPreferences.getInstance();
  final token = prefs.getString('token');
  final driverId = prefs.getString('driverID');

  if (token == null || token.isEmpty) {
    throw Exception('ไม่พบ token กรุณาเข้าสู่ระบบใหม่');
  }
  if (driverId == null || driverId.isEmpty) {
    throw Exception('ไม่พบรหัสพนักงานของผู้ใช้ กรุณาเข้าสู่ระบบใหม่');
  }

  try {
    final response = await dio.post(
      path,
      data: {
        'Type': type,
        'driverId': driverId,
        'trucksendid': truckSendId,
        'SearchText': searchText,
      },
      options: Options(
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        receiveTimeout: const Duration(seconds: 60),
      ),
    );

    if (response.statusCode != 200) {
      throw Exception('ดึงข้อมูลไม่สำเร็จ (HTTP ${response.statusCode})');
    }

    return response.data;
  } on DioException catch (e) {
    debugPrint('$path error: ${e.type} ${e.message}');

    if (e.response?.statusCode == 401) {
      throw Exception('token หมดอายุ กรุณาเข้าสู่ระบบใหม่');
    }

    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout ||
        e.type == DioExceptionType.sendTimeout) {
      throw Exception('เชื่อมต่อเซิร์ฟเวอร์หมดเวลา กรุณาลองใหม่');
    }

    throw Exception('เชื่อมต่อเซิร์ฟเวอร์ไม่ได้ กรุณาลองใหม่');
  }
}

/// endpoint ตอบเป็น list ตรง ๆ แต่เผื่อกรณีห่อไว้ใน key เช่น data / Result
List<dynamic> _asList(dynamic data) {
  dynamic decoded = data;

  if (decoded is String) {
    final trimmed = decoded.trim();
    if (trimmed.isEmpty) return const [];
    decoded = jsonDecode(trimmed);
  }

  if (decoded is List) return decoded;

  if (decoded is Map) {
    for (final key in const ['data', 'Data', 'result', 'Result', 'List']) {
      final value = decoded[key];
      if (value is List) return value;
    }
    return [decoded];
  }

  return const [];
}

String _str(dynamic value) {
  if (value == null) return '';
  final text = value.toString().trim();
  return text == 'null' ? '' : text;
}

int _int(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.round();
  return int.tryParse(_str(value)) ?? 0;
}

double _double(dynamic value) {
  if (value is double) return value;
  if (value is num) return value.toDouble();
  return double.tryParse(_str(value)) ?? 0;
}
