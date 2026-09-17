import 'package:flutter/material.dart';

import 'package:claim/page/profile/rank_board_page.dart';
import 'package:claim/utils/profile_avatar_service.dart';
import 'package:claim/utils/rank_service.dart';
import 'package:claim/widgets/rank_badge.dart';

const String kDefaultAvatarAsset = 'assets/images/profile.png';

/// รูปโปรไฟล์ที่ผู้ใช้เลือกไว้ อัปเดตเองทุกหน้าที่ใช้เมื่อเปลี่ยนรูป
///
/// ยังไม่เลือกหรือโหลดรูปไม่ได้จะถอยไปใช้รูปที่ติดมากับแอป
class ProfileAvatarView extends StatelessWidget {
  final double radius;

  /// แตะที่รูปแล้วดูอันดับได้เลย ไม่ต้องเล็งป้ายเล็ก ๆ มุมบนขวา
  ///
  /// คนติดอันดับได้การ์ดของตัวเอง คนไม่ติดอันดับเข้าหน้าตารางตรง ๆ
  /// ตารางเป็นของทุกคน ไม่ใช่รางวัลที่ต้องติดอันดับก่อนถึงจะดูได้
  ///
  /// หน้าที่แตะรูปแล้วมีงานอื่นอยู่แล้ว เช่น หน้าโปรไฟล์ที่แตะเพื่อเปลี่ยนรูป
  /// ให้ปล่อยเป็น false ไม่งั้นสองงานจะชนกัน
  final bool tapOpensRank;

  const ProfileAvatarView({
    super.key,
    required this.radius,
    this.tapOpensRank = false,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final size = radius * 2;

    // ป้ายอันดับลอยมุมบนขวา ไม่มีอันดับก็ไม่กินที่
    return ValueListenableBuilder<UserRank?>(
      valueListenable: RankService.I.rank,
      builder: (context, rank, avatar) {
        final content = rank == null
            ? avatar!
            : Stack(
                clipBehavior: Clip.none,
                children: [
                  avatar!,
                  Positioned(
                    right: -2,
                    top: -2,
                    child: RankBadge(rank: rank, avatarRadius: radius),
                  ),
                ],
              );

        if (!tapOpensRank) return content;

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          // ไม่ติดอันดับก็ยังดูตารางได้ ไปหน้าตารางเลยเพราะไม่มีการ์ดให้เด้ง
          onTap: () => rank == null
              ? openRankBoard(context)
              : showRankCard(context, rank),
          child: content,
        );
      },
      child: ValueListenableBuilder<String?>(
        valueListenable: ProfileAvatarService.I.imageUrl,
        builder: (context, url, _) => Container(
          width: size,
          height: size,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHighest,
            shape: BoxShape.circle,
          ),
          child: url == null || url.isEmpty
              ? const _DefaultAvatar()
              : Image.network(
                  url,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stack) =>
                      const _DefaultAvatar(),
                ),
        ),
      ),
    );
  }
}

class _DefaultAvatar extends StatelessWidget {
  const _DefaultAvatar();

  @override
  Widget build(BuildContext context) =>
      Image.asset(kDefaultAvatarAsset, fit: BoxFit.cover);
}
