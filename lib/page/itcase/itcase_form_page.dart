import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import 'package:permission_handler/permission_handler.dart';
import 'package:claim/page/itcase/itcase_api.dart';
import 'package:claim/page/itcase/itcase_appbar.dart';
import 'package:claim/page/itcase/itcase_job_detail_page.dart';
import 'package:claim/page/itcase/itcase_status_page.dart';
import 'package:claim/utils/app_colors.dart';
import 'package:claim/utils/app_icons.dart';
import 'package:claim/utils/mobile_api.dart';
import 'package:claim/widgets/app_card.dart';
import 'package:claim/widgets/barcode_scanner.dart';
import 'package:claim/widgets/state_views.dart';

const int _maxDescription = 500;
const double _kImageRadius = 12;
const Map<String, IconData> _typeIcons = {
  'S001': Icons.desktop_windows_outlined, // คอมพิวเตอร์
  'S002': Icons.grid_view_outlined, // โปรแกรม
  'S003': Icons.dns_outlined, // ระบบ
  'S004': Icons.print_outlined, // อุปกรณ์ต่อพ่วง
  'S005': Icons.wifi_outlined, // อินเทอร์เน็ต
  'S006': Icons.inventory_2_outlined, // เบิก
  'S007': Icons.folder_outlined, // ข้อมูล
};

@visibleForTesting
TextEditingValue insertScannedCode(String text, int at, String code) {
  final cursor = at.clamp(0, text.length);
  final prefix = text.substring(0, cursor);
  final space = prefix.isEmpty || prefix.endsWith(' ') ? '' : ' ';
  final inserted = '$space$code';

  return TextEditingValue(
    text: prefix + inserted + text.substring(cursor),
    selection: TextSelection.collapsed(offset: cursor + inserted.length),
  );
}

/// ช่องเลือกโปรแกรมจึงโผล่มาเฉพาะตอนที่เกี่ยวข้องจริง
class ItCaseFormPage extends StatefulWidget {
  /// ใส่มาจากเว็บแอปเพื่อให้มีปุ่มออกจากระบบบนแถบหัว
  ///
  /// แอปมือถือไม่ต้องส่ง เพราะออกจากระบบที่หน้าโปรไฟล์อยู่แล้ว ปุ่มซ้ำอีกที่
  /// รังแต่จะกดพลาด ส่วนเว็บมีแค่หน้านี้หน้าเดียว ไม่มีที่อื่นให้ออก
  final VoidCallback? onSignOut;

  const ItCaseFormPage({super.key, this.onSignOut});

  @override
  State<ItCaseFormPage> createState() => _ItCaseFormPageState();
}

class _ItCaseFormPageState extends State<ItCaseFormPage> {
  final TextEditingController _description = TextEditingController();

  List<ItCaseSolveType> _solveTypes = const [];

  ItCaseSolveType? _solveType;
  ItCaseProgram? _program;
  XFile? _image;

