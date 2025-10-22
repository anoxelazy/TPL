// import 'package:flutter/material.dart';
// import 'package:intl/intl.dart';
// import 'package:claim/utils/app_logger.dart';

// class LogsPage extends StatefulWidget {
//   const LogsPage({super.key});

//   @override
//   State<LogsPage> createState() => _LogsPageState();
// }

// class _LogsPageState extends State<LogsPage> {
//   late Future<List<LogEntry>> _futureLogs;

//   @override
//   void initState() {
//     super.initState();
//     _futureLogs = AppLogger.I.list();
//   }

//   Future<void> _refresh() async {
//     setState(() {
//       _futureLogs = AppLogger.I.list();
//     });
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         centerTitle: false,
//         titleSpacing: 16,
//         backgroundColor: Theme.of(context).colorScheme.surface,
//         foregroundColor: Theme.of(context).colorScheme.onSurface,
//         title: Text(
//           'บันทึกการทำงาน',
//           style: Theme.of(context).textTheme.titleLarge?.copyWith(
//             color: Theme.of(context).colorScheme.onSurface,
//           ),
//         ),
//         actions: [
//           IconButton(
//             onPressed: () async {
//               await AppLogger.I.clear();
//               await _refresh();
//             },
//             icon: Icon(
//               Icons.delete_forever,
//               color: Theme.of(context).colorScheme.onSurface,
//             ),
//             tooltip: 'ล้างบันทึกทั้งหมด',
//           )
//         ],
//       ),
//       body: FutureBuilder<List<LogEntry>>(
//         future: _futureLogs,
//         builder: (context, snapshot) {
//           if (!snapshot.hasData) {
//             return const Center(child: CircularProgressIndicator());
//           }
//           final logs = snapshot.data!;
//           if (logs.isEmpty) {
//             return Center(
//               child: Text(
//                 'ยังไม่มีบันทึก',
//                 style: TextStyle(
//                   color: Theme.of(context).colorScheme.onSurface,
//                 ),
//               ),
//             );
//           }
//           return RefreshIndicator(
//             onRefresh: _refresh,
//             child: ListView.separated(
//               itemCount: logs.length,
//               separatorBuilder: (_, __) => const Divider(height: 1),
//               itemBuilder: (context, index) {
//                 final entry = logs[index];
//                 return ListTile(
//                   leading: Icon(
//                     Icons.event_note,
//                     color: Theme.of(context).colorScheme.onSurface,
//                   ),
//                   title: Text(
//                     entry.action,
//                     style: Theme.of(context)
//                         .textTheme
//                         .titleMedium
//                         ?.copyWith(
//                           fontWeight: FontWeight.w700,
//                           color: Theme.of(context).colorScheme.onSurface,
//                         ),
//                   ),
//                   subtitle: Column(
//                     crossAxisAlignment: CrossAxisAlignment.start,
//                     children: [
//                       Text(
//                         DateFormat('dd/MM/yyyy HH:mm:ss').format(entry.timestamp),
//                         style: TextStyle(
//                           color: Theme.of(context).colorScheme.onSurfaceVariant,
//                         ),
//                       ),
//                       if (entry.data != null)
//                         Text(
//                           entry.data.toString(),
//                           style: Theme.of(context).textTheme.bodyMedium?.copyWith(
//                             color: Theme.of(context).colorScheme.onSurfaceVariant,
//                           ),
//                         ),
//                     ],
//                   ),
//                 );
//               },
//             ),
//           );
//         },
//       ),
//     );
//   }
// }


