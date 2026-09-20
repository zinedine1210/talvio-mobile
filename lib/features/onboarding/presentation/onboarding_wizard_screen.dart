import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/onboarding_providers.dart';

class _LocationEntry {
  final nameController = TextEditingController();
  final latController = TextEditingController();
  final lngController = TextEditingController();
  final radiusController = TextEditingController(text: '100');
}

class OnboardingWizardScreen extends ConsumerStatefulWidget {
  const OnboardingWizardScreen({super.key});

  @override
  ConsumerState<OnboardingWizardScreen> createState() => _OnboardingWizardScreenState();
}

class _OnboardingWizardScreenState extends ConsumerState<OnboardingWizardScreen> {
  int _currentStep = 0;
  bool _isSubmitting = false;

  final List<_LocationEntry> _locations = [_LocationEntry()];

  TimeOfDay _workStart = const TimeOfDay(hour: 7, minute: 0);
  TimeOfDay _workEnd = const TimeOfDay(hour: 16, minute: 0);
  final _lateToleranceController = TextEditingController(text: '15');
  final _leaveQuotaController = TextEditingController(text: '12');
  final _overtimeRateController = TextEditingController(text: '1.5');
  final _cutoffDayController = TextEditingController(text: '20');
  final _payDayController = TextEditingController(text: '25');

  String _formatTime(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  Future<void> _pickTime(bool isStart) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: isStart ? _workStart : _workEnd,
    );
    if (picked == null) return;
    setState(() => isStart ? _workStart = picked : _workEnd = picked);
  }

  bool get _locationsValid => _locations.every((l) =>
      l.nameController.text.trim().isNotEmpty &&
      double.tryParse(l.latController.text) != null &&
      double.tryParse(l.lngController.text) != null &&
      int.tryParse(l.radiusController.text) != null);

  Future<void> _submit() async {
    setState(() => _isSubmitting = true);
    final payload = {
      'locations': _locations
          .map((l) => {
                'name': l.nameController.text.trim(),
                'latitude': double.parse(l.latController.text),
                'longitude': double.parse(l.lngController.text),
                'radius_meters': int.parse(l.radiusController.text),
              })
          .toList(),
      'work_start_time': _formatTime(_workStart),
      'work_end_time': _formatTime(_workEnd),
      'late_tolerance_minutes': int.parse(_lateToleranceController.text),
      'default_leave_quota': int.parse(_leaveQuotaController.text),
      'overtime_rate_multiplier': double.parse(_overtimeRateController.text),
      'payroll_cutoff_day': int.parse(_cutoffDayController.text),
      'payroll_pay_day': int.parse(_payDayController.text),
    };
    try {
      await ref.read(onboardingApiProvider).submit(payload);
      if (!mounted) return;
      context.go('/home');
    } on DioException catch (e) {
      final message = e.response?.data is Map
          ? (e.response?.data['message'] ?? 'Gagal menyimpan onboarding')
          : 'Gagal menyimpan onboarding, cek koneksi ke server';
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message.toString())));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final steps = [
      Step(
        title: const Text('Lokasi Kantor'),
        isActive: _currentStep >= 0,
        content: Column(
          children: [
            for (var i = 0; i < _locations.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(child: Text('Lokasi ${i + 1}', style: const TextStyle(fontWeight: FontWeight.bold))),
                        if (_locations.length > 1)
                          IconButton(
                            icon: const Icon(Icons.delete_outline),
                            onPressed: () => setState(() => _locations.removeAt(i)),
                          ),
                      ],
                    ),
                    TextField(
                      controller: _locations[i].nameController,
                      decoration: const InputDecoration(labelText: 'Nama Lokasi (mis. Kantor Pusat)'),
                    ),
                    TextField(
                      controller: _locations[i].latController,
                      decoration: const InputDecoration(labelText: 'Latitude'),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                    ),
                    TextField(
                      controller: _locations[i].lngController,
                      decoration: const InputDecoration(labelText: 'Longitude'),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                    ),
                    TextField(
                      controller: _locations[i].radiusController,
                      decoration: const InputDecoration(labelText: 'Radius (meter)'),
                      keyboardType: TextInputType.number,
                    ),
                  ],
                ),
              ),
            TextButton.icon(
              onPressed: () => setState(() => _locations.add(_LocationEntry())),
              icon: const Icon(Icons.add),
              label: const Text('Tambah Lokasi'),
            ),
          ],
        ),
      ),
      Step(
        title: const Text('Jam Kerja'),
        isActive: _currentStep >= 1,
        content: Column(
          children: [
            ListTile(
              title: const Text('Jam Masuk'),
              trailing: Text(_formatTime(_workStart)),
              onTap: () => _pickTime(true),
            ),
            ListTile(
              title: const Text('Jam Pulang'),
              trailing: Text(_formatTime(_workEnd)),
              onTap: () => _pickTime(false),
            ),
            TextField(
              controller: _lateToleranceController,
              decoration: const InputDecoration(labelText: 'Toleransi Telat (menit)'),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
      ),
      Step(
        title: const Text('Kebijakan Cuti & Lembur'),
        isActive: _currentStep >= 2,
        content: Column(
          children: [
            TextField(
              controller: _leaveQuotaController,
              decoration: const InputDecoration(labelText: 'Kuota Cuti Default (hari/tahun)'),
              keyboardType: TextInputType.number,
            ),
            TextField(
              controller: _overtimeRateController,
              decoration: const InputDecoration(labelText: 'Rate Lembur (pengali gaji/jam)'),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
            ),
          ],
        ),
      ),
      Step(
        title: const Text('Payroll'),
        isActive: _currentStep >= 3,
        content: Column(
          children: [
            TextField(
              controller: _cutoffDayController,
              decoration: const InputDecoration(labelText: 'Tanggal Cutoff (1-28)'),
              keyboardType: TextInputType.number,
            ),
            TextField(
              controller: _payDayController,
              decoration: const InputDecoration(labelText: 'Tanggal Gajian (1-28)'),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
      ),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Setup Awal Perusahaan')),
      body: Stepper(
        currentStep: _currentStep,
        steps: steps,
        onStepContinue: () {
          if (_currentStep == 0 && !_locationsValid) {
            ScaffoldMessenger.of(context)
                .showSnackBar(const SnackBar(content: Text('Lengkapi data lokasi dengan benar')));
            return;
          }
          if (_currentStep < steps.length - 1) {
            setState(() => _currentStep += 1);
          } else if (!_isSubmitting) {
            _submit();
          }
        },
        onStepCancel: _currentStep == 0 ? null : () => setState(() => _currentStep -= 1),
        controlsBuilder: (context, details) => Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Row(
            children: [
              FilledButton(
                onPressed: _isSubmitting ? null : details.onStepContinue,
                child: _isSubmitting
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(_currentStep == steps.length - 1 ? 'Selesai' : 'Lanjut'),
              ),
              if (details.onStepCancel != null)
                TextButton(onPressed: details.onStepCancel, child: const Text('Kembali')),
            ],
          ),
        ),
      ),
    );
  }
}
