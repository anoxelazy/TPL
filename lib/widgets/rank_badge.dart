import 'package:flutter/material.dart';

import 'package:claim/utils/app_colors.dart';
import 'package:claim/utils/rank_service.dart';

/// สีประจำแต่ละชั้น
Color rankColor(RankTier tier) => switch (tier) {
  RankTier.diamond => AppColors.rankDiamond,
  RankTier.gold => AppColors.rankGold,
  RankTier.silver => AppColors.rankSilver,
  RankTier.bronze => AppColors.rankBronze,
};

/// ป้ายอันดับมุมบนขวาของรูปโปรไฟล์ แตะแล้วบอกว่าติดอันดับอะไร
///
/// ขนาดผูกกับรัศมีรูป ป้ายจะได้ไม่ใหญ่เกินรูปเล็กบนหน้าหลัก
/// และไม่จิ๋วจนอ่านไม่ออกบนรูปใหญ่ในหน้าโปรไฟล์
class RankBadge extends StatelessWidget {
  final UserRank rank;
  final double avatarRadius;

  const RankBadge({
    super.key,
    required this.rank,
    required this.avatarRadius,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final size = (avatarRadius * 0.78).clamp(16.0, 26.0);
    final color = rankColor(rank.tier);

    return GestureDetector(
      onTap: () => showRankCard(context, rank),
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(color: scheme.surface, width: 1.5),
        ),
        child: rank.isDiamond
            ? Icon(Icons.diamond, size: size * 0.58, color: Colors.white)
            : Text(
                '${rank.rank}',
                style: TextStyle(
                  fontSize: size * 0.58,
                  fontWeight: FontWeight.w900,
                  height: 1,
                  color: Colors.white,
                ),
              ),
      ),
    );
  }
}

/// การ์ดบอกรายละเอียดอันดับ เด้งเมื่อแตะป้าย
Future<void> showRankCard(BuildContext context, UserRank rank) {
  final color = rankColor(rank.tier);

  return showDialog<void>(
    context: context,
    builder: (dialogContext) {
      final scheme = Theme.of(dialogContext).colorScheme;

      return AlertDialog(
        contentPadding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 68,
              height: 68,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              child: rank.isDiamond
                  ? const Icon(Icons.diamond, size: 34, color: Colors.white)
                  : Text(
                      '${rank.rank}',
                      style: const TextStyle(
                        fontSize: 34,
                        fontWeight: FontWeight.w900,
                        height: 1,
                        color: Colors.white,
                      ),
                    ),
            ),
            const SizedBox(height: 14),
            Text(
              rank.title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: scheme.onSurface,
              ),
            ),
            if (rank.period.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                'รอบ ${rank.period}',
                style: TextStyle(
                  fontSize: 12.5,
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
            if (rank.reports > 0 || rank.images > 0) ...[
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _Stat(
                    value: rank.reports,
                    unit: 'รายการ',
                    label: 'จำนวนรายงาน',
                    color: color,
                  ),
                  _Stat(
                    value: rank.images,
                    unit: 'รูป',
                    label: 'รูปภาพแนบรวม',
                    color: color,
                  ),
                ],
              ),
            ],
          ],
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('ปิด'),
          ),
        ],
      );
    },
  );
}

class _Stat extends StatelessWidget {
  final int value;
  final String unit;
  final String label;
  final Color color;

  const _Stat({
    required this.value,
    required this.unit,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Column(
      children: [
        Text(
          '$value',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
        Text(
          unit,
          style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(fontSize: 11.5, color: scheme.onSurfaceVariant),
        ),
      ],
    );
  }
}
