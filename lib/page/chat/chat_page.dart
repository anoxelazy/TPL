import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:claim/page/chat/chat_api.dart';
import 'package:claim/page/repair/repair_api.dart';
import 'package:claim/page/repair/repair_appbar.dart';
import 'package:claim/page/repair/repair_style.dart';
import 'package:claim/utils/app_colors.dart';
import 'package:claim/widgets/app_card.dart';

/// หน้าแชทติดตามสถานะงานซ่อม
///
/// บอทอยู่ฝั่งเซิร์ฟเวอร์ทั้งหมดและเป็นเมนูกับคำสั่งตายตัว ไม่ใช้ LLM หน้านี้จึง
/// ไม่มี logic ของบอทเลยสักบรรทัด ทำแค่ส่งข้อความไปแล้ววาดสิ่งที่ตอบกลับมา
/// เว็บกับ LINE เรียกตัวเดียวกัน คำตอบจึงตรงกันทุกช่องทาง
///
/// บอทอ่านอย่างเดียว แจ้งซ่อมหรือแก้ใบผ่านบอทไม่ได้ ถ้าผู้ใช้พิมพ์ว่าอยากแจ้งซ่อม
/// บอทจะตอบเป็นลิงก์ให้ไปทำที่ฟอร์มจริง
class ChatPage extends StatefulWidget {
  const ChatPage({super.key});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

/// ข้อความหนึ่งบรรทัดในห้องแชท
///
/// ของผู้ใช้มีแค่ข้อความ ของบอทถือ [ChatReply] ทั้งก้อนไว้ เพราะต้องวาดการ์ด
/// เคสกับปุ่มลัดต่อจากข้อความด้วย
class _Msg {
  final bool fromUser;
  final String text;
  final ChatReply? reply;

  const _Msg.user(this.text) : fromUser = true, reply = null;
  const _Msg.bot(this.reply) : fromUser = false, text = '';

  /// ข้อความที่จะโชว์ ของบอทเอามาจากคำตอบ
  String get body => fromUser ? text : (reply?.text ?? '');
}

class _ChatPageState extends State<ChatPage> {
  final _input = TextEditingController();
  final _scroll = ScrollController();

  final List<_Msg> _messages = [];

  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    // เปิดมาถามเมนูให้เลย ผู้ใช้จะได้เห็นว่าพิมพ์อะไรได้บ้างโดยไม่ต้องเดา
    _send('ช่วยเหลือ', silent: true);
  }

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  /// ส่งข้อความหาบอท
  ///
  /// [silent] ใช้ตอนเปิดหน้าจอ ไม่ต้องโชว์ว่าเราพิมพ์ "ช่วยเหลือ" ไป
  /// เพราะผู้ใช้ไม่ได้พิมพ์เอง เห็นแล้วจะงงว่าใครพิมพ์
  Future<void> _send(String text, {bool silent = false}) async {
    final message = text.trim();
    if (message.isEmpty || _busy) return;

    setState(() {
      if (!silent) _messages.add(_Msg.user(message));
      _busy = true;
      _error = null;
    });
    _input.clear();
    _toBottom();

    try {
      final reply = await askChatbot(message);
      if (!mounted) return;
      setState(() {
        _messages.add(_Msg.bot(reply));
        _busy = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }

    _toBottom();
  }

  /// เลื่อนลงล่างสุดหลังเฟรมถัดไป
  ///
  /// เลื่อนทันทีไม่ได้ ข้อความที่เพิ่งเพิ่มยังไม่ถูกวาด ความสูงจึงยังเป็นของเก่า
  void _toBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;

      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _open(ChatLink link) async {
    final uri = Uri.tryParse(link.url);
    if (uri == null) return;

    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: scheme.surfaceContainerLowest,
      appBar: repairAppBar(title: 'ติดตามสถานะซ่อม'),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scroll,
              padding: const EdgeInsets.fromLTRB(12, 16, 12, 8),
              itemCount: _messages.length,
              itemBuilder: (context, index) => _Bubble(
                message: _messages[index],
                onQuickReply: _send,
                onLink: _open,
                // ปุ่มลัดโชว์เฉพาะข้อความล่าสุด ของเก่าเลื่อนขึ้นไปแล้วกดไม่ได้
                // ไม่งั้นจอจะเต็มไปด้วยปุ่มซ้ำ ๆ ที่ไม่มีใครกด
                showQuickReplies: index == _messages.length - 1 && !_busy,
              ),
            ),
          ),
          if (_busy) const _Typing(),
          if (_error != null) _ErrorBar(message: _error!),
          _InputBar(
            controller: _input,
            enabled: !_busy,
            onSend: () => _send(_input.text),
          ),
        ],
      ),
    );
  }
}

/// ข้อความหนึ่งก้อนพร้อมของที่ห้อยท้าย (การ์ดเคส ปุ่มลัด ลิงก์)
class _Bubble extends StatelessWidget {
  final _Msg message;
  final bool showQuickReplies;
  final void Function(String text) onQuickReply;
  final void Function(ChatLink link) onLink;

