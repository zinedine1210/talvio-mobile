import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error_translator.dart';
import '../../../core/formatters.dart';
import '../../../l10n/app_localizations.dart';
import '../../correction/presentation/correction_approvals_screen.dart';
import '../../employee/providers/employee_providers.dart';
import '../../leave/providers/leave_providers.dart';
import '../../overtime/providers/overtime_providers.dart';
import '../../attendance/providers/attendance_providers.dart';

/// "11 Persetujuan" — figma's 2 tabs are Menunggu/Koreksi. Menunggu merges
/// leave + overtime + wfh/out-of-radius review (same 3 sources
/// NotificationsScreen used to just group+count) into one card list; Koreksi
/// embeds CorrectionApprovalsList (its own compare-box layout, HR-only).
enum _Kind { leave, overtime, wfh }

class _PendingItem {
  _PendingItem({
    required this.kind,
    required this.id,
    required this.employeeId,
    required this.typeLabel,
    required this.subtitle,
  });
  final _Kind kind;
  final int id;
  final int? employeeId;
  final String typeLabel;
  final String subtitle;
}

class PersetujuanHubScreen extends ConsumerStatefulWidget {
  const PersetujuanHubScreen({super.key});

  @override
  ConsumerState<PersetujuanHubScreen> createState() => _PersetujuanHubScreenState();
}

class _PersetujuanHubScreenState extends ConsumerState<PersetujuanHubScreen> {
  int _tab = 0;

  String _leaveTypeLabel(AppLocalizations t, String? type) => switch (type) {
        'cuti' => t.leaveTypeCuti,
        'izin' => t.leaveTypeIzin,
        'sakit' => t.leaveTypeSakit,
        _ => type ?? '-',
      };

