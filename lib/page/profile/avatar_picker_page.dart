import 'package:flutter/material.dart';

import 'package:claim/page/profile/profile_avatar_api.dart';
import 'package:claim/utils/app_colors.dart';
import 'package:claim/utils/profile_avatar_service.dart';
import 'package:claim/widgets/profile_avatar_view.dart';
import 'package:claim/widgets/state_views.dart';

class AvatarPickerPage extends StatefulWidget {
  const AvatarPickerPage({super.key});

  @override
  State<AvatarPickerPage> createState() => _AvatarPickerPageState();
}

class _AvatarPickerPageState extends State<AvatarPickerPage> {
  List<ProfileAvatar> _avatars = [];
  bool _isLoading = true;
  String? _error;
  String? _selectedId;

  @override
  void initState() {
    super.initState();
    _selectedId = ProfileAvatarService.I.selectedId;
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final avatars = await fetchProfileAvatars();
      await ProfileAvatarService.I.syncWith(avatars);
      if (!mounted) return;
      setState(() {
        _avatars = avatars;
        _selectedId = ProfileAvatarService.I.selectedId;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _select(ProfileAvatar avatar) async {
    await ProfileAvatarService.I.select(avatar);
    if (!mounted) return;
    setState(() => _selectedId = avatar.id);
  }

  Future<void> _useDefault() async {
    await ProfileAvatarService.I.clear();
    if (!mounted) return;
    setState(() => _selectedId = null);
  }

  String get _selectedName {
    final id = _selectedId;
    if (id == null) return 'รูปเริ่มต้น';
    for (final avatar in _avatars) {
      if (avatar.id == id) return avatar.name;
    }
    return 'รูปที่เลือกไว้';
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: scheme.surfaceContainerLowest,
      appBar: AppBar(title: const Text('เปลี่ยนรูปโปรไฟล์')),
      body: Column(
        children: [
          _preview(context),
          Expanded(child: _body()),
        ],
      ),
    );
  }

  Widget _preview(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            scheme.primary.withValues(alpha: 0.16),
            scheme.surfaceContainerLowest,
          ],
        ),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: scheme.primary, width: 2),
            ),
            child: const ProfileAvatarView(radius: 42),
          ),
          const SizedBox(height: 12),
          Text(
            _selectedName,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: scheme.onSurface,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'แตะรูปด้านล่างเพื่อเปลี่ยน',
            style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }

  Widget _body() {
    if (_isLoading) return const LoadingStateView();

    final error = _error;
    if (error != null) {
      return ErrorStateView(message: error, onRetry: _load);
    }

    if (_avatars.isEmpty) {
      return const EmptyStateView(
        icon: Icons.image_not_supported_outlined,
        message: 'ยังไม่มีรูปให้เลือก',
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 5,
        crossAxisSpacing: 10,
        mainAxisSpacing: 14,
        childAspectRatio: 0.72,
      ),
      itemCount: _avatars.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) {
          return _AvatarTile(
            name: 'รูปเริ่มต้น',
            selected: _selectedId == null,
            onTap: _useDefault,
            image: const Image(
              image: AssetImage(kDefaultAvatarAsset),
              fit: BoxFit.cover,
            ),
          );
        }

        final avatar = _avatars[index - 1];
        return _AvatarTile(
          name: avatar.name,
          selected: avatar.id == _selectedId,
          onTap: () => _select(avatar),
          image: Image.network(
            avatar.url,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stack) => Icon(
              Icons.broken_image_outlined,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            loadingBuilder: (context, child, progress) => progress == null
                ? child
                : const Center(
                    child: SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
          ),
        );
      },
    );
  }
}

class _AvatarTile extends StatelessWidget {
  final String name;
  final bool selected;
  final VoidCallback onTap;
  final Widget image;

  const _AvatarTile({
    required this.name,
    required this.selected,
    required this.onTap,
    required this.image,
  });

  static const Duration _duration = Duration(milliseconds: 200);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Column(
        children: [
          Expanded(
            child: AnimatedScale(
              duration: _duration,
              curve: Curves.easeOut,
              scale: selected ? 1.06 : 1,
              child: Stack(
                children: [
                  AnimatedContainer(
                    duration: _duration,
                    curve: Curves.easeOut,
                    padding: EdgeInsets.all(selected ? 2 : 0),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: selected ? scheme.primary : Colors.transparent,
                        width: selected ? 2 : 0,
                      ),
                    ),
                    child: Container(
                      clipBehavior: Clip.antiAlias,
                      decoration: BoxDecoration(
                        color: scheme.surfaceContainerHighest,
                        shape: BoxShape.circle,
                      ),
                      child: SizedBox.expand(child: image),
                    ),
                  ),
                  if (selected)
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: AppColors.success,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: scheme.surfaceContainerLowest,
                            width: 2,
                          ),
                        ),
                        child: const Icon(
                          Icons.check,
                          size: 10,
                          color: Colors.white,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 10,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
              color: selected ? scheme.primary : scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
