import 'package:flutter/material.dart';

import 'package:claim/utils/app_colors.dart';
import 'package:claim/utils/rank_service.dart';
import 'package:claim/widgets/app_card.dart';
import 'package:claim/widgets/rank_badge.dart';
import 'package:claim/widgets/rank_medal.dart';
import 'package:claim/widgets/state_views.dart';

/// เปิดหน้าตารางอันดับ
///
/// คนที่ติดอันดับเข้ามาทางการ์ดอันดับ ส่วนคนที่ไม่ติดไม่มีการ์ดให้เด้ง
/// แตะรูปโปรไฟล์แล้วมาที่หน้านี้ตรง ๆ ตารางเป็นของทุกคน ไม่ใช่ของคนติดอันดับ
void openRankBoard(BuildContext context) => Navigator.of(
  context,
).push(MaterialPageRoute(builder: (_) => const RankBoardPage()));

/// ตารางสิบอันดับผู้ส่งบันทึกสินค้าเสียหายสูญหาย
///
/// ข้อมูลมาจาก rank.json ก้อนเดียวกับป้าย เปิดหน้าไม่ต้องรอโหลดใหม่
class RankBoardPage extends StatelessWidget {
  const RankBoardPage({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: scheme.surfaceContainerLowest,
      appBar: AppBar(title: const Text('ตารางอันดับ')),
      body: RefreshIndicator(
        onRefresh: RankService.I.init,
        child: ValueListenableBuilder<RankBoard?>(
          valueListenable: RankService.I.board,
          builder: (context, board, _) => ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: AppSizes.pagePadding,
            children: board == null
                ? const [
                    SizedBox(height: 80),
                    EmptyStateView(
                      message: 'ยังไม่มีตารางอันดับ\nดึงหน้าจอลงเพื่อโหลดใหม่',
                      icon: Icons.emoji_events_outlined,
                    ),
                  ]
                : [
                    _Header(board: board),
                    const SizedBox(height: AppSizes.gap),
                    _Table(board: board),
                    const SizedBox(height: AppSizes.gap),
                    _Note(count: board.entries.length),
                  ],
          ),
        ),
      ),
    );
  }
}

/// หัวเรื่อง บอกว่านับจากอะไรและเป็นรอบไหน
class _Header extends StatelessWidget {
  final RankBoard board;

  const _Header({required this.board});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return AppCard(
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.rankGold.withValues(alpha: 0.14),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.emoji_events,
              size: 26,
              color: AppColors.rankGold,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'ผู้ส่งบันทึกสินค้าเสียหายสูญหาย',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: scheme.onSurface,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  board.period.isEmpty ? 'สิบอันดับแรก' : 'รอบ ${board.period}',
                  style: TextStyle(
                    fontSize: 12.5,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// ตัวตาราง หัวคอลัมน์กับทุกแถวอยู่ในการ์ดเดียวกัน
class _Table extends StatelessWidget {
  final RankBoard board;

  const _Table({required this.board});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final me = RankService.I.currentEmpId;

    // json บางรอบไม่นับรูปมาให้ ถ้ายังตั้งคอลัมน์ไว้จะได้ศูนย์เรียงลงมาสิบแถว
    // ดูเหมือนทุกคนไม่เคยแนบรูป ซ่อนไปเลยแล้วยกที่ว่างให้ชื่อดีกว่า
    final hasImages = board.entries.any((e) => e.images > 0);

    return AppCard(
      clipContent: true,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
            color: scheme.surfaceContainerHighest,
            child: Row(
              children: [
                SizedBox(width: 34, child: _head(scheme, 'ที่')),
                const SizedBox(width: 10),
                Expanded(child: _head(scheme, 'ชื่อ')),
                SizedBox(width: 58, child: _head(scheme, 'รายงาน', end: true)),
                if (hasImages)
                  SizedBox(width: 52, child: _head(scheme, 'รูป', end: true)),
              ],
            ),
          ),
          for (var i = 0; i < board.entries.length; i++) ...[
            if (i > 0) Divider(height: 1, color: scheme.outlineVariant),
            _Row(
              entry: board.entries[i],
              isMe: me.isNotEmpty && board.entries[i].empId == me,
              showImages: hasImages,
            ),
          ],
        ],
      ),
    );
  }

  Widget _head(ColorScheme scheme, String text, {bool end = false}) => Text(
    text,
    textAlign: end ? TextAlign.end : TextAlign.start,
    style: TextStyle(
      fontSize: 11.5,
      fontWeight: FontWeight.w700,
      color: scheme.onSurfaceVariant,
    ),
  );
}

