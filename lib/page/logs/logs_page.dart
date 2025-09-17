import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_application_1/utils/app_logger.dart';

class LogsPage extends StatefulWidget {
  const LogsPage({super.key});

  @override
  State<LogsPage> createState() => _LogsPageState();
}

class _LogsPageState extends State<LogsPage> {
  late Future<List<LogEntry>> _futureLogs;

  @override
  void initState() {
    super.initState();
    _futureLogs = AppLogger.I.list();
  }

  Future<void> _refresh() async {
    setState(() {
      _futureLogs = AppLogger.I.list();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: false,
        titleSpacing: 16,
        title: Text('บันทึกการทำงาน', style: Theme.of(context).textTheme.titleLarge),
        actions: [
          IconButton(
            onPressed: () async {
              await AppLogger.I.clear();
              await _refresh();
            },
            icon: const Icon(Icons.delete_forever),
            tooltip: 'ล้างบันทึกทั้งหมด',
          )
        ],
      ),
      body: FutureBuilder<List<LogEntry>>(
        future: _futureLogs,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final logs = snapshot.data!;
          if (logs.isEmpty) {
            return const Center(child: Text('ยังไม่มีบันทึก'));
          }
          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView.separated(
              itemCount: logs.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final entry = logs[index];
                return ListTile(
                  leading: const Icon(Icons.event_note),
                  title: Text(
                    entry.action,
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(DateFormat('dd/MM/yyyy HH:mm:ss').format(entry.timestamp)),
                      if (entry.data != null)
                        Text(
                          entry.data.toString(),
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                    ],
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}