  bool _loading = true;
  bool _sending = false;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _load();
    _description.addListener(_onTyped);
  }

  @override
  void dispose() {
    _description.removeListener(_onTyped);
    _description.dispose();
    super.dispose();
  }

  void _onTyped() => setState(() {});

  /// ครบพอจะส่งได้หรือยัง ใช้คุมทั้งปุ่มส่งและการบอกว่าขาดอะไร
  bool get _isComplete {
    final type = _solveType;
    if (type == null) return false;
    if (type.hasPrograms && _program == null) return false;
    return _description.text.trim().isNotEmpty;
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });

    try {
      final types = await fetchSolveTypes();
      if (!mounted) return;
      setState(() {
        _solveTypes = types;
        _loading = false;
      });
    } on MobileApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _loadError = e.message;
        _loading = false;
      });
    } catch (_) {
      // ไม่ดักตรงนี้แล้ววงหมุนจะค้างทั้งหน้า ไม่มีทางกดอะไรได้อีกเลย
      if (!mounted) return;
      setState(() {
        _loadError = 'โหลดข้อมูลไม่สำเร็จ กรุณาลองใหม่';
        _loading = false;
      });
    }
  }

  /// เปลี่ยนประเภทปัญหาแล้วโปรแกรมที่เลือกไว้ใช้ไม่ได้อีก เพราะเป็นคนละชุด
  void _selectType(ItCaseSolveType type) {
    setState(() {
      _solveType = type;
      _program = null;
    });
  }

  Future<void> _capture() async {
    // แอปมี CAMERA อยู่ในลิสต์สิทธิ์ (ปลั๊กอิน camera ใส่มาให้ตอน merge manifest)
    // พอประกาศไว้แล้ว Android บังคับว่าต้องได้รับอนุญาตก่อน ไม่งั้นการเรียกกล้อง
    // จะโยน error ออกมาดื้อ ๆ แทนที่จะเปิดกล้องให้
    var status = await Permission.camera.status;
    if (!status.isGranted) status = await Permission.camera.request();
    if (!mounted) return;

    if (!status.isGranted) {
      _toast(
        status.isPermanentlyDenied
            ? 'เปิดสิทธิ์กล้องให้แอปในหน้าตั้งค่าก่อน แล้วลองอีกครั้ง'
            : 'ต้องอนุญาตสิทธิ์กล้องก่อนถึงจะถ่ายรูปได้',
      );
      return;
    }

    await _pick(ImageSource.camera);
  }

  Future<void> _pickFromGallery() => _pick(ImageSource.gallery);

  Future<void> _pick(ImageSource source) async {
    // ไม่ลดคุณภาพตรงนี้ ปล่อยให้ compressImageForUpload ย่อทีเดียวตอนส่ง
    // จะได้ไม่โดนบีบซ้ำสองรอบจนอ่านตัวหนังสือบนหน้าจอที่ถ่ายมาไม่ออก
    final picked = await ImagePicker().pickImage(source: source);
    if (picked == null || !mounted) return;
    setState(() => _image = picked);
  }

  Future<void> _submit() async {
    final type = _solveType;

    // ปุ่มปิดอยู่แล้วเมื่อยังไม่ครบ แต่บอกให้รู้ว่าขาดอะไรดีกว่าให้กดแล้วเงียบ
    if (type == null) {
      _toast('เลือกก่อนว่าอะไรมีปัญหา');
      return;
    }
    if (type.hasPrograms && _program == null) {
      _toast('เลือกโปรแกรมที่มีปัญหาด้วย');
      return;
    }
    if (_description.text.trim().isEmpty) {
      _toast('บอกปัญหาที่เกิดขึ้นด้วย จะได้แก้ไขได้ตรงจุด');
      return;
    }

    setState(() => _sending = true);
    FocusScope.of(context).unfocus();

    try {
      final result = await createItCase(
        jobType: type.id,
        description: _description.text.trim(),
        // ประเภทที่ไม่มีโปรแกรมให้เลือก createItCase จะเติม P000 ให้เอง
        programId: _program?.id,
        image: _image,
      );
      if (!mounted) return;

      final openDetail = await _showSent(result);
      if (!mounted) return;

      // ปิดฟอร์มก่อนเปิดรายละเอียด กดย้อนกลับจากรายละเอียดจะได้ไม่ย้อนมาเจอ
      // ฟอร์มที่กรอกค้างไว้แล้วส่งไปแล้ว
      final navigator = Navigator.of(context);
      navigator.pop(true);
      if (openDetail) _openSentCase(result.caseNumber, navigator);
    } on MobileApiException catch (e) {
      if (!mounted) return;
      setState(() => _sending = false);
      _toast(e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _sending = false);
      _toast('ส่งเคสไม่สำเร็จ กรุณาลองใหม่');
    }
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  /// เด้งบอกว่าส่งแล้ว ต้องกดรับทราบก่อนถึงจะปิดหน้ากลับไป
  ///
  /// ใช้ป๊อปอัปแทน snackbar เพราะ snackbar หายเองใน 4 วินาที คนที่กดส่งแล้ว
  /// วางมือถือลงทันทีจะไม่ทันเห็น แล้วไม่แน่ใจว่าเรื่องส่งไปถึงหรือยัง
  /// จนกลับมาส่งซ้ำอีกใบ ทีม IT ได้เคสเดียวกันสองใบ
  ///
  /// ข้อความบนหัวมาจากเซิร์ฟเวอร์ตรง ๆ ([createItCase] การันตีว่าไม่ว่าง)
  /// ส่วนเลขเคสยกออกมาเป็นช่องของตัวเอง แตะเพื่อเข้าไปดูความคืบหน้าของเคสนี้
  /// ได้เลย หรือกดไอคอนคัดลอกเอาเลขไปวางในไลน์หาทีม IT
  ///
  /// คืน `true` เมื่อผู้แจ้งกดที่เลขเคส คนเรียกจะได้พาไปหน้ารายละเอียดต่อ
  Future<bool> _showSent(ItCaseResult result) async {
    final scheme = Theme.of(context).colorScheme;

    final openDetail = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(
          Icons.check_circle,
          size: 40,
          color: AppColors.caseIcon,
        ),
        title: Text(result.message, textAlign: TextAlign.center),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (result.hasCaseNumber) ...[
              _CaseNumberBox(
                caseNumber: result.caseNumber,
                onOpen: () => Navigator.of(dialogContext).pop(true),
              ),
              const SizedBox(height: 14),
            ],
            Text(
              result.hasCaseNumber
                  ? 'รอทีม IT รับเรื่องแล้ว แตะที่เลขเคสเพื่อดูความคืบหน้าได้เลย'
                  : 'รอทีม IT รับเรื่องแล้ว ดูความคืบหน้าได้ที่ปุ่มรายการมุมบนขวา',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                height: 1.4,
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.caseIcon,
                foregroundColor: Colors.white,
              ),
              child: const Text('ตกลง'),
            ),
          ),
        ],
      ),
    );

    return openDetail ?? false;
  }

  /// เปิดรายละเอียดของเคสที่เพิ่งแจ้ง
  ///
  /// ตอนนี้มีแค่เลขเคสในมือ หน้าปลายทางจะยิง `jobdetails` เอาเนื้อหาเต็มเอง
  /// ประเภทปัญหาที่ฟอร์มโหลดไว้แล้วส่งต่อไปด้วย จะได้ไม่ต้องยิงซ้ำ
  void _openSentCase(String caseNumber, NavigatorState navigator) {
    navigator.push(
      MaterialPageRoute(
        builder: (_) => ItCaseJobDetailPage(
          job: ItCaseJob.justSent(caseNumber),
          types: _solveTypes,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: itCaseAppBar(
        title: 'แจ้งเคส',
        actions: [
          if (widget.onSignOut != null)
            IconButton(
              tooltip: 'ออกจากระบบ',
              onPressed: widget.onSignOut,
              icon: const Icon(Icons.logout),
            ),
          IconButton(
            tooltip: 'ขั้นตอนการดำเนินงาน',
            onPressed: () => Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const ItCaseStatusPage())),
            icon: const Icon(Icons.list_alt),
          ),
        ],
      ),
      // แตะที่ว่างเพื่อปิดคีย์บอร์ด แบบเดียวกับฟอร์มแจ้งซ่อม
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: _body(),
      ),
    );
  }

  Widget _body() {
    if (_loading) return const LoadingStateView();

    final error = _loadError;
    if (error != null) {
      return ErrorStateView(message: error, onRetry: _load);
    }

    final scheme = Theme.of(context).colorScheme;
    final type = _solveType;

    return ListView(
      padding: AppSizes.pagePadding,
      children: [
        _typeCard(scheme),

        // โปรแกรมติดมากับประเภทปัญหา ประเภทที่ไม่เกี่ยวก็ไม่ต้องถาม
        if (type != null && type.hasPrograms) ...[
          const SizedBox(height: AppSizes.gap),
          _programCard(scheme, type),
        ],

        const SizedBox(height: AppSizes.gap),
        _descriptionCard(scheme),
        const SizedBox(height: AppSizes.gap),
        _imageCard(scheme),
        const SizedBox(height: 20),
        _submitButton(),
      ],
    );
  }

  Widget _typeCard(ColorScheme scheme) => AppCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _cardTitle(scheme, Icons.help_outline, 'อะไรมีปัญหา'),
        const SizedBox(height: 12),
        if (_solveTypes.isEmpty) _loadFailedNotice(scheme) else _typePicker(),
      ],
    ),
  );

  Widget _programCard(ColorScheme scheme, ItCaseSolveType type) => AppCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _cardTitle(scheme, Icons.apps_outlined, 'โปรแกรมไหน'),
        const SizedBox(height: 12),
        _programPicker(scheme, type),
      ],
    ),
  );

  Widget _descriptionCard(ColorScheme scheme) => AppCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: _cardTitle(
                scheme,
                Icons.edit_note_outlined,
                'รายละเอียดปัญหา',
              ),
            ),
            IconButton(
              tooltip: 'สแกนบาร์โค้ด',
              onPressed: _sending ? null : _scanIntoDescription,
              icon: const Icon(AppIcons.scan, size: 20),
              color: AppColors.caseIcon,
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _descriptionField(scheme),
      ],
    ),
  );

  /// สแกนเลขแล้ววางตรงตำแหน่งเคอร์เซอร์ ไม่ใช่ทับข้อความที่พิมพ์ไว้
  Future<void> _scanIntoDescription() async {
    final code = await openBarcodeScannerPage(
      context,
      title: 'สแกนเลขเอกสาร',
      hint: 'วางบาร์โค้ดให้อยู่กลางจอ ระบบจะกรอกให้อัตโนมัติ',
    );
    if (code == null || !mounted) return;

    final text = _description.text;
    final selection = _description.selection;
    // เคอร์เซอร์ใช้ไม่ได้ (เช่น ยังไม่เคยแตะช่องเลย) ให้ต่อท้ายข้อความ
    final at = selection.isValid ? selection.start : text.length;

    _description.value = insertScannedCode(text, at, code);
  }

  Widget _imageCard(ColorScheme scheme) => AppCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            _cardTitle(scheme, Icons.image_outlined, 'รูปประกอบ'),
            const SizedBox(width: 6),
            Text(
              'ไม่บังคับ',
              style: TextStyle(fontSize: 11.5, color: scheme.onSurfaceVariant),
            ),
          ],
        ),
        const SizedBox(height: 4),
        _hint(scheme, 'ถ่ายหน้าจอที่มีปัญหา ทีม IT จะเห็นภาพเร็วขึ้น'),
        const SizedBox(height: 12),
        _imageArea(scheme),
      ],
    ),
  );

  /// หัวการ์ด ไอคอนนำหน้าชื่อ ทรงเดียวกับฟอร์มแจ้งซ่อม
  ///
  /// ต่างแค่สีไอคอนที่ใช้สีประจำแจ้งเคส ไม่ใช่ primary ของธีม
  /// จะได้เป็นสีเดียวกับแถบที่กดเข้ามาจากหน้าหลัก
  Widget _cardTitle(ColorScheme scheme, IconData icon, String text) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 18, color: AppColors.caseIcon),
      const SizedBox(width: 8),
      Text(
        text,
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w700,
          color: scheme.onSurface,
        ),
      ),
    ],
  );

  Widget _hint(ColorScheme scheme, String text) => Text(
    text,
    style: TextStyle(
      fontSize: 12,
      height: 1.35,
      color: scheme.onSurfaceVariant,
    ),
  );

  /// ช่องเลือกประเภทปัญหา โชว์ครบทุกตัวพร้อมกัน
  ///
  /// ชื่อประเภทสั้นทุกตัว ("เบิก" ยาวสุด 13 ตัวอักษร) ชิปที่กว้างตามคำจึงจบใน
  /// สองแถว ตารางช่องสี่เหลี่ยมกินความสูงเกือบครึ่งจอทั้งที่มีแค่ 7 ตัวเลือก
  /// ช่องเลือกประเภทปัญหา
  ///
  /// เป็น dropdown เพื่อไม่ให้ตัวเลือกเจ็ดตัวกินความสูงค้างไว้ตลอดเวลา
  /// แต่ตอนกางออกยังใช้หน้าตาเดิม คือไอคอนประจำหมวดนำหน้า และตัวที่เลือกอยู่
  /// เป็นสีของแจ้งเคสพร้อมติ๊ก จะได้ยังกวาดตาเจอง่ายเหมือนตอนเป็นชิป
  Widget _typePicker() => DropdownButtonFormField<ItCaseSolveType>(
    initialValue: _solveType,
    isExpanded: true,
    hint: Text('เลือกหมวดที่มีปัญหา', style: _hintStyle),
    icon: const Icon(Icons.expand_more, color: AppColors.caseIcon),
    decoration: _pickerDecoration(),
    // ช่องตอนปิดอยู่ไม่ต้องถมสีทึบ ไม่งั้นจะกลายเป็นแถบสีใหญ่กลางฟอร์ม
    selectedItemBuilder: (context) => [
      for (final type in _solveTypes)
        _ItCaseOptionRow(
          icon: _typeIcons[type.id] ?? Icons.help_outline,
          label: type.label,
          selected: false,
        ),
    ],
    items: [
      for (final type in _solveTypes)
        DropdownMenuItem(
          value: type,
          child: _ItCaseOptionRow(
            icon: _typeIcons[type.id] ?? Icons.help_outline,
            label: type.label,
            selected: type.id == _solveType?.id,
          ),
        ),
    ],
    onChanged: _sending
        ? null
        : (type) {
            if (type != null) _selectType(type);
          },
  );

  /// ช่องเลือกโปรแกรม อยู่ใต้ช่องประเภทปัญหา จึงต้องหน้าตาเป็นชุดเดียวกัน
  ///
  /// key ผูกกับประเภทที่เลือก เปลี่ยนหมวดแล้วช่องนี้จะรีเซ็ตตาม
  /// ไม่ค้างชื่อโปรแกรมของหมวดก่อนหน้าไว้
  Widget _programPicker(ColorScheme scheme, ItCaseSolveType type) =>
      DropdownButtonFormField<ItCaseProgram>(
        key: ValueKey(type.id),
        initialValue: _program,
        isExpanded: true,
        hint: Text('เลือกโปรแกรมที่มีปัญหา', style: _hintStyle),
        icon: const Icon(Icons.expand_more, color: AppColors.caseIcon),
        decoration: _pickerDecoration(),
        selectedItemBuilder: (context) => [
          for (final program in type.programs)
            _ItCaseOptionRow(
              icon: Icons.apps_outlined,
              label: program.name,
              selected: false,
            ),
        ],
        items: [
          for (final program in type.programs)
            DropdownMenuItem(
              value: program,
              child: _ItCaseOptionRow(
                icon: Icons.apps_outlined,
                label: program.name,
                selected: program.id == _program?.id,
              ),
            ),
        ],
        onChanged: _sending
            ? null
            : (program) => setState(() => _program = program),
      );

  TextStyle get _hintStyle => TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    height: 1.4,
    color: Theme.of(
      context,
    ).colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
  );

  InputDecoration _pickerDecoration() => InputDecoration(
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppSizes.cardRadius),
      borderSide: const BorderSide(color: AppColors.caseIcon, width: 2),
    ),
  );

  Widget _descriptionField(ColorScheme scheme) => TextField(
    controller: _description,
    enabled: !_sending,
    maxLines: 5,
    minLines: 3,
    maxLength: _maxDescription,
    textInputAction: TextInputAction.newline,
    decoration: InputDecoration(
      hintText: 'เช่น ทำสถานะเอกสารไม่ได้',
      alignLabelWithHint: true,
      hintStyle: _hintStyle,
      counterText: _description.text.length > _maxDescription - 100
          ? '${_description.text.length}/$_maxDescription'
          : '',
      counterStyle: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppSizes.cardRadius),
        borderSide: const BorderSide(color: AppColors.caseIcon, width: 2),
      ),
    ),
  );

  Widget _imageArea(ColorScheme scheme) {
    final image = _image;
    if (image == null) return _imageButtons(scheme);

    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(_kImageRadius),
          child: Stack(
            children: [
              _Preview(file: image),
              Positioned(
                top: 8,
                right: 8,
                child: Material(
                  color: Colors.black.withValues(alpha: 0.55),
                  shape: const CircleBorder(),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: _sending
                        ? null
                        : () => setState(() => _image = null),
                    child: const Padding(
                      padding: EdgeInsets.all(6),
                      child: Icon(Icons.close, size: 18, color: Colors.white),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        _imageButtons(scheme, replace: true),
      ],
    );
  }

  /// ปุ่มกว้างพอดีคำ ไม่ยืดเต็มบรรทัด
  ///
  /// รูปเป็นของไม่บังคับ ยืดเป็นกรอบใหญ่สองอันจะเด่นกว่าช่องที่ต้องกรอกจริง
  Widget _imageButtons(ColorScheme scheme, {bool replace = false}) => Wrap(
    spacing: 8,
    runSpacing: 8,
    children: [
      _ImageButton(
        icon: Icons.photo_camera_outlined,
        label: replace ? 'ถ่ายใหม่' : 'ถ่ายรูป',
        onTap: _sending ? null : _capture,
      ),
      _ImageButton(
        icon: Icons.photo_library_outlined,
        label: replace ? 'เลือกใหม่' : 'เลือกรูป',
        onTap: _sending ? null : _pickFromGallery,
      ),
    ],
  );

  /// เซิร์ฟเวอร์ตอบสำเร็จแต่ลิสต์ว่าง จะมาลงที่นี่ ไม่ใช่หน้า error
  Widget _loadFailedNotice(ColorScheme scheme) => Row(
    children: [
      Expanded(
        child: Text(
          'ยังไม่มีรายการปัญหาให้เลือก ลองโหลดใหม่อีกครั้ง',
          style: TextStyle(fontSize: 13, height: 1.35, color: scheme.onSurface),
        ),
      ),
      const SizedBox(width: 6),
      TextButton(onPressed: _load, child: const Text('โหลดใหม่')),
    ],
  );

  /// ปุ่มส่งอยู่ท้ายฟอร์ม ไม่ใช่แถบติดขอบล่าง เหมือนฟอร์มอื่นของแอป
  Widget _submitButton() => FilledButton.icon(
    onPressed: _sending ? null : _submit,
    style: FilledButton.styleFrom(
      minimumSize: const Size.fromHeight(48),
      backgroundColor: AppColors.caseIcon,
      foregroundColor: Colors.white,
      // ครบแล้วค่อยเด่นเต็มที่ ยังไม่ครบก็ยังกดได้ แล้วบอกว่าขาดอะไร
      disabledBackgroundColor: AppColors.caseIcon.withValues(alpha: 0.4),
      disabledForegroundColor: Colors.white,
    ),
    icon: _sending
        ? const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Colors.white,
            ),
          )
        : Icon(_isComplete ? Icons.send : Icons.edit_outlined, size: 18),
    label: Text(_sending ? 'กำลังส่ง...' : 'ส่งเคส'),
  );
}

