import 'package:flutter/material.dart';
import 'package:claim/screen/login.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:claim/utils/app_colors.dart';
import 'package:claim/utils/permission_service.dart';
import 'package:claim/utils/session_reset.dart';
import 'package:claim/page/profile/avatar_picker_page.dart';
import 'package:claim/widgets/app_card.dart';
import 'package:claim/widgets/profile_avatar_view.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  String fullName = "";
  String driverID = "";
  String appVersion = "";
  bool isLoading = true;

  String get _branchId => PermissionService.I.getBranchId() ?? '';

  bool get _hasDriverId => driverID.isNotEmpty && driverID != "ไม่มีรหัส";

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? token = prefs.getString("token");

    if (token == null) {
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginPage()),
      );
      return;
    }

    try {
      final PackageInfo packageInfo = await PackageInfo.fromPlatform();
      appVersion = packageInfo.version;
    } catch (e) {
      appVersion = "ไม่พบเวอร์ชัน";
    }

    setState(() {
      fullName = prefs.getString("fullname") ?? "ไม่มีชื่อ";
      driverID = prefs.getString("driverID") ?? "ไม่มีรหัส";
      isLoading = false;
    });
  }

  Future<void> _openAvatarPicker() async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const AvatarPickerPage()));
  }

  Future<void> _logout() async {
    // รายการที่ต้องล้างอยู่ที่ forgetSignedInUser ที่เดียว หน้านี้แค่สั่งกับพาไป
    // หน้า login ต่อ เพิ่ม service ใหม่แล้วไม่ต้องมาไล่แก้ทุกที่ที่ logout ได้
    await forgetSignedInUser();

    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const LoginPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: scheme.surfaceContainerLowest,
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: EdgeInsets.zero,
              children: [
                _header(context),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  child: Column(
                    children: [
                      if (_hasDriverId) ...[
                        _qrCard(context),
                        const SizedBox(height: AppSizes.gap),
                      ],
                      _infoCard(context),
                      const SizedBox(height: AppSizes.gap),
                      _logoutCard(context),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  /// หัวหน้าจอ รูปโปรไฟล์กดเปลี่ยนได้จากตรงนี้
  Widget _header(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 18),
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
      child: Row(
        children: [
          GestureDetector(
            onTap: _openAvatarPicker,
            child: Stack(
              children: [
                const ProfileAvatarView(radius: 24),
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: scheme.primary,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: scheme.surfaceContainerLowest,
                        width: 1.5,
                      ),
                    ),
                    child: Icon(Icons.edit, size: 10, color: scheme.onPrimary),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  fullName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    height: 1.25,
                    color: scheme.onSurface,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      Icons.badge_outlined,
                      size: 13,
                      color: scheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        driverID,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11.5,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// QR ให้คนอื่นสแกนรหัสพนักงาน เป็นสิ่งที่ใช้บ่อยสุดในหน้านี้ จึงอยู่บนสุด
  Widget _qrCard(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return AppCard(
      child: Column(
        children: [
          Row(
            children: [
              const _RowIcon(
                icon: Icons.qr_code_2,
                color: AppColors.scanIcon,
                background: AppColors.scanBg,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'QR รหัสพนักงาน',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: scheme.onSurface,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          QrImageView(
            data: driverID,
            version: QrVersions.auto,
            size: 190,
            backgroundColor: scheme.surface,
            eyeStyle: QrEyeStyle(
              eyeShape: QrEyeShape.square,
              color: scheme.onSurface,
            ),
            dataModuleStyle: QrDataModuleStyle(
              dataModuleShape: QrDataModuleShape.square,
              color: scheme.onSurface,
            ),
            errorCorrectionLevel: QrErrorCorrectLevel.M,
          ),
          const SizedBox(height: 10),
          Text(
            driverID,
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 1,
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoCard(BuildContext context) {
    final branch = _branchId;

    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          _SettingRow(
            icon: Icons.face_retouching_natural,
            color: AppColors.pmIcon,
            background: AppColors.pmBg,
            title: 'เปลี่ยนรูปโปรไฟล์',
            onTap: _openAvatarPicker,
          ),
          if (branch.isNotEmpty) ...[
            const _RowDivider(),
            _SettingRow(
              icon: Icons.store_mall_directory_outlined,
              color: AppColors.stockIcon,
              background: AppColors.stockBg,
              title: 'สาขา',
              value: branch,
              showChevron: false,
            ),
          ],
          const _RowDivider(),
          _SettingRow(
            icon: Icons.info_outline,
            color: AppColors.planIcon,
            background: AppColors.planBg,
            title: 'เวอร์ชันแอป',
            value: appVersion,
            showChevron: false,
          ),
        ],
      ),
    );
  }

  Widget _logoutCard(BuildContext context) {
    return AppCard(
      padding: EdgeInsets.zero,
      child: _SettingRow(
        icon: Icons.logout,
        color: AppColors.danger,
        background: Color(0x1AEF4444),
        title: 'ออกจากระบบ',
        titleColor: AppColors.danger,
        showChevron: false,
        onTap: _logout,
      ),
    );
  }
}

/// ไอคอนในกรอบสี่เหลี่ยมมุมมนหน้าแต่ละแถว
class _RowIcon extends StatelessWidget {
  final IconData icon;
  final Color color;
  final Color background;

  const _RowIcon({
    required this.icon,
    required this.color,
    required this.background,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 30,
      height: 30,
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(icon, size: 17, color: color),
    );
  }
}

/// เส้นคั่นระหว่างแถว เว้นซ้ายให้ตรงกับข้อความ ไม่ลากทับไอคอน
class _RowDivider extends StatelessWidget {
  const _RowDivider();

  @override
  Widget build(BuildContext context) => Divider(
    height: 1,
    thickness: 0.5,
    indent: 56,
    color: Theme.of(context).colorScheme.outlineVariant,
  );
}

/// แถวในการ์ด ไอคอนสี + ชื่อ + ค่าทางขวา กดได้เมื่อส่ง [onTap] มา
class _SettingRow extends StatelessWidget {
  final IconData icon;
  final Color color;
  final Color background;
  final String title;
  final String? value;
  final Color? titleColor;
  final bool showChevron;
  final VoidCallback? onTap;

  const _SettingRow({
    required this.icon,
    required this.color,
    required this.background,
    required this.title,
    this.value,
    this.titleColor,
    this.showChevron = true,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    final row = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          _RowIcon(icon: icon, color: color, background: background),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: titleColor ?? scheme.onSurface,
              ),
            ),
          ),
          if (value != null)
            // ไม่ใส่ Flexible เพราะจะไปแบ่ง flex กับชื่อแถวคนละครึ่ง
            // ทำให้ค่าไปกองอยู่กลางแถวแทนที่จะชิดขวา จำกัดความกว้างแทน
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 160),
              child: Text(
                value!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.right,
                style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
              ),
            ),
          if (showChevron) ...[
            const SizedBox(width: 4),
            Icon(Icons.chevron_right, size: 16, color: scheme.onSurfaceVariant),
          ],
        ],
      ),
    );

    if (onTap == null) return row;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSizes.cardRadius),
        child: row,
      ),
    );
  }
}
