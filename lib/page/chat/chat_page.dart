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
/// เคสต่อจากข้อความด้วย
class _Msg {
  final bool fromUser;
  final String text;
  final ChatReply? reply;

  /// เวลาที่ข้อความนี้โผล่บนจอ ใช้โชว์ข้าง ๆ ฟองแบบแอปแชตทั่วไป
  ///
  /// ไม่ใช่เวลาจากเซิร์ฟเวอร์ บอทไม่ได้ส่งมาให้ และคนอ่านสนใจแค่ว่าคุยกันตอนไหน
  final DateTime at;

  _Msg.user(this.text) : fromUser = true, reply = null, at = DateTime.now();

  _Msg.bot(this.reply) : fromUser = false, text = '', at = DateTime.now();

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

  /// ปุ่มลัดของคำตอบล่าสุด ไม่มีก็คืนรายการว่าง
  ///
  /// เอาของข้อความล่าสุดชุดเดียว ไม่ใช่ทุกข้อความ เพราะปุ่มไปอยู่เหนือช่องพิมพ์
  /// แบบ LINE แล้ว ของเก่าจะกลายเป็นปุ่มค้างที่กดแล้วงงว่าทำไมถามเรื่องเดิม
  List<String> get _quickReplies {
    if (_busy || _messages.isEmpty) return const [];

    final last = _messages.last;
    if (last.fromUser) return const [];

    return last.reply?.quickReplies ?? const [];
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final replies = _quickReplies;

    return Scaffold(
      // พื้นห้องแชทเข้มกว่าฟองข้อความนิดหนึ่ง ฟองจึงลอยขึ้นมาอ่านง่าย
      // แบบเดียวกับ LINE ที่พื้นหลังไม่ใช่สีขาวเปล่า
      backgroundColor: scheme.surfaceContainerHigh,
      appBar: repairAppBar(title: 'ติดตามสถานะซ่อม'),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scroll,
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
              // +1 สำหรับป้ายวันที่หัวห้อง
              itemCount: _messages.length + 1,
              itemBuilder: (context, index) {
                if (index == 0) return const _DateChip();

                final at = index - 1;
                final message = _messages[at];
                final previous = at == 0 ? null : _messages[at - 1];

                return _Bubble(
                  message: message,
                  onAsk: _send,
                  onLink: _open,
                  // ข้อความติดกันของคนเดียวกันไม่ต้องขึ้นรูปกับชื่อซ้ำ
                  // เหมือน LINE ที่โชว์เฉพาะก้อนแรกของชุด
                  headed:
                      previous == null || previous.fromUser != message.fromUser,
                );
              },
            ),
          ),
          if (_busy) const _Typing(),
          if (_error != null) _ErrorBar(message: _error!),
          if (replies.isNotEmpty)
            _QuickReplyBar(replies: replies, onTap: _send),
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

/// ข้อความหนึ่งก้อนพร้อมของที่ห้อยท้าย (การ์ดเคส ลิงก์)
///
/// วางแบบเดียวกับแอปแชตทั่วไป: รูปบอทกับชื่ออยู่ซ้าย ข้อความเราอยู่ขวา
/// เวลาเกาะอยู่ข้างฟองด้านนอก ไม่ใช่ในฟอง จะได้ไม่แย่งที่ข้อความ
class _Bubble extends StatelessWidget {
  final _Msg message;

  /// ก้อนแรกของชุด ต้องขึ้นรูปกับชื่อ ก้อนถัด ๆ ไปเว้นที่ไว้เฉย ๆ
  final bool headed;

  final void Function(String text) onAsk;
  final void Function(ChatLink link) onLink;

  const _Bubble({
    required this.message,
    required this.headed,
    required this.onAsk,
    required this.onLink,
  });

  @override
  Widget build(BuildContext context) {
    final fromUser = message.fromUser;

    return Padding(
      padding: EdgeInsets.only(top: headed ? 12 : 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: fromUser
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        children: [
          if (!fromUser) ...[
            // ก้อนถัดมาในชุดเดียวกันเว้นที่เท่ารูปไว้ ข้อความจะได้เรียงตรงกัน
            SizedBox(width: 34, child: headed ? const _BotAvatar() : null),
            const SizedBox(width: 8),
          ],
          if (fromUser) _Time(at: message.at),
          if (fromUser) const SizedBox(width: 6),
          Flexible(child: _content(context)),
          if (!fromUser) const SizedBox(width: 6),
          if (!fromUser) _Time(at: message.at),
        ],
      ),
    );
  }

