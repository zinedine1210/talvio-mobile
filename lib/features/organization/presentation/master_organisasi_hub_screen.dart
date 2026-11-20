import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error_translator.dart';
import '../../../l10n/app_localizations.dart';
import '../../employee/providers/employee_providers.dart';
import '../../leave/presentation/approval_config_screen.dart';

/// "15 Master Organisasi" — figma's 2 tabs are Departemen/Approval routing.
/// Departemen tab reskins department_list_screen's list (IconBadge + name +
/// "X orang" count badge, computed client-side from employeeListProvider —
/// no backend employee_count field exists). Approval routing tab embeds the
/// existing, functionally-correct ApprovalConfigForm (figma's own edit
/// screens for this flow are broken/mismatched content, same pattern as the
/// Data Karyawan sub-screens — not implemented).
class MasterOrganisasiHubScreen extends ConsumerStatefulWidget {
  const MasterOrganisasiHubScreen({super.key});

  @override
  ConsumerState<MasterOrganisasiHubScreen> createState() => _MasterOrganisasiHubScreenState();
}

class _MasterOrganisasiHubScreenState extends ConsumerState<MasterOrganisasiHubScreen> {
  int _tab = 0;

  Future<void> _addDepartment() async {
    final t = AppLocalizations.of(context)!;
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(t.addDepartmentTitle),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(labelText: t.departmentNameLabel),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(t.cancelButton)),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: Text(t.saveButton),
          ),
        ],
      ),
    );
    if (name == null || name.isEmpty) return;
    try {
      await ref.read(employeeApiProvider).createDepartment(name);
      ref.invalidate(departmentListProvider);
    } on DioException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(translateError(context, e))));
    }
  }

  Future<void> _editDepartment(Map<String, dynamic> department) async {
    final t = AppLocalizations.of(context)!;
    final controller = TextEditingController(text: department['name']?.toString() ?? '');
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(t.editDepartmentTitle),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(labelText: t.departmentNameLabel),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(t.cancelButton)),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: Text(t.saveButton),
          ),
        ],
      ),
    );
    if (name == null || name.isEmpty) return;
    try {
      await ref.read(employeeApiProvider).updateDepartment(department['id'] as int, name);
      ref.invalidate(departmentListProvider);
    } on DioException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(translateError(context, e))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final departmentsAsync = ref.watch(departmentListProvider);
    final employeesAsync = ref.watch(employeeListProvider);

    final employeeCounts = <int, int>{};
    for (final e in employeesAsync.value ?? const <Map<String, dynamic>>[]) {
      final deptId = (e['department_id'] as num?)?.toInt();
      if (deptId != null) employeeCounts[deptId] = (employeeCounts[deptId] ?? 0) + 1;
    }

    return Scaffold(
      appBar: AppBar(title: Text(t.hrTileMasterOrg)),
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
                          label: [t.departmentsTitle, t.tabApprovalRouting][i],
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
                ? const ApprovalConfigForm()
                : Padding(
                    padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        InkWell(
                          onTap: _addDepartment,
                          borderRadius: BorderRadius.circular(14),
                          child: DecoratedBox(
                            decoration:
                                BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                              child: Row(
                                children: [
                                  const Icon(Icons.add, color: Color(0xFF0D9488), size: 18),
                                  const SizedBox(width: 10),
                                  Text(t.addDepartmentRowLabel,
                                      style: const TextStyle(
                                          color: Color(0xFF0D9488), fontWeight: FontWeight.w600)),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Expanded(
                          child: departmentsAsync.when(
                            loading: () => const Center(child: CircularProgressIndicator()),
                            error: (e, _) => Center(child: Text(translateError(context, e))),
                            data: (departments) {
                              if (departments.isEmpty) {
                                return Center(child: Text(t.noDepartmentsYet));
                              }
                              return RefreshIndicator(
                                onRefresh: () async => ref.invalidate(departmentListProvider),
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                      color: Colors.white, borderRadius: BorderRadius.circular(20)),
                                  child: ListView.separated(
                                    padding: const EdgeInsets.symmetric(vertical: 4),
                                    itemCount: departments.length,
                                    separatorBuilder: (_, _) =>
                                        const Divider(height: 1, indent: 70, endIndent: 16),
                                    itemBuilder: (context, i) {
                                      final department = departments[i];
                                      final count = employeeCounts[department['id'] as int] ?? 0;
                                      return ListTile(
                                        contentPadding:
                                            const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                        leading: Container(
                                          width: 40,
                                          height: 40,
                                          decoration: const BoxDecoration(
                                              color: Color(0xFFCCFBF1), shape: BoxShape.circle),
                                          child: const Icon(Icons.apartment_outlined,
                                              color: Color(0xFF0D9488), size: 20),
                                        ),
                                        title: Text(department['name']?.toString() ?? '-',
                                            style: const TextStyle(
                                                fontWeight: FontWeight.w600, color: Color(0xFF134E4A))),
                                        trailing: DecoratedBox(
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFF0FDFA),
                                            borderRadius: BorderRadius.circular(13),
                                          ),
                                          child: Padding(
                                            padding:
                                                const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                            child: Text(t.employeeCountLabel(count),
                                                style: const TextStyle(
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.w600,
                                                    color: Color(0xFF0D9488))),
                                          ),
                                        ),
                                        onTap: () => _editDepartment(department),
                                      );
                                    },
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
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
