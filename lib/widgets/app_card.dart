import 'package:flutter/material.dart';

import 'package:claim/utils/app_colors.dart';

/// การ์ดมาตรฐานของแอป ใช้ทุกที่ที่ต้องแสดงข้อมูลเป็นกล่อง
///
/// รวมมุมโค้ง ขอบ และสีพื้นไว้ที่เดียว เวลาปรับหน้าตาจะเปลี่ยนพร้อมกันทุกฟีเจอร์
class AppCard extends StatelessWidget {
  final Widget child;

  /// ระยะขอบด้านใน ปล่อยว่างจะใช้ [AppSizes.cardPadding]
  final EdgeInsetsGeometry? padding;

  /// ใส่มาเมื่อการ์ดกดได้ จะได้เอฟเฟกต์ ripple ให้เอง
  final VoidCallback? onTap;

  /// สีพื้นการ์ด ปล่อยว่างจะใช้สีพื้นผิวปกติของธีม
  final Color? color;

  /// ตัดเนื้อหาส่วนที่ล้นมุมโค้ง ใช้ตอนมีแถบสีชิดขอบการ์ด
  final bool clipContent;

  const AppCard({
    super.key,
    required this.child,
    this.padding,
    this.onTap,
    this.color,
    this.clipContent = false,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final radius = BorderRadius.circular(AppSizes.cardRadius);

    final Widget content = Container(
      padding: clipContent ? null : (padding ?? AppSizes.cardPadding),
      clipBehavior: clipContent ? Clip.antiAlias : Clip.none,
      decoration: BoxDecoration(
        borderRadius: radius,
        border: Border.all(
          color: scheme.outlineVariant,
          width: AppSizes.cardBorder,
        ),
      ),
      child: child,
    );

    return Material(
      color: color ?? scheme.surface,
      borderRadius: radius,
      child: onTap == null
          ? content
          : InkWell(onTap: onTap, borderRadius: radius, child: content),
    );
  }
}