  Future<void> _actLeave(int id, bool approve) async {
    final t = AppLocalizations.of(context)!;
    try {
      if (approve) {
        await ref.read(leaveApiProvider).approve(id);
      } else {
        await ref.read(leaveApiProvider).reject(id);
      }
      ref.invalidate(leaveApprovalsProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t.leaveApprovalSuccessMessage)));
    } on DioException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(translateError(context, e))));
    }
  }

  Future<void> _actOvertime(int id, bool approve) async {
    final t = AppLocalizations.of(context)!;
    try {
      if (approve) {
        await ref.read(overtimeApiProvider).approve(id);
      } else {
        await ref.read(overtimeApiProvider).reject(id);
      }
      ref.invalidate(overtimeApprovalsProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t.leaveApprovalSuccessMessage)));
    } on DioException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(translateError(context, e))));
    }
  }

  Future<void> _actWfh(int id, bool approve) async {
    final t = AppLocalizations.of(context)!;
    String? note;
    if (!approve) {
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
      if (note == null) return;
    }
    try {
      await ref
          .read(attendanceApiProvider)
          .review(id, status: approve ? 'approved_wfh' : 'rejected', note: note);
      ref.invalidate(pendingReviewProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t.reviewSuccessMessage)));
    } on DioException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(translateError(context, e))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final leaveAsync = ref.watch(leaveApprovalsProvider);
    final overtimeAsync = ref.watch(overtimeApprovalsProvider);
    final wfhAsync = ref.watch(pendingReviewProvider);
    final employeesAsync = ref.watch(employeeListProvider);

    final loading = leaveAsync.isLoading || overtimeAsync.isLoading || wfhAsync.isLoading;
    final error = leaveAsync.hasError || overtimeAsync.hasError || wfhAsync.hasError;

    final employees = employeesAsync.value ?? const <Map<String, dynamic>>[];
    String? nameFor(int? employeeId) {
      final match = employees.where((e) => e['id'] == employeeId);
      return match.isNotEmpty ? match.first['name']?.toString() : null;
    }

    final items = <_PendingItem>[
      for (final r in leaveAsync.value ?? const <Map<String, dynamic>>[])
        _PendingItem(
          kind: _Kind.leave,
          id: r['id'] as int,
          employeeId: r['employee_id'] as int?,
          typeLabel: _leaveTypeLabel(t, r['type']?.toString()),
          subtitle: '${formatDateLongFromString(r['start_date']?.toString())} - '
              '${formatDateLongFromString(r['end_date']?.toString())}',
        ),
      for (final r in overtimeAsync.value ?? const <Map<String, dynamic>>[])
        _PendingItem(
          kind: _Kind.overtime,
          id: r['id'] as int,
          employeeId: r['employee_id'] as int?,
          typeLabel: t.overtimeMenu,
          subtitle: '${formatDateLongFromString(r['date']?.toString())}, '
              '${r['start_time']} - ${r['end_time']}',
        ),
      for (final r in wfhAsync.value ?? const <Map<String, dynamic>>[])
        _PendingItem(
          kind: _Kind.wfh,
          id: r['id'] as int,
          employeeId: r['employee_id'] as int?,
          typeLabel: t.pendingReviewTitle,
          subtitle: formatDateLongFromString(r['date']?.toString()),
        ),
    ];

    return Scaffold(
      appBar: AppBar(title: Text(t.persetujuanTitle)),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
            child: DecoratedBox(
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Row(
                  children: [
                    for (var i = 0; i < 2; i++)
                      Expanded(
                        child: _TabPill(
                          label: [t.tabMenunggu, t.tabKoreksi][i],
                          selected: _tab == i,
                          onTap: () => setState(() => _tab = i),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: _tab == 1
                ? const CorrectionApprovalsList()
                : loading
                    ? const Center(child: CircularProgressIndicator())
                    : error
                        ? Center(child: Text(t.errorGeneric))
                        : items.isEmpty
                            ? Center(child: Text(t.noLeaveApprovalsMessage))
                            : RefreshIndicator(
                                onRefresh: () async {
                                  ref.invalidate(leaveApprovalsProvider);
                                  ref.invalidate(overtimeApprovalsProvider);
                                  ref.invalidate(pendingReviewProvider);
                                },
                                child: ListView.separated(
                                  padding: const EdgeInsets.all(24),
                                  itemCount: items.length,
                                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                                  itemBuilder: (context, i) {
                                    final item = items[i];
                                    final name = nameFor(item.employeeId) ?? '-';
                                    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
                                    return DecoratedBox(
                                      decoration: BoxDecoration(
                                          color: Colors.white, borderRadius: BorderRadius.circular(20)),
                                      child: Padding(
                                        padding: const EdgeInsets.all(16),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                CircleAvatar(
                                                  backgroundColor: const Color(0xFFCCFBF1),
                                                  child: Text(initial,
                                                      style: const TextStyle(
                                                          color: Color(0xFF0D9488),
                                                          fontWeight: FontWeight.w700)),
                                                ),
                                                const SizedBox(width: 12),
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    children: [
                                                      Text(name,
                                                          style: const TextStyle(
                                                              fontWeight: FontWeight.w600,
                                                              color: Color(0xFF134E4A))),
                                                      Text(item.typeLabel,
                                                          style: const TextStyle(
                                                              color: Color(0xFF475569), fontSize: 12)),
                                                    ],
                                                  ),
                                                ),
                                                DecoratedBox(
                                                  decoration: BoxDecoration(
                                                    color: const Color(0xFFFFEDD5),
                                                    borderRadius: BorderRadius.circular(13),
                                                  ),
                                                  child: Padding(
                                                    padding: const EdgeInsets.symmetric(
                                                        horizontal: 10, vertical: 6),
                                                    child: Text(t.pendingBadgeLabel,
                                                        style: const TextStyle(
                                                            fontSize: 11,
                                                            fontWeight: FontWeight.w600,
                                                            color: Color(0xFF9A3412))),
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 12),
                                            Text(item.subtitle,
                                                style: const TextStyle(
                                                    color: Color(0xFF134E4A), fontSize: 13)),
                                            const SizedBox(height: 16),
                                            Row(
                                              children: [
                                                Expanded(
                                                  child: OutlinedButton(
                                                    onPressed: () => switch (item.kind) {
                                                      _Kind.leave => _actLeave(item.id, false),
                                                      _Kind.overtime => _actOvertime(item.id, false),
                                                      _Kind.wfh => _actWfh(item.id, false),
                                                    },
                                                    child: Text(t.rejectButton),
                                                  ),
                                                ),
                                                const SizedBox(width: 12),
                                                Expanded(
                                                  child: FilledButton(
                                                    onPressed: () => switch (item.kind) {
                                                      _Kind.leave => _actLeave(item.id, true),
                                                      _Kind.overtime => _actOvertime(item.id, true),
                                                      _Kind.wfh => _actWfh(item.id, true),
                                                    },
                                                    child: Text(t.approveButton),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
          ),
        ],
      ),
    );
  }
}

class _TabPill extends StatelessWidget {
  const _TabPill({required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        height: 40,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF0D9488) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 13,
            color: selected ? Colors.white : const Color(0xFF475569),
          ),
        ),
      ),
    );
  }
}
