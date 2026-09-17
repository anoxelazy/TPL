import 'package:flutter/material.dart';

import 'package:claim/page/profile/rank_board_page.dart';
import 'package:claim/utils/app_colors.dart';
import 'package:claim/utils/rank_service.dart';
import 'package:claim/widgets/rank_medal.dart';

/// สีประจำแต่ละชั้น
Color rankColor(RankTier tier) => switch (tier) {
  RankTier.diamond => AppColors.rankDiamond,
  RankTier.gold => AppColors.rankGold,
  RankTier.silver => AppColors.rankSilver,
  RankTier.bronze => AppColors.rankBronze,
  RankTier.top10 => AppColors.rankTop10,
};

/// ตัวเลขสองหลักต้องย่อลง ไม่งั้น "10" ล้นออกนอกวงกลม
double rankFontFor(double circleSize, int? rank) =>
    circleSize * ((rank ?? 0) >= 10 ? 0.44 : 0.58);

/// ป้ายอันดับมุมบนขวาของรูปโปรไฟล์ แตะแล้วบอกว่าติดอันดับอะไร
///
/// ขนาดผูกกับรัศมีรูป ป้ายจะได้ไม่ใหญ่เกินรูปเล็กบนหน้าหลัก
/// และไม่จิ๋วจนอ่านไม่ออกบนรูปใหญ่ในหน้าโปรไฟล์
///
/// ป้ายติดหน้าจออยู่ตลอด เลยไม่ใส่อนิเมชัน เก็บไว้เล่นทีเดียวตอนเปิดการ์ด
class RankBadge extends StatelessWidget {
  final UserRank rank;
  final double avatarRadius;

  const RankBadge({super.key, required this.rank, required this.avatarRadius});

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
                  fontSize: rankFontFor(size, rank.rank),
                  fontWeight: FontWeight.w900,
                  height: 1,
                  color: Colors.white,
                ),
              ),
      ),
    );
  }
}

/// การ์ดบอกรายละเอียดอันดับ เด้งเมื่อแตะป้ายหรือแตะรูปโปรไฟล์
Future<void> showRankCard(BuildContext context, UserRank rank) {
  final color = rankColor(rank.tier);

  return showDialog<void>(
    context: context,
    builder: (dialogContext) {
      final scheme = Theme.of(dialogContext).colorScheme;

      return AlertDialog(
        contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
        // passthrough ให้เนื้อหายังกว้างเต็มการ์ดเหมือนตอนไม่มี stack
        content: Stack(
          clipBehavior: Clip.none,
          fit: StackFit.passthrough,
          children: [
            Positioned(
              top: -12,
              right: -8,
              child: IconButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                icon: const Icon(Icons.close),
                iconSize: 20,
                visualDensity: VisualDensity.compact,
                color: scheme.onSurfaceVariant,
                tooltip: 'ปิด',
              ),
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                RankMedal(
                  size: 68,
                  color: color,
                  halo: true,
                  child: rank.isDiamond
                      ? const Icon(Icons.diamond, size: 34, color: Colors.white)
                      : Text(
                          '${rank.rank}',
                          style: TextStyle(
                            fontSize: rankFontFor(68, rank.rank),
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
                      // json บางรอบไม่นับรูปมาให้ โชว์เลขศูนย์ไปจะเหมือนบอกว่า
                      // คนนี้ไม่เคยแนบรูปสักใบ ทั้งที่แค่ไม่มีข้อมูลมา
                      if (rank.images > 0)
                        _Stat(
                          value: rank.images,
                          unit: 'รูป',
                          label: 'รูปภาพแนบรวม',
                          color: color,
                        ),
                    ],
                  ),
                ],
                const SizedBox(height: 20),
                // ปุ่มกว้างเต็มการ์ด ขอบซ้ายขวาเท่ากัน ไม่เอียงไปข้างใดข้างหนึ่ง
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    // ปิดการ์ดก่อนค่อยเปิดหน้าตาราง จะได้ไม่ค้างซ้อนตอนย้อนกลับ
                    onPressed: () {
                      final navigator = Navigator.of(dialogContext);
                      navigator.pop();
                      openRankBoard(navigator.context);
                    },
                    icon: const Icon(Icons.leaderboard, size: 18),
                    label: const Text('ดูตารางอันดับ'),
                  ),
                ),
              ],
            ),
          ],
        ),
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
        // ตัวเลขไล่ขึ้นจาก 0 ให้เห็นว่ากว่าจะสะสมมาได้เท่านี้ผ่านอะไรมาบ้าง
        TweenAnimationBuilder<int>(
          tween: IntTween(begin: 0, end: value),
          duration: const Duration(milliseconds: 1100),
          curve: Curves.easeOutCubic,
          builder: (context, shown, _) => Text(
            '$shown',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: color,
            ),
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
