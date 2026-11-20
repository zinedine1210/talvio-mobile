import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../l10n/app_localizations.dart';
import '../providers/employee_providers.dart';

class EmployeeListScreen extends ConsumerStatefulWidget {
  const EmployeeListScreen({super.key});

  @override
  ConsumerState<EmployeeListScreen> createState() => _EmployeeListScreenState();
}

class _EmployeeListScreenState extends ConsumerState<EmployeeListScreen> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final employeesAsync = ref.watch(employeeListProvider);
    final departmentsAsync = ref.watch(departmentListProvider);
    final departmentNames = <int, String>{
      for (final d in departmentsAsync.value ?? const <Map<String, dynamic>>[])
        (d['id'] as num).toInt(): d['name']?.toString() ?? '-',
    };

    return Scaffold(
      appBar: AppBar(
        title: Text(t.employeesTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () async {
              await context.push('/employees/new');
              ref.invalidate(employeeListProvider);
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _searchController,
              onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
              decoration: InputDecoration(
                hintText: t.searchEmployeeHint,
                prefixIcon: const Icon(Icons.search),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: employeesAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text(t.errorGeneric)),
                data: (employees) {
                  final filtered = _query.isEmpty
                      ? employees
                      : employees
                          .where((e) => (e['name']?.toString() ?? '').toLowerCase().contains(_query))
                          .toList();
                  if (filtered.isEmpty) {
                    return Center(child: Text(t.noEmployeesYet));
                  }
                  return RefreshIndicator(
                    onRefresh: () async => ref.invalidate(employeeListProvider),
                    child: DecoratedBox(
                      decoration:
                          BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
                      child: ListView.separated(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        itemCount: filtered.length,
                        separatorBuilder: (_, _) =>
                            const Divider(height: 1, indent: 70, endIndent: 16),
                        itemBuilder: (context, i) {
                          final e = filtered[i];
                          final name = e['name']?.toString() ?? '-';
                          final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
                          final photoUrl = e['photo_url']?.toString();
                          final hasPhoto = photoUrl != null && photoUrl.isNotEmpty;
                          final deptId = (e['department_id'] as num?)?.toInt();
                          final deptName = deptId != null ? departmentNames[deptId] : null;
                          final position = e['position']?.toString();
                          final subtitle = [
                            if (deptName != null) deptName,
                            if (position != null && position.isNotEmpty) position,
                          ].join(', ');
                          return ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            leading: CircleAvatar(
                              backgroundColor: const Color(0xFFCCFBF1),
                              backgroundImage: hasPhoto ? NetworkImage(photoUrl) : null,
                              child: hasPhoto
                                  ? null
                                  : Text(initial,
                                      style: const TextStyle(
                                          color: Color(0xFF0D9488), fontWeight: FontWeight.w700)),
                            ),
                            title: Text(name,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600, color: Color(0xFF134E4A))),
                            subtitle: subtitle.isEmpty
                                ? null
                                : Text(subtitle, style: const TextStyle(color: Color(0xFF475569))),
                            trailing: const Icon(Icons.chevron_right, color: Color(0xFF94A3B8)),
                            onTap: () async {
                              await context.push('/employees/edit', extra: e);
                              ref.invalidate(employeeListProvider);
                            },
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
    );
  }
}
