import 'package:flutter/material.dart';

import 'package:claim/utils/profile_avatar_service.dart';
import 'package:claim/utils/rank_service.dart';
import 'package:claim/widgets/rank_badge.dart';

const String kDefaultAvatarAsset = 'assets/images/profile.png';

/// รูปโปรไฟล์ที่ผู้ใช้เลือกไว้ อัปเดตเองทุกหน้าที่ใช้เมื่อเปลี่ยนรูป
///
/// ยังไม่เลือกหรือโหลดรูปไม่ได้จะถอยไปใช้รูปที่ติดมากับแอป
class ProfileAvatarView extends StatelessWidget {
  final double radius;

  const ProfileAvatarView({super.key, required this.radius});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final size = radius * 2;

    // ป้ายอันดับลอยมุมบนขวา ไม่มีอันดับก็ไม่กินที่
    return ValueListenableBuilder<UserRank?>(
      valueListenable: RankService.I.rank,
      builder: (context, rank, avatar) => rank == null
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
            ),
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
