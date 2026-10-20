import 'package:flutter/material.dart';
import 'package:skeletonizer/skeletonizer.dart';

/// หน้าจอตอนโหลดข้อมูลไม่สำเร็จ พร้อมปุ่มลองใหม่
class ErrorStateView extends StatelessWidget {
  final String message;
  final Future<void> Function() onRetry;

  const ErrorStateView({
    super.key,
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.cloud_off_outlined,
              size: 56,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('ลองใหม่'),
            ),
          ],
        ),
      ),
    );
  }
}

/// หน้าจอตอนไม่มีข้อมูล
class EmptyStateView extends StatelessWidget {
  final String message;
  final IconData icon;

  const EmptyStateView({
    super.key,
    required this.message,
    this.icon = Icons.inbox_outlined,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Column(
      children: [
        Icon(icon, size: 56, color: scheme.onSurfaceVariant),
        const SizedBox(height: 16),
        Text(
          message,
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 14, color: scheme.onSurfaceVariant),
        ),
      ],
    );
  }
}

/// วงกลมหมุนตอนกำลังโหลด
///
/// ใช้กับหน้าที่ไม่ใช่รายการ (ฟอร์ม หน้ารายละเอียด) หน้ารายการใช้
/// [ListLoadingView] แทน
class LoadingStateView extends StatelessWidget {
  const LoadingStateView({super.key});

  @override
  Widget build(BuildContext context) =>
      const Center(child: CircularProgressIndicator());
}

/// การ์ดโครงสีเทากะพริบตอนหน้ารายการกำลังโหลด
///
/// ผู้ใช้เห็นหน้าตารายการที่กำลังจะมาตั้งแต่วินาทีแรก รู้สึกเร็วกว่าจอว่าง
/// ที่มีวงกลมหมุนอยู่ตรงกลาง แม้จะรอนานเท่ากัน
///
/// ใส่การ์ดเท่าที่จอพอดี ไม่ใช้ ListView เพราะบางหน้าวางไว้ในที่ที่ความสูง
/// ไม่จำกัด ListView จะพังทั้งหน้า ส่วน Column ล้นจอก็ขึ้นแถบเหลืองดำ
class ListLoadingView extends StatelessWidget {
  const ListLoadingView({super.key});

  static const double _cardHeight = 84;

  /// ความสูงไม่จำกัดก็แสดงเท่านี้
  static const int _fallbackCount = 4;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final count = constraints.maxHeight.isFinite
            ? ((constraints.maxHeight - 16) / _cardHeight).floor().clamp(1, 12)
            : _fallbackCount;

        return ClipRect(
          child: Skeletonizer(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (var i = 0; i < count; i++) const _SkeletonCard(),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// การ์ดหลอกให้ [Skeletonizer] วาดโครง ข้อความข้างในไม่มีใครเห็น
/// มีไว้กำหนดความยาวของแท่งสีเทาเท่านั้น
class _SkeletonCard extends StatelessWidget {
  const _SkeletonCard();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      height: ListLoadingView._cardHeight,
      child: Card(
        margin: EdgeInsets.only(bottom: 8),
        child: ListTile(
          leading: CircleAvatar(radius: 20),
          title: Text('รายการที่กำลังโหลดอยู่'),
          subtitle: Text('รายละเอียดของรายการนี้'),
          trailing: Text('สถานะ'),
        ),
      ),
    );
  }
}