  /// ชื่อบอท ฟองข้อความ และของที่ห้อยท้าย
  Widget _content(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final reply = message.reply;
    final fromUser = message.fromUser;

    return Column(
      crossAxisAlignment: fromUser
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      children: [
        if (!fromUser && headed) ...[
          Padding(
            padding: const EdgeInsets.only(left: 2, bottom: 3),
            child: Text(
              'รายงานจากแผนกไอที',
              style: TextStyle(fontSize: 11.5, color: scheme.onSurfaceVariant),
            ),
          ),
        ],

        ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.sizeOf(context).width * 0.72,
          ),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
            decoration: BoxDecoration(
              color: fromUser ? AppColors.repairIcon : scheme.surface,
              // มุมที่ชิดตัวคนพูดตัดตรง อีกสามมุมโค้ง เป็นหางฟองแบบง่าย ๆ
              // ที่บอกทิศได้โดยไม่ต้องวาดสามเหลี่ยม
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(16),
                topRight: const Radius.circular(16),
                bottomLeft: Radius.circular(fromUser ? 16 : 4),
                bottomRight: Radius.circular(fromUser ? 4 : 16),
              ),
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
            const SizedBox(height: 6),
            ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.sizeOf(context).width * 0.78,
              ),
              child: _TicketCard(ticket: ticket, onAsk: onAsk),
            ),
          ],

          if (reply.link?.isUsable == true) ...[
            const SizedBox(height: 6),
            OutlinedButton.icon(
              onPressed: () => onLink(reply.link!),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.repairIcon,
                backgroundColor: scheme.surface,
                visualDensity: VisualDensity.compact,
              ),
              icon: const Icon(Icons.open_in_new, size: 15),
              label: Text(
                reply.link!.label.isEmpty ? 'เปิดลิงก์' : reply.link!.label,
                style: const TextStyle(fontSize: 12.5),
              ),
            ),
          ],
        ],
      ],
    );
  }
}

/// รูปประจำตัวบอท
class _BotAvatar extends StatelessWidget {
  const _BotAvatar();

  @override
  Widget build(BuildContext context) => Container(
    width: 34,
    height: 34,
    alignment: Alignment.center,
    decoration: const BoxDecoration(
      color: AppColors.repairBg,
      shape: BoxShape.circle,
    ),
    child: const Icon(
      Icons.support_agent,
      size: 20,
      color: AppColors.repairIcon,
    ),
  );
}

/// เวลาข้างฟองข้อความ
class _Time extends StatelessWidget {
  final DateTime at;

  const _Time({required this.at});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 2),
    child: Text(
      DateFormat('HH:mm').format(at),
      style: TextStyle(
        fontSize: 10.5,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    ),
  );
}

/// ป้ายวันที่หัวห้อง
///
/// ห้องนี้เริ่มใหม่ทุกครั้งที่เปิดหน้า ไม่มีประวัติเก่าค้าง จึงมีป้ายเดียวพอ
/// ไม่ต้องคั่นกลางเหมือนแชตที่เก็บย้อนหลังได้
class _DateChip extends StatelessWidget {
  const _DateChip();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Center(
      child: Container(
        margin: const EdgeInsets.only(bottom: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          DateFormat('d MMM y', 'th').format(DateTime.now()),
          style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
        ),
      ),
    );
  }
}

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

/// แถบปุ่มลัดเหนือช่องพิมพ์
///
/// LINE วางปุ่มลัดไว้ตรงนี้ ไม่ใช่ใต้ฟองข้อความ เพราะเลื่อนอ่านย้อนขึ้นไปแล้ว
/// ปุ่มยังอยู่ที่เดิม กดได้ตลอดโดยไม่ต้องเลื่อนกลับลงมา
///
/// เลื่อนแนวนอนเผื่อปุ่มเยอะจนไม่พอในบรรทัดเดียว ไม่ตัดบรรทัดลงมากินที่จอ
class _QuickReplyBar extends StatelessWidget {
  final List<String> replies;
  final void Function(String text) onTap;

  const _QuickReplyBar({required this.replies, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return SizedBox(
      height: 46,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        itemCount: replies.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final text = replies[index];

          return ActionChip(
            label: Text(text, style: const TextStyle(fontSize: 12.5)),
            onPressed: () => onTap(text),
            backgroundColor: scheme.surface,
            side: const BorderSide(color: AppColors.repairIcon),
            labelStyle: const TextStyle(color: AppColors.repairIcon),
            visualDensity: VisualDensity.compact,
          );
        },
      ),
    );
  }
}
