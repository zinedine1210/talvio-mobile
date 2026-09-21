import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error_translator.dart';
import '../../../l10n/app_localizations.dart';
import '../../employee/providers/employee_providers.dart';
import '../providers/attendance_providers.dart';

/// HR-only screen: attendance records flagged pending_review (outside
/// radius and/or an uncertain/mismatched on-device face check) — the
/// human-override safety net SPEC.md's "Face Verification" section
/// requires alongside automated on-device matching.
class PendingReviewScreen extends ConsumerWidget {
  const PendingReviewScreen({super.key});

  Future<void> _review(BuildContext context, WidgetRef ref, int id, String status) async {
    final t = AppLocalizations.of(context)!;
    String? note;
    if (status == 'rejected') {
      final controller = TextEditingController();
      note = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(t.rejectButton),
          content: TextField(
            controller: controller,
            decoration: InputDecoration(labelText: t.hrNoteLabel),
            maxLines: 3,
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(t.cancelButton)),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(controller.text.trim()),
              child: Text(t.submitButton),
            ),
          ],
        ),
      );
      if (note == null) return; // cancelled
    }
    try {
      await ref.read(attendanceApiProvider).review(id, status: status, note: note);
      ref.invalidate(pendingReviewProvider);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(t.reviewSuccessMessage)));
    } on DioException catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(translateError(context, e))));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context)!;
    final pendingAsync = ref.watch(pendingReviewProvider);
    final employeesAsync = ref.watch(employeeListProvider);

    return Scaffold(
      appBar: AppBar(title: Text(t.pendingReviewTitle)),
      body: pendingAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(translateError(context, e))),
        data: (records) {
          if (records.isEmpty) {
            return Center(child: Text(t.noPendingReviewMessage));
          }
          final employees = employeesAsync.value ?? const [];
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(pendingReviewProvider),
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: records.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, i) {
                final r = records[i];
                final employee = employees.where((e) => e['id'] == r['employee_id']);
                final employeeName = employee.isNotEmpty ? employee.first['name']?.toString() : null;
                final withinIn = r['is_within_radius_in'] == true;
                final faceStatus = r['face_match_status']?.toString();
                final note = r['note']?.toString();

                final colorScheme = Theme.of(context).colorScheme;
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 18,
                              backgroundColor: colorScheme.primaryContainer,
                              child: Icon(Icons.person_outline,
                                  size: 18, color: colorScheme.onPrimaryContainer),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(employeeName ?? 'Employee #${r['employee_id']}',
                                      style: const TextStyle(fontWeight: FontWeight.w700)),
                                  Text(r['date']?.toString() ?? '-',
                                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                          color: colorScheme.onSurfaceVariant)),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            if ((r['clock_in_photo_url'] as String?)?.isNotEmpty == true)
                              Expanded(child: _PhotoThumb(t.clockInPhotoLabel, r['clock_in_photo_url'])),
                            if ((r['clock_out_photo_url'] as String?)?.isNotEmpty == true)
                              Expanded(child: _PhotoThumb(t.clockOutPhotoLabel, r['clock_out_photo_url'])),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            Chip(
                              avatar: Icon(
                                withinIn ? Icons.check_circle_outline : Icons.error_outline,
                                size: 18,
                                color: withinIn ? colorScheme.onTertiaryContainer : colorScheme.onErrorContainer,
                              ),
                              label: Text(withinIn ? t.withinRadiusLabel : t.outsideRadiusLabel),
                              backgroundColor:
                                  withinIn ? colorScheme.tertiaryContainer : colorScheme.errorContainer,
                            ),
                            if (faceStatus != null)
                              Chip(
                                avatar: Icon(Icons.face_retouching_natural, size: 18,
                                    color: colorScheme.onSecondaryContainer),
                                label: Text('${t.faceMatchLabel}: $faceStatus'),
                                backgroundColor: colorScheme.secondaryContainer,
                              ),
                          ],
                        ),
                        if (note != null && note.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text('${t.hrNoteLabel}: $note',
                              style: Theme.of(context).textTheme.bodyMedium),
                        ],
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton(
                              onPressed: () => _review(context, ref, r['id'] as int, 'rejected'),
                              child: Text(t.rejectButton),
                            ),
                            const SizedBox(width: 8),
                            FilledButton(
                              onPressed: () => _review(context, ref, r['id'] as int, 'approved_wfh'),
                              child: Text(t.approveButton),
                            ),
                          ],
                        ),
                      ],
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

class _PhotoThumb extends StatelessWidget {
  const _PhotoThumb(this.label, this.url);
  final String label;
  final String url;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(label, style: Theme.of(context).textTheme.labelSmall),
        const SizedBox(height: 4),
        GestureDetector(
          onTap: () => showDialog(
            context: context,
            builder: (context) => Dialog(child: Image.network(url)),
          ),
          child: Image.network(url, height: 80, fit: BoxFit.cover),
        ),
      ],
    );
  }
}
