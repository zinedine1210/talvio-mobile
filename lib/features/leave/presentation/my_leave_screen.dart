import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/error_translator.dart';
import '../../../l10n/app_localizations.dart';
import '../providers/leave_providers.dart';

class MyLeaveScreen extends ConsumerWidget {
  const MyLeaveScreen({super.key});

  String _typeLabel(AppLocalizations t, String? type) => switch (type) {
        'cuti' => t.leaveTypeCuti,
        'izin' => t.leaveTypeIzin,
        'sakit' => t.leaveTypeSakit,
        _ => type ?? '-',
      };

  String _statusLabel(AppLocalizations t, String? status) => switch (status) {
        'pending' => t.statusPending,
        'approved' => t.statusApproved,
        'rejected' => t.statusRejected,
        _ => status ?? '-',
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context)!;
    final requestsAsync = ref.watch(myLeaveRequestsProvider);

    return Scaffold(
      appBar: AppBar(title: Text(t.leaveTitle)),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await context.push('/leave/new');
          ref.invalidate(myLeaveRequestsProvider);
        },
        child: const Icon(Icons.add),
      ),
      body: requestsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(translateError(context, e))),
        data: (requests) {
          if (requests.isEmpty) {
            return Center(child: Text(t.noLeaveRequestsMessage));
          }
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(myLeaveRequestsProvider),
            child: ListView.separated(
              itemCount: requests.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, i) {
                final r = requests[i];
                return ListTile(
                  title: Text(_typeLabel(t, r['type']?.toString())),
                  subtitle: Text('${r['start_date']} — ${r['end_date']}'),
                  trailing: Chip(label: Text(_statusLabel(t, r['status']?.toString()))),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
