import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class ClaimCard extends StatelessWidget {
  final Map<String, dynamic> claim;
  final int index;
  final VoidCallback onEdit;
  final VoidCallback onSend;

  const ClaimCard({
    super.key,
    required this.claim,
    required this.index,
    required this.onEdit,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    final DateTime timestamp = claim['timestamp'] ?? DateTime.now();
    final bool isSent = claim['isSent'] ?? false;
    final String type = claim['type'] ?? '';
    final String remarkType = claim['remarkType']?.toString() ?? '';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Card(
        elevation: 2,
        color: isSent
            ? Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3)
            : Theme.of(context).colorScheme.surface,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'เลขเอกสาร: ${claim['docNumber']}',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                    ),
                    Text(
                      'รหัสรถ: ${claim['carCode']}',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                    ),
                    Text(
                      'ประเภท: $type',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                    ),
                    if ((type == 'เสียหาย' ||
                            type == 'สูญหาย' ||
                            type == 'ไม่ครบล็อต') &&
                        remarkType.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          type == 'เสียหาย'
                              ? 'รายละเอียดความเสียหาย: $remarkType'
                              : type == 'สูญหาย'
                                  ? 'รายละเอียดการสูญหาย: $remarkType'
                                  : 'รายละเอียดเพิ่มเติม: $remarkType',
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    fontStyle: FontStyle.italic,
                                  ),
                          maxLines: 4,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    Text(
                      'วันที่: ${DateFormat('dd/MM/yyyy').format(timestamp)}',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 80,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: Icon(
                        Icons.edit,
                        color: Theme.of(context).colorScheme.primary,
                        size: 40,
                      ),
                      tooltip: 'แก้ไขข้อมูล',
                      onPressed: onEdit,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                    const SizedBox(height: 12),
                    IconButton(
                      icon: Icon(
                        Icons.send,
                        color: Theme.of(context).colorScheme.error,
                        size: 45,
                      ),
                      tooltip: 'ส่งรายการนี้ไป Google Sheet',
                      onPressed: onSend,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'กดส่งรายงาน',
                      style: TextStyle(
                        fontSize: 14,
                        color: Theme.of(context).colorScheme.error,
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
