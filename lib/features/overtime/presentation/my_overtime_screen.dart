import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/error_translator.dart';
import '../../../core/formatters.dart';
import '../../../l10n/app_localizations.dart';
import '../providers/overtime_providers.dart';

class MyOvertimeScreen extends ConsumerWidget {
  const MyOvertimeScreen({super.key});

  String _statusLabel(AppLocalizations t, String? status) => switch (status) {
        'pending' => t.statusPending,
        'approved' => t.statusApproved,
        'rejected' => t.statusRejected,
        _ => status ?? '-',
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context)!;
    final requestsAsync = ref.watch(myOvertimeRequestsProvider);

    return Scaffold(
      appBar: AppBar(title: Text(t.overtimeTitle)),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await context.push('/overtime/new');
          ref.invalidate(myOvertimeRequestsProvider);
        },
        child: const Icon(Icons.add),
      ),
      body: requestsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(translateError(context, e))),
        data: (requests) {
          if (requests.isEmpty) {
            return Center(child: Text(t.noOvertimeRequestsMessage));
          }
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(myOvertimeRequestsProvider),
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
                      child: Icon(Icons.schedule_outlined, color: colorScheme.onPrimaryContainer),
                    ),
                    title: Text(formatDateLongFromString(r['date']?.toString()),
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text('${r['start_time']} — ${r['end_time']}'),
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
