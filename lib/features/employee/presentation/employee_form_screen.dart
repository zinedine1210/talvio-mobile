import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
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
      text: (widget.employee?['base_salary'] ?? '').toString());

  late String _role = widget.employee?['role']?.toString() ?? 'employee';
  late int? _departmentId = widget.employee?['department_id'] as int?;
  late int? _supervisorId = widget.employee?['supervisor_id'] as int?;
  late DateTime? _joinDate = widget.employee?['join_date'] != null
      ? DateTime.tryParse(widget.employee!['join_date'].toString())
      : null;
  bool _isSaving = false;

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
      'base_salary': double.tryParse(_salaryController.text) ?? 0,
      if (_joinDate != null) 'join_date': _joinDate!.toUtc().toIso8601String(),
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
      final message = e.response?.data is Map
          ? (e.response?.data['error'] ?? 'Gagal menyimpan data karyawan')
          : 'Gagal menyimpan data karyawan, cek koneksi ke server';
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message.toString())));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _deactivate() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Nonaktifkan Karyawan'),
        content: Text('Yakin ingin menonaktifkan ${widget.employee!['name']}?'),
        actions: [
          TextButton(onPressed: () => context.pop(false), child: const Text('Batal')),
          FilledButton(onPressed: () => context.pop(true), child: const Text('Nonaktifkan')),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref.read(employeeApiProvider).deactivateEmployee(widget.employee!['id'] as int);
      if (!mounted) return;
      context.pop();
    } on DioException {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Gagal menonaktifkan karyawan')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final departmentsAsync = ref.watch(departmentListProvider);
    final employeesAsync = ref.watch(employeeListProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Karyawan' : 'Tambah Karyawan'),
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
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Nama'),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Wajib diisi' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _emailController,
                enabled: !_isEditing,
                decoration: const InputDecoration(labelText: 'Email'),
                keyboardType: TextInputType.emailAddress,
                validator: _isEditing
                    ? null
                    : (v) {
                        if (v == null || v.trim().isEmpty) return 'Wajib diisi';
                        if (!_emailRegex.hasMatch(v.trim())) return 'Email tidak valid';
                        return null;
                      },
              ),
              if (!_isEditing) ...[
                const SizedBox(height: 12),
                TextFormField(
                  controller: _passwordController,
                  decoration: const InputDecoration(labelText: 'Password Awal'),
                  obscureText: true,
                  validator: (v) => (v == null || v.length < 6) ? 'Minimal 6 karakter' : null,
                ),
              ],
              const SizedBox(height: 12),
              TextFormField(
                controller: _phoneController,
                decoration: const InputDecoration(labelText: 'Telepon'),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _positionController,
                decoration: const InputDecoration(labelText: 'Jabatan'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _salaryController,
                decoration: const InputDecoration(labelText: 'Gaji Pokok'),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _role,
                decoration: const InputDecoration(labelText: 'Role'),
                items: const [
                  DropdownMenuItem(value: 'employee', child: Text('Karyawan')),
                  DropdownMenuItem(value: 'hr_admin', child: Text('HR Admin')),
                ],
                onChanged: (v) => setState(() => _role = v ?? 'employee'),
              ),
              const SizedBox(height: 12),
              departmentsAsync.when(
                loading: () => const LinearProgressIndicator(),
                error: (e, _) => Text('Gagal memuat departemen: $e'),
                data: (departments) => DropdownButtonFormField<int?>(
                  initialValue: _departmentId,
                  decoration: const InputDecoration(labelText: 'Departemen'),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('- Tidak ada -')),
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
                error: (e, _) => Text('Gagal memuat daftar atasan: $e'),
                data: (employees) => DropdownButtonFormField<int?>(
                  initialValue: _supervisorId,
                  decoration: const InputDecoration(labelText: 'Atasan'),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('- Tidak ada -')),
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
                title: const Text('Tanggal Bergabung'),
                trailing: Text(_joinDate == null
                    ? 'Pilih tanggal'
                    : '${_joinDate!.year}-${_joinDate!.month.toString().padLeft(2, '0')}-${_joinDate!.day.toString().padLeft(2, '0')}'),
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
                    : const Text('Simpan'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
