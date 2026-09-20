import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/error_translator.dart';
import '../../../core/formatters.dart';
import '../../../l10n/app_localizations.dart';
import '../providers/employee_providers.dart';

final _emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

class EmployeeFormScreen extends ConsumerStatefulWidget {
  const EmployeeFormScreen({super.key, this.employee});

  /// Non-null when editing an existing employee (passed via route `extra`
  /// from the list screen — avoids an extra GET /employees/:id round trip).
  final Map<String, dynamic>? employee;

  @override
  ConsumerState<EmployeeFormScreen> createState() => _EmployeeFormScreenState();
}

class _EmployeeFormScreenState extends ConsumerState<EmployeeFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final _nameController =
      TextEditingController(text: widget.employee?['name']?.toString() ?? '');
  late final _emailController =
      TextEditingController(text: widget.employee?['email']?.toString() ?? '');
  final _passwordController = TextEditingController();
  late final _phoneController =
      TextEditingController(text: widget.employee?['phone']?.toString() ?? '');
  late final _positionController =
      TextEditingController(text: widget.employee?['position']?.toString() ?? '');
  late final _salaryController = TextEditingController(
      text: widget.employee?['base_salary'] != null
          ? formatRupiah((widget.employee!['base_salary'] as num).toInt())
          : '');

  late String _role = widget.employee?['role']?.toString() ?? 'employee';
  late int? _departmentId = widget.employee?['department_id'] as int?;
  late int? _supervisorId = widget.employee?['supervisor_id'] as int?;
  late DateTime? _joinDate = widget.employee?['join_date'] != null
      ? DateTime.tryParse(widget.employee!['join_date'].toString())
      : null;
  late String? _photoUrl = widget.employee?['photo_url']?.toString();
  bool _isSaving = false;
  bool _isUploadingPhoto = false;

  bool get _isEditing => widget.employee != null;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _phoneController.dispose();
    _positionController.dispose();
    _salaryController.dispose();
    super.dispose();
  }

  Future<void> _pickAndUploadPhoto() async {
    final t = AppLocalizations.of(context)!;
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera),
              title: Text(t.takePhotoOption),
              onTap: () => context.pop(ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: Text(t.choosePhotoOption),
              onTap: () => context.pop(ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;

    final picked = await ImagePicker()
        .pickImage(source: source, maxWidth: 1024, maxHeight: 1024, imageQuality: 85);
    if (picked == null) return;

    setState(() => _isUploadingPhoto = true);
    try {
      final bytes = await picked.readAsBytes();
      final result = await ref
          .read(employeeApiProvider)
          .uploadPhoto(widget.employee!['id'] as int, bytes, picked.name);
      if (!mounted) return;
      setState(() => _photoUrl = result['photo_url']?.toString());
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(t.photoUploadedMessage)));
    } on DioException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(translateError(context, e))));
    } finally {
      if (mounted) setState(() => _isUploadingPhoto = false);
    }
  }

  Future<void> _pickJoinDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _joinDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _joinDate = picked);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    final payload = {
      'name': _nameController.text.trim(),
      'phone': _phoneController.text.trim(),
      'role': _role,
      'department_id': _departmentId,
      'supervisor_id': _supervisorId,
      'position': _positionController.text.trim(),
      'base_salary': parseRupiahInput(_salaryController.text),
      if (_joinDate != null)
        'join_date':
            '${_joinDate!.year.toString().padLeft(4, '0')}-${_joinDate!.month.toString().padLeft(2, '0')}-${_joinDate!.day.toString().padLeft(2, '0')}',
      if (!_isEditing) 'email': _emailController.text.trim(),
      if (!_isEditing) 'password': _passwordController.text,
    };
    try {
      final api = ref.read(employeeApiProvider);
      if (_isEditing) {
        await api.updateEmployee(widget.employee!['id'] as int, payload);
      } else {
        await api.createEmployee(payload);
      }
      if (!mounted) return;
      context.pop();
    } on DioException catch (e) {
      if (!mounted) return;
      final message = translateError(context, e);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _deactivate() async {
    final t = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(t.deactivateEmployeeTitle),
        content: Text(t.confirmDeactivateEmployee(widget.employee!['name']?.toString() ?? '')),
        actions: [
          TextButton(onPressed: () => context.pop(false), child: Text(t.cancelButton)),
          FilledButton(onPressed: () => context.pop(true), child: Text(t.deactivateButton)),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref.read(employeeApiProvider).deactivateEmployee(widget.employee!['id'] as int);
      if (!mounted) return;
      context.pop();
    } on DioException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(translateError(context, e))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final departmentsAsync = ref.watch(departmentListProvider);
    final employeesAsync = ref.watch(employeeListProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? t.editEmployeeTitle : t.addEmployeeTitle),
        actions: [
          if (_isEditing)
            IconButton(icon: const Icon(Icons.person_off), onPressed: _deactivate),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              if (_isEditing) ...[
                Center(
                  child: GestureDetector(
                    onTap: _isUploadingPhoto ? null : _pickAndUploadPhoto,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        CircleAvatar(
                          radius: 48,
                          backgroundImage:
                              _photoUrl != null && _photoUrl!.isNotEmpty
                                  ? NetworkImage(_photoUrl!)
                                  : null,
                          child: _photoUrl == null || _photoUrl!.isEmpty
                              ? const Icon(Icons.person, size: 48)
                              : null,
                        ),
                        if (_isUploadingPhoto) const CircularProgressIndicator(),
                      ],
                    ),
                  ),
                ),
                Center(
                  child: TextButton(
                    onPressed: _isUploadingPhoto ? null : _pickAndUploadPhoto,
                    child: Text(t.profilePhotoLabel),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(labelText: t.nameLabel),
                validator: (v) => (v == null || v.trim().isEmpty) ? t.requiredField : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _emailController,
                enabled: !_isEditing,
                decoration: InputDecoration(labelText: t.emailLabel),
                keyboardType: TextInputType.emailAddress,
                validator: _isEditing
                    ? null
                    : (v) {
                        if (v == null || v.trim().isEmpty) return t.requiredField;
                        if (!_emailRegex.hasMatch(v.trim())) return t.invalidEmail;
                        return null;
                      },
              ),
              if (!_isEditing) ...[
                const SizedBox(height: 12),
                TextFormField(
                  controller: _passwordController,
                  decoration: InputDecoration(labelText: t.initialPasswordLabel),
                  obscureText: true,
                  validator: (v) => (v == null || v.length < 6) ? t.minLength6 : null,
                ),
              ],
              const SizedBox(height: 12),
              TextFormField(
                controller: _phoneController,
                decoration: InputDecoration(labelText: t.phoneLabel),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _positionController,
                decoration: InputDecoration(labelText: t.positionLabel),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _salaryController,
                decoration: InputDecoration(labelText: t.baseSalaryLabel),
                keyboardType: TextInputType.number,
                inputFormatters: [RupiahInputFormatter()],
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _role,
                decoration: InputDecoration(labelText: t.roleLabel),
                items: [
                  DropdownMenuItem(value: 'employee', child: Text(t.employeeRoleOption)),
                  DropdownMenuItem(value: 'hr_admin', child: Text(t.hrAdminRoleOption)),
                ],
                onChanged: (v) => setState(() => _role = v ?? 'employee'),
              ),
              const SizedBox(height: 12),
              departmentsAsync.when(
                loading: () => const LinearProgressIndicator(),
                error: (e, _) => Text(translateError(context, e)),
                data: (departments) => DropdownButtonFormField<int?>(
                  initialValue: _departmentId,
                  decoration: InputDecoration(labelText: t.departmentLabel),
                  items: [
                    DropdownMenuItem(value: null, child: Text(t.noneOption)),
                    ...departments.map((d) => DropdownMenuItem(
                          value: d['id'] as int,
                          child: Text(d['name']?.toString() ?? '-'),
                        )),
                  ],
                  onChanged: (v) => setState(() => _departmentId = v),
                ),
              ),
              const SizedBox(height: 12),
              employeesAsync.when(
                loading: () => const LinearProgressIndicator(),
                error: (e, _) => Text(translateError(context, e)),
                data: (employees) => DropdownButtonFormField<int?>(
                  initialValue: _supervisorId,
                  decoration: InputDecoration(labelText: t.supervisorLabel),
                  items: [
                    DropdownMenuItem(value: null, child: Text(t.noneOption)),
                    ...employees
                        .where((e) => e['id'] != widget.employee?['id'])
                        .map((e) => DropdownMenuItem(
                              value: e['id'] as int,
                              child: Text(e['name']?.toString() ?? '-'),
                            )),
                  ],
                  onChanged: (v) => setState(() => _supervisorId = v),
                ),
              ),
              const SizedBox(height: 12),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(t.joinDateLabel),
                trailing: Text(_joinDate == null ? t.pickDateHint : formatDateLong(_joinDate!)),
                onTap: _pickJoinDate,
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _isSaving ? null : _submit,
                child: _isSaving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(t.saveButton),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
