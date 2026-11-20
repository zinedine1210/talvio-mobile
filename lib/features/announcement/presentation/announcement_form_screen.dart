import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/error_translator.dart';
import '../../../l10n/app_localizations.dart';
import '../../employee/providers/employee_providers.dart';
import '../providers/announcement_providers.dart';

class AnnouncementFormScreen extends ConsumerStatefulWidget {
  const AnnouncementFormScreen({super.key});

  @override
  ConsumerState<AnnouncementFormScreen> createState() => _AnnouncementFormScreenState();
}

class _AnnouncementFormScreenState extends ConsumerState<AnnouncementFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _bodyController = TextEditingController();
  String _target = 'all';
  int? _departmentId;
  bool _isSaving = false;

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final t = AppLocalizations.of(context)!;
    if (!_formKey.currentState!.validate()) return;
    if (_target == 'department' && _departmentId == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t.requiredField)));
      return;
    }
    setState(() => _isSaving = true);
    try {
      await ref.read(announcementApiProvider).createAnnouncement(
            title: _titleController.text.trim(),
            body: _bodyController.text.trim(),
            target: _target,
            departmentId: _target == 'department' ? _departmentId : null,
          );
      ref.invalidate(announcementListProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(t.announcementSubmittedMessage)));
      context.pop();
    } on DioException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(translateError(context, e))));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final departmentsAsync = ref.watch(departmentListProvider);

    return Scaffold(
      appBar: AppBar(title: Text(t.newAnnouncementTitle)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      TextFormField(
                        controller: _titleController,
                        decoration: InputDecoration(labelText: t.announcementTitleLabel),
                        validator: (v) => (v == null || v.trim().isEmpty) ? t.requiredField : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _bodyController,
                        decoration: InputDecoration(labelText: t.announcementBodyLabel),
                        maxLines: 4,
                        validator: (v) => (v == null || v.trim().isEmpty) ? t.requiredField : null,
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        initialValue: _target,
                        decoration: InputDecoration(labelText: t.announcementTargetLabel),
                        items: [
                          DropdownMenuItem(value: 'all', child: Text(t.announcementTargetAll)),
                          DropdownMenuItem(value: 'department', child: Text(t.announcementTargetDepartment)),
                        ],
                        onChanged: (v) => setState(() => _target = v ?? 'all'),
                      ),
                      if (_target == 'department') ...[
                        const SizedBox(height: 16),
                        departmentsAsync.when(
                          loading: () => const Center(child: CircularProgressIndicator()),
                          error: (e, _) => Text(translateError(context, e)),
                          data: (departments) => DropdownButtonFormField<int?>(
                            initialValue: _departmentId,
                            decoration: InputDecoration(labelText: t.announcementDepartmentLabel),
                            items: departments
                                .map((d) => DropdownMenuItem(
                                      value: d['id'] as int,
                                      child: Text(d['name']?.toString() ?? '-'),
                                    ))
                                .toList(),
                            onChanged: (v) => setState(() => _departmentId = v),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _isSaving ? null : _submit,
                child: _isSaving
                    ? const SizedBox(
                        height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : Text(t.submitButton),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
