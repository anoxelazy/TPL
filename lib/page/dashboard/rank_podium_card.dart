import 'package:flutter/material.dart';

import 'package:claim/page/profile/rank_board_page.dart';
import 'package:claim/utils/app_colors.dart';
import 'package:claim/utils/rank_service.dart';
import 'package:claim/widgets/app_card.dart';
import 'package:claim/widgets/rank_badge.dart';
import 'package:claim/widgets/rank_medal.dart';

class RankPodiumCard extends StatelessWidget {
  const RankPodiumCard({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<RankBoard?>(
      valueListenable: RankService.I.board,
      builder: (context, board, _) {
        final entries = board?.entries ?? const <RankEntry>[];
        if (!entries.any((e) => e.rank >= 1 && e.rank <= 3)) {
          return const SizedBox.shrink();
        }

        return Padding(
          padding: const EdgeInsets.only(top: 16),
          child: AppCard(
            onTap: () => openRankBoard(context),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Header(period: board?.period ?? ''),
                const SizedBox(height: 14),
                _Podium(entries: entries),
                _MyRank(entries: entries),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _Header extends StatelessWidget {
  final String period;

  const _Header({required this.period});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Row(
      children: [
        Container(
          width: 30,
          height: 30,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.rankGold.withValues(alpha: 0.14),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.emoji_events,
            size: 18,
            color: AppColors.rankGold,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'ตารางอันดับผู้ส่งบันทึกสินค้าเสียหายสูญหาย',
                style: TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w800,
                  color: scheme.onSurface,
                ),
              ),
              Text(
                period.isEmpty
                    ? 'ผู้ส่งบันทึกสินค้าเสียหายสูญหาย'
                    : 'รอบ $period',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11.5,
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        Icon(Icons.chevron_right, size: 20, color: scheme.onSurfaceVariant),
      ],
    );
  }
}

class _Podium extends StatelessWidget {
  final List<RankEntry> entries;

  const _Podium({required this.entries});

  RankEntry? _at(int rank) {
    for (final entry in entries) {
      if (entry.rank == rank) return entry;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final first = _at(1);
    final second = _at(2);
    final third = _at(3);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(child: second == null ? _blank(34) : _Step(entry: second)),
        const SizedBox(width: 8),
        Expanded(child: first == null ? _blank(46) : _Step(entry: first)),
        const SizedBox(width: 8),
        Expanded(child: third == null ? _blank(26) : _Step(entry: third)),
      ],
    );
  }

  Widget _blank(double height) => SizedBox(height: height);
}

class _Step extends StatelessWidget {
  final RankEntry entry;

  const _Step({required this.entry});

  bool get _isFirst => entry.rank == 1;

  double get _height => switch (entry.rank) {
    1 => 46,
    2 => 34,
    _ => 26,
  };

  double get _medalSize => _isFirst ? 46 : 38;

  String get _shortName {
    final parts = entry.label.split(RegExp(r'\s+'));
    return parts.isEmpty ? entry.label : parts.first;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tier = entry.tier;
    final color = tier == null ? scheme.outline : rankColor(tier);
    final isMe =
        RankService.I.currentEmpId.isNotEmpty &&
        entry.empId == RankService.I.currentEmpId;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        RankMedal(
          size: _medalSize,
          color: color,
          halo: _isFirst,
          delay: Duration(milliseconds: 120 * (entry.rank - 1)),
          child: Text(
            '${entry.rank}',
            style: TextStyle(
              fontSize: rankFontFor(_medalSize, entry.rank),
              fontWeight: FontWeight.w900,
              height: 1,
              color: Colors.white,
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          _shortName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: isMe ? FontWeight.w900 : FontWeight.w700,
            color: isMe ? color : scheme.onSurface,
          ),
        ),
        Text(
          '${entry.reports} บันทึก',
          maxLines: 1,
          style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
        ),
        const SizedBox(height: 6),
        Container(
          height: _height,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                color.withValues(alpha: 0.30),
                color.withValues(alpha: 0.08),
              ],
            ),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
          ),
        ),
      ],
    );
  }
}

class _MyRank extends StatelessWidget {
  final List<RankEntry> entries;

  const _MyRank({required this.entries});

  @override
  Widget build(BuildContext context) {
    final me = RankService.I.currentEmpId;
    if (me.isEmpty) return const SizedBox.shrink();

    RankEntry? mine;
    for (final entry in entries) {
      if (entry.empId == me) mine = entry;
    }
    if (mine == null || mine.rank <= 3) return const SizedBox.shrink();

    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: scheme.primary.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Icon(Icons.person, size: 16, color: scheme.primary),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'อันดับของคุณ',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: scheme.onSurface,
                ),
              ),
            ),
            Text(
              'ที่ ${mine.rank} · ${mine.reports} ใบ',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
                color: scheme.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