/// ตัวเลือกประเภทปัญหาหนึ่งตัว ไอคอนนำหน้าชื่อ
///
/// ใช้ภาษาเดียวกับป้ายสถานะของแจ้งซ่อม คือพื้นสีจางกับขอบสีเดียวกับตัวหนังสือ
/// ต่างแค่ตอนยังไม่เลือกจะเป็นสีกลางของธีม เลือกแล้วค่อยเปลี่ยนเป็นสีแจ้งเคส
///
/// ไอคอนประจำประเภทสลับเป็นติ๊กตอนเลือก ไม่ใช้แค่สีบอกว่าอันไหนถูกเลือก
/// คนตาบอดสีจะได้แยกออกด้วย และชิปกว้างเท่าเดิม แถวไม่ขยับตอนกดสลับไปมา
/// หนึ่งบรรทัดของตัวเลือกใน dropdown
///
/// เก็บหน้าตาเดิมตอนเป็นชิปไว้ทั้งหมด คือไอคอนประจำหมวดนำหน้าเสมอ (ไม่ถูก
/// ติ๊กมาแทนที่ เพราะไอคอนคือสิ่งที่ทำให้จำหมวดได้) และตัวที่เลือกอยู่เป็นสี
/// ของแจ้งเคสพร้อมติ๊กท้ายบรรทัด กางเมนูมาปุ๊บรู้ทันทีว่าค้างไว้ที่อันไหน
///
/// ตัวเดียวกันนี้ถูกใช้เป็นหน้าตาของช่องตอนปิดอยู่ด้วย (ผ่าน
/// selectedItemBuilder) แต่ส่ง [selected] เป็น false เพราะช่องที่ปิดอยู่
/// ไม่ต้องย้ำว่าเลือกแล้ว มันคือคำตอบอยู่ในตัวแล้ว
class _ItCaseOptionRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;

  const _ItCaseOptionRow({
    required this.icon,
    required this.label,
    required this.selected,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = selected ? AppColors.caseIcon : scheme.onSurface;

    return Row(
      children: [
        Icon(
          icon,
          size: 18,
          color: selected ? AppColors.caseIcon : scheme.onSurfaceVariant,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 14,
              height: 1.2,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              color: color,
            ),
          ),
        ),
        if (selected) ...[
          const SizedBox(width: 8),
          const Icon(Icons.check, size: 18, color: AppColors.caseIcon),
        ],
      ],
    );
  }
}

