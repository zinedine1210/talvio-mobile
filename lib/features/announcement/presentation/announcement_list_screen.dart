import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api_client.dart';
import '../../../core/error_translator.dart';
import '../../../core/formatters.dart';
import '../../../l10n/app_localizations.dart';
import '../providers/announcement_providers.dart';

class AnnouncementListScreen extends ConsumerWidget {
  const AnnouncementListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context)!;
    final announcementsAsync = ref.watch(announcementListProvider);
    final isHr = ref.watch(currentEmployeeProvider)?['role'] == 'hr_admin';

    return Scaffold(
      appBar: AppBar(title: Text(t.announcementsTitle)),
      floatingActionButton: isHr
          ? FloatingActionButton(
              onPressed: () async {
                await context.push('/announcements/new');
                ref.invalidate(announcementListProvider);
              },
              child: const Icon(Icons.add),
            )
          : null,
      body: announcementsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(translateError(context, e))),
        data: (announcements) {
          if (announcements.isEmpty) {
            return Center(child: Text(t.noAnnouncementsMessage));
          }
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(announcementListProvider),
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
              itemCount: announcements.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, i) {
                final a = announcements[i];
                final created = DateTime.tryParse(a['created_at']?.toString() ?? '');
                return InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: () => context.push('/announcements/detail', extra: a),
                  child: DecoratedBox(
                    decoration:
                        BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: const BoxDecoration(
                                color: Color(0xFFCCFBF1), shape: BoxShape.circle),
                            child: const Icon(Icons.campaign_outlined,
                                color: Color(0xFF0D9488), size: 20),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(a['title']?.toString() ?? '-',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w700, color: Color(0xFF134E4A))),
                                const SizedBox(height: 4),
                                Text(
                                  a['body']?.toString() ?? '',
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(color: Color(0xFF475569), fontSize: 13),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  created != null ? formatRelativeTime(created) : '',
                                  style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
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
