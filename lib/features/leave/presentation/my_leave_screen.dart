import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/error_translator.dart';
import '../../../core/formatters.dart';
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

  IconData _typeIcon(String? type) => switch (type) {
        'cuti' => Icons.beach_access_outlined,
        'izin' => Icons.event_busy_outlined,
        'sakit' => Icons.local_hospital_outlined,
        _ => Icons.event_note_outlined,
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
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
              itemCount: requests.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, i) {
                final r = requests[i];
                final status = r['status']?.toString();
                final colorScheme = Theme.of(context).colorScheme;
                final (chipBg, chipFg) = switch (status) {
                  'approved' => (colorScheme.tertiaryContainer, colorScheme.onTertiaryContainer),
                  'rejected' => (colorScheme.errorContainer, colorScheme.onErrorContainer),
                  _ => (colorScheme.surfaceContainerHighest, colorScheme.onSurfaceVariant),
                };
                return Card(
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    leading: CircleAvatar(
                      backgroundColor: colorScheme.primaryContainer,
                      child: Icon(_typeIcon(r['type']?.toString()),
                          color: colorScheme.onPrimaryContainer),
                    ),
                    title: Text(_typeLabel(t, r['type']?.toString()),
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text(
                        '${formatDateLongFromString(r['start_date']?.toString())} - '
                        '${formatDateLongFromString(r['end_date']?.toString())}'),
                    trailing: Chip(
                      label: Text(_statusLabel(t, status)),
                      backgroundColor: chipBg,
                      labelStyle: TextStyle(color: chipFg),
                    ),
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