class _ImageButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  const _ImageButton({required this.icon, required this.label, this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Material(
      color: scheme.surface,
      shape: StadiumBorder(side: BorderSide(color: scheme.outlineVariant)),
      child: InkWell(
        onTap: onTap,
        customBorder: const StadiumBorder(),
        // ไอคอนอยู่ข้างคำ ไม่ใช่ซ้อนบน ปุ่มจะได้เตี้ยลงครึ่งหนึ่ง
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 14, 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 17, color: AppColors.caseIcon),
              const SizedBox(width: 7),
              Text(
                label,
                style: TextStyle(fontSize: 12.5, color: scheme.onSurface),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CaseNumberBox extends StatefulWidget {
  final String caseNumber;

  final VoidCallback onOpen;

  const _CaseNumberBox({required this.caseNumber, required this.onOpen});

  @override
  State<_CaseNumberBox> createState() => _CaseNumberBoxState();
}

class _CaseNumberBoxState extends State<_CaseNumberBox> {
  bool _copied = false;

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: widget.caseNumber));
    if (!mounted) return;
    setState(() => _copied = true);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final radius = BorderRadius.circular(_kImageRadius);

    // พื้นใสไปกับการ์ด ตัวเลขเป็นของที่เด่นเองอยู่แล้ว ไม่ต้องมีกล่องสีมาล้อม
    // ลูกศรท้ายแถวเป็นตัวบอกว่าแถวนี้กดเข้าไปต่อได้
    return Material(
      color: Colors.transparent,
      borderRadius: radius,
      child: InkWell(
        onTap: widget.onOpen,
        borderRadius: radius,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 6, 4, 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _copied ? 'คัดลอกแล้ว' : 'เลขเคส',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: _copied
                            ? AppColors.success
                            : scheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 2),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        widget.caseNumber,
                        style: const TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                          height: 1.1,
                          // เลขเคสต้องอ่านทีละตัวเพื่อจดหรือบอกทางโทรศัพท์
                          // เว้นวรรคระหว่างตัวอักษรกันอ่านข้ามหรือสลับตัว
                          letterSpacing: 0.8,
                          color: AppColors.caseIcon,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),

              // ปุ่มคัดลอกกินแตะของตัวเอง ไม่ทะลุไปเปิดหน้ารายละเอียด
              IconButton(
                tooltip: 'คัดลอกเลขเคส',
                onPressed: _copy,
                visualDensity: VisualDensity.compact,
                icon: Icon(
                  _copied ? Icons.check : Icons.copy_rounded,
                  size: 20,
                  color: _copied ? AppColors.success : AppColors.caseIcon,
                ),
              ),
              Icon(
                Icons.chevron_right,
                size: 22,
                color: scheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// รูปที่เลือกไว้ก่อนส่ง
///
/// อ่านเป็นไบต์แล้ววาดด้วย [Image.memory] แทน `Image.file` เพราะบนเว็บไม่มี
/// `dart:io` ให้สร้าง File และ path ของ [XFile] ฝั่งเว็บเป็น blob ที่เปิดแบบ
/// ไฟล์ไม่ได้ ทางนี้ใช้ได้เหมือนกันทั้งสองฝั่ง
class _Preview extends StatelessWidget {
  final XFile file;

  const _Preview({required this.file});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Uint8List>(
      // อ่านใหม่เมื่อเปลี่ยนรูป ไม่ใช่ค้างรูปเดิมเพราะ future ตัวเก่ายังอยู่
      key: ValueKey(file.path),
      future: file.readAsBytes(),
      builder: (context, snapshot) {
        final bytes = snapshot.data;
        if (bytes == null) {
          return const SizedBox(
            height: 150,
            child: Center(child: CircularProgressIndicator()),
          );
        }

        return Image.memory(
          bytes,
          height: 150,
          width: double.infinity,
          fit: BoxFit.cover,
        );
      },
    );
  }
}