  const _Bubble({
    required this.message,
    required this.showQuickReplies,
    required this.onQuickReply,
    required this.onLink,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final reply = message.reply;
    final fromUser = message.fromUser;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: fromUser
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          // ข้อความของเราชิดขวาพื้นสีเข้ม ของบอทชิดซ้ายพื้นการ์ด
          // แบบเดียวกับแอปแชตทั่วไป ไม่ต้องมีชื่อคนพูดกำกับ
          ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.sizeOf(context).width * 0.82,
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: fromUser ? AppColors.repairIcon : scheme.surface,
                borderRadius: BorderRadius.circular(14).copyWith(
                  bottomRight: fromUser ? Radius.zero : null,
                  bottomLeft: fromUser ? null : Radius.zero,
                ),
                border: fromUser
                    ? null
                    : Border.all(color: scheme.outlineVariant, width: 0.5),
              ),
              child: SelectableText(
                message.body.isEmpty ? '-' : message.body,
                style: TextStyle(
                  fontSize: 14,
                  height: 1.45,
                  color: fromUser ? Colors.white : scheme.onSurface,
                ),
              ),
            ),
          ),

          if (reply != null) ...[
            for (final ticket in reply.tickets) ...[
              const SizedBox(height: 8),
              _TicketCard(ticket: ticket, onAsk: onQuickReply),
            ],

            if (reply.link?.isUsable == true) ...[
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () => onLink(reply.link!),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.repairIcon,
                ),
                icon: const Icon(Icons.open_in_new, size: 16),
                label: Text(
                  reply.link!.label.isEmpty ? 'เปิดลิงก์' : reply.link!.label,
                ),
              ),
            ],

            if (showQuickReplies && reply.quickReplies.isNotEmpty) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final text in reply.quickReplies)
                    ActionChip(
                      label: Text(text, style: const TextStyle(fontSize: 12.5)),
                      onPressed: () => onQuickReply(text),
                      side: BorderSide(color: AppColors.repairIcon),
                      labelStyle: const TextStyle(color: AppColors.repairIcon),
                      backgroundColor: scheme.surface,
                    ),
                ],
              ),
            ],
          ],
        ],
      ),
    );
  }
}

/// การ์ดเคสที่บอทส่งมา
///
/// กดแล้วถามบอทต่อด้วยเลขเคสนั้น เป็นทางลัดแทนการพิมพ์ TK-42 เอง
class _TicketCard extends StatelessWidget {
  final ChatTicket ticket;
  final void Function(String text) onAsk;

  const _TicketCard({required this.ticket, required this.onAsk});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    // บอทส่งรหัสสถานะดิบมา แปลงเป็น enum ของแอปเพื่อเอาสีชุดเดียวกับหน้าแจ้งซ่อม
    // ส่วนป้ายข้อความใช้ของบอท ไม่ใช่ของ enum เผื่อ IT เพิ่มสถานะใหม่
    final status = RepairStatus.fromCode(ticket.status);
    final color = repairStatusColor(status, scheme);
    final created = ticket.createdAt;

    return AppCard(
      onTap: ticket.id == null ? null : () => onAsk(ticket.code),
      color: repairCardColor(status, scheme),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  ticket.deviceName.isEmpty ? '-' : ticket.deviceName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                    color: scheme.onSurface,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: color),
                ),
                child: Text(
                  ticket.statusLabel.isEmpty
                      ? status.label
                      : ticket.statusLabel,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
              ),
            ],
          ),

          if (ticket.issue.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              ticket.issue,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 13, color: scheme.onSurface),
            ),
          ],

          const SizedBox(height: 10),
          Wrap(
            spacing: 12,
            runSpacing: 4,
            children: [
              if (ticket.code.isNotEmpty)
                _meta(scheme, Icons.confirmation_number_outlined, ticket.code),
              if (ticket.sn.isNotEmpty) _meta(scheme, Icons.tag, ticket.sn),
              if (ticket.technician.isNotEmpty)
                _meta(scheme, Icons.engineering_outlined, ticket.technician),
              if (ticket.imageCount > 0)
                _meta(scheme, Icons.photo_outlined, '${ticket.imageCount} รูป'),
              if (created != null)
                _meta(
                  scheme,
                  Icons.schedule,
                  DateFormat('d MMM y HH:mm', 'th').format(created),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _meta(ColorScheme scheme, IconData icon, String text) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 13, color: scheme.onSurfaceVariant),
      const SizedBox(width: 4),
      Text(
        text,
        style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
      ),
    ],
  );
}

/// จุดสามจุดตอนบอทกำลังคิด
///
/// บอทตอบเร็วมาก (ไม่ได้ถาม LLM) แต่ถ้าไม่มีอะไรขึ้นเลยระหว่างรอ คนจะกดส่งซ้ำ
class _Typing extends StatelessWidget {
  const _Typing();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'กำลังตอบ...',
              style: TextStyle(fontSize: 12.5, color: scheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

/// แถบแจ้งว่าส่งไม่สำเร็จ
///
/// ไม่ใช้ snackbar เพราะมันหายเองแล้วคนที่มองจออยู่จะไม่รู้ว่าทำไมไม่มีคำตอบ
class _ErrorBar extends StatelessWidget {
  final String message;

  const _ErrorBar({required this.message});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      color: scheme.errorContainer,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Icon(
            Icons.cloud_off_outlined,
            size: 16,
            color: scheme.onErrorContainer,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(fontSize: 12.5, color: scheme.onErrorContainer),
            ),
          ),
        ],
      ),
    );
  }
}

/// ช่องพิมพ์กับปุ่มส่ง
class _InputBar extends StatelessWidget {
  final TextEditingController controller;
  final bool enabled;
  final VoidCallback onSend;

  const _InputBar({
    required this.controller,
    required this.enabled,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        decoration: BoxDecoration(
          color: scheme.surface,
          border: Border(top: BorderSide(color: scheme.outlineVariant)),
        ),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                enabled: enabled,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => onSend(),
                decoration: InputDecoration(
                  hintText: 'พิมพ์เลขเคส หรือ S/N',
                  isDense: true,
                  filled: true,
                  fillColor: scheme.surfaceContainerHighest,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(
              onPressed: enabled ? onSend : null,
              style: IconButton.styleFrom(
                backgroundColor: AppColors.repairIcon,
                foregroundColor: Colors.white,
              ),
              icon: const Icon(Icons.send_rounded, size: 20),
            ),
          ],
        ),
      ),
    );
  }
}