/// หนึ่งแถวของตาราง แถวของตัวเองมีพื้นสีและป้าย "คุณ" กำกับไว้
class _Row extends StatelessWidget {
  final RankEntry entry;
  final bool isMe;
  final bool showImages;

  const _Row({
    required this.entry,
    required this.isMe,
    required this.showImages,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tier = entry.tier;

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      color: isMe ? scheme.primary.withValues(alpha: 0.08) : null,
      child: Row(
        children: [
          SizedBox(width: 34, child: Center(child: _medal(scheme, tier))),
          const SizedBox(width: 10),
          Expanded(child: _name(scheme)),
          SizedBox(width: 58, child: _value(scheme, entry.reports, bold: true)),
          if (showImages)
            SizedBox(width: 52, child: _value(scheme, entry.images)),
        ],
      ),
    );
  }

  /// สามอันดับแรกได้วงสีเหรียญ อันดับ 4-10 ได้วงน้ำเงินของชั้นสิบอันดับ
  ///
  /// เกินสิบไม่มีสีของตัวเอง ใช้วงกลาง ๆ ของธีม ปกติไม่เกิดเพราะตารางตัดที่สิบ
  ///
  /// หน่วงตามอันดับ เลขจะได้ไล่ประทับลงมาทีละแถวจากที่ 1 ไม่ใช่ผุดพร้อมกันทั้งตาราง
  /// halo ปิดไว้เพราะการ์ดตารางตัดขอบ วงกระเพื่อมจะโดนเฉือน
  Widget _medal(ColorScheme scheme, RankTier? tier) => RankMedal(
    size: 30,
    color: tier == null ? scheme.surfaceContainerHighest : rankColor(tier),
    delay: Duration(milliseconds: 70 * (entry.rank - 1)),
    child: Text(
      '${entry.rank}',
      style: TextStyle(
        fontSize: rankFontFor(30, entry.rank),
        fontWeight: FontWeight.w900,
        height: 1,
        color: tier == null ? scheme.onSurfaceVariant : Colors.white,
      ),
    ),
  );

  Widget _name(ColorScheme scheme) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          Flexible(
            child: Text(
              entry.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 14,
                fontWeight: isMe ? FontWeight.w800 : FontWeight.w600,
                color: scheme.onSurface,
              ),
            ),
          ),
          if (isMe) ...[
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: scheme.primary,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                'คุณ',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: scheme.onPrimary,
                ),
              ),
            ),
          ],
        ],
      ),
      if (_subtitle.isNotEmpty) ...[
        const SizedBox(height: 2),
        Text(
          _subtitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: 11.5, color: scheme.onSurfaceVariant),
        ),
      ],
    ],
  );

  /// บรรทัดรองใต้ชื่อ รหัสพนักงานกับสาขา ขาดตัวไหนก็ข้ามตัวนั้นไป
  ///
  /// ไม่มีชื่อ รหัสจะขึ้นไปอยู่บรรทัดบนแล้ว บรรทัดนี้ไม่ต้องบอกซ้ำอีก
  String get _subtitle => [
    if (entry.name.isNotEmpty) 'รหัส ${entry.empId}',
    if (entry.location.isNotEmpty) entry.location,
  ].join(' · ');

  Widget _value(ColorScheme scheme, int value, {bool bold = false}) => Text(
    '$value',
    textAlign: TextAlign.end,
    style: TextStyle(
      fontSize: 14,
      fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
      color: bold ? scheme.onSurface : scheme.onSurfaceVariant,
    ),
  );
}

/// ท้ายตาราง บอกที่มาของตัวเลขสั้น ๆ
class _Note extends StatelessWidget {
  final int count;

  const _Note({required this.count});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Text(
      'นับจากบันทึกสินค้าเสียหายสูญหายที่ส่งเข้าระบบ แสดง $count อันดับแรกของรอบ',
      textAlign: TextAlign.center,
      style: TextStyle(fontSize: 11.5, color: scheme.onSurfaceVariant),
    );
  }
}
