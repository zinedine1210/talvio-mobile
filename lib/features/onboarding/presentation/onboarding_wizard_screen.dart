import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart' as ll;

import '../../../core/error_translator.dart';
import '../../../l10n/app_localizations.dart';
import '../providers/onboarding_providers.dart';
import 'office_location_picker.dart';

class OnboardingWizardScreen extends ConsumerStatefulWidget {
  const OnboardingWizardScreen({super.key});

  @override
  ConsumerState<OnboardingWizardScreen> createState() => _OnboardingWizardScreenState();
}

class _OnboardingWizardScreenState extends ConsumerState<OnboardingWizardScreen> {
  int _currentStep = 0;
  bool _isSubmitting = false;

  final _addressController = TextEditingController(text: 'Jl. Sudirman No. 1, Jakarta');
  final _radiusController = TextEditingController(text: '100');
  ll.LatLng? _officePoint;

  TimeOfDay _workStart = const TimeOfDay(hour: 8, minute: 0);
  TimeOfDay _workEnd = const TimeOfDay(hour: 17, minute: 0);
  final _lateToleranceController = TextEditingController(text: '15');
  // ISO weekday: 1=Senin ... 7=Minggu. Default Senin-Jumat, cocok konvensi
  // kerja kantoran umum; HR bisa ubah sebelum lanjut.
  final Set<int> _workDays = {1, 2, 3, 4, 5};

  final _leaveQuotaController = TextEditingController(text: '12');
  final _sickLeaveQuotaController = TextEditingController(text: '12');
  final _overtimeRateController = TextEditingController(text: '1.5');

  final _cutoffDayController = TextEditingController(text: '25');
  final _payDayController = TextEditingController(text: '1');

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

  Future<void> _pickOnMap() async {
    final result = await Navigator.of(context).push<ll.LatLng>(
      MaterialPageRoute(builder: (_) => OfficeLocationPicker(initial: _officePoint)),
    );
    if (result != null) setState(() => _officePoint = result);
  }

  bool get _locationValid =>
      _addressController.text.trim().isNotEmpty &&
      _officePoint != null &&
      int.tryParse(_radiusController.text) != null;

  Future<void> _submit() async {
    setState(() => _isSubmitting = true);
    final payload = {
      'locations': [
        {
          'name': _addressController.text.trim(),
          'latitude': _officePoint!.latitude,
          'longitude': _officePoint!.longitude,
          'radius_meters': int.parse(_radiusController.text),
        }
      ],
      'work_start_time': _formatTime(_workStart),
      'work_end_time': _formatTime(_workEnd),
      'late_tolerance_minutes': int.parse(_lateToleranceController.text),
      'work_days': (_workDays.toList()..sort()),
      'default_leave_quota': int.parse(_leaveQuotaController.text),
      'default_sick_leave_quota': int.parse(_sickLeaveQuotaController.text),
      'overtime_rate_multiplier': double.parse(_overtimeRateController.text),
      'payroll_cutoff_day': int.parse(_cutoffDayController.text),
      'payroll_pay_day': int.parse(_payDayController.text),
    };
    try {
      await ref.read(onboardingApiProvider).submit(payload);
      if (!mounted) return;
      context.go('/home');
    } on DioException catch (e) {
      if (!mounted) return;
      final message = translateError(context, e);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    const dayLabels = ['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min'];

    final steps = [
      (
        title: t.officeLocationStep,
        subtitle: t.officeLocationSubtitle,
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _MapCard(onTap: _pickOnMap),
            const SizedBox(height: 16),
            TextField(
              controller: _addressController,
              decoration: InputDecoration(
                labelText: t.officeAddressLabel,
                prefixIcon: const Icon(Icons.location_on_outlined),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _radiusController,
              decoration: InputDecoration(labelText: t.radiusLabel),
              keyboardType: TextInputType.number,
              onChanged: (_) => setState(() {}),
            ),
          ],
        ),
      ),
      (
        title: t.workHoursStep,
        subtitle: t.workHoursSubtitle,
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: _TimeField(
                    label: t.clockInTimeLabel,
                    value: _formatTime(_workStart),
                    onTap: () => _pickTime(true),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _TimeField(
                    label: t.clockOutTimeLabel,
                    value: _formatTime(_workEnd),
                    onTap: () => _pickTime(false),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _lateToleranceController,
              decoration: InputDecoration(labelText: t.lateToleranceLabel),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 12),
            Text(t.workDaysLabel, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                for (var i = 0; i < 7; i++)
                  _DayCircle(
                    label: dayLabels[i][0],
                    selected: _workDays.contains(i + 1),
                    onTap: () => setState(() {
                      if (_workDays.contains(i + 1)) {
                        _workDays.remove(i + 1);
                      } else {
                        _workDays.add(i + 1);
                      }
                    }),
                  ),
              ],
            ),
          ],
        ),
      ),
      (
        title: t.leaveOvertimePolicyStep,
        subtitle: t.leaveOvertimePolicySubtitle,
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _leaveQuotaController,
              decoration: InputDecoration(labelText: t.defaultLeaveQuotaLabel),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _sickLeaveQuotaController,
              decoration: InputDecoration(labelText: t.sickLeaveQuotaLabel),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),
            _InfoCard(text: t.leaveQuotaInfoCard),
          ],
        ),
      ),
      (
        title: t.payrollStep,
        subtitle: t.payrollStepSubtitle,
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _cutoffDayController,
              decoration: InputDecoration(
                labelText: t.payrollCutoffLabel,
                prefixIcon: const Icon(Icons.event_outlined),
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 12),
            // Pilihan jalur approval cuma tampilan dulu — belum ada field
            // approval-route di payload onboarding backend.
            InputDecorator(
              decoration: InputDecoration(labelText: t.approvalDefaultLabel),
              child: Row(
                children: [
                  Expanded(child: Text(t.approvalDefaultValue)),
                  const Icon(Icons.keyboard_arrow_down, size: 20),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _SummaryCard(text: t.workspaceReadySummary),
          ],
        ),
      ),
    ];

    void onContinue() {
      if (_currentStep == 0 && !_locationValid) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(t.completeLocationDataWarning)));
        return;
      }
      if (_currentStep < steps.length - 1) {
        setState(() => _currentStep += 1);
      } else if (!_isSubmitting) {
        _submit();
      }
    }

    // Hand-rolled step navigation instead of Stepper — Stepper + Material 3
    // crashes ("RenderBox was not laid out") on this Flutter version, a
    // known upstream framework issue, not something fixable from app code.
    return Scaffold(
      appBar: AppBar(
        title: Text(t.companySetupTitle),
        actions: [
          TextButton(
            // Admin bisa lengkapi setup ini belakangan lewat Pengaturan
            // Perusahaan — skip tidak mengirim apa pun ke backend.
            onPressed: () => context.go('/home'),
            child: Text(t.skipLabel),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Row(
              children: [
                for (var i = 0; i < steps.length; i++) ...[
                  if (i > 0) const SizedBox(width: 8),
                  Expanded(
                    child: Container(
                      height: 6,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(3),
                        color: i <= _currentStep
                            ? const Color(0xFF0D9488)
                            : const Color(0xFF99F6E4),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(steps[_currentStep].title,
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge
                          ?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text(
                    steps[_currentStep].subtitle,
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 16),
                  steps[_currentStep].content,
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Row(
              children: [
                if (_currentStep > 0) ...[
                  // OutlinedButtonTheme sets minimumSize width: infinity too
                  // — same bounded-width requirement as the FilledButton
                  // below, so this also needs an Expanded ancestor.
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => setState(() => _currentStep -= 1),
                      child: Text(t.backButton),
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
                // FilledButton's theme sets minimumSize width: infinity, so
                // it needs a bounded-width ancestor here (Row alone won't
                // give it one) — same crash class as the Stepper this
                // replaced if left unwrapped.
                Expanded(
                  child: FilledButton(
                    onPressed: _isSubmitting ? null : onContinue,
                    child: _isSubmitting
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(_currentStep == steps.length - 1 ? t.finishButton : t.continueButton),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MapCard extends StatelessWidget {
  const _MapCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        child: Container(
          height: 180,
          color: const Color(0xFFE2E8F0),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                child: const Icon(Icons.location_on, color: Color(0xFFEA580C), size: 28),
              ),
              Positioned(
                right: 16,
                bottom: 16,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          AppLocalizations.of(context)!.pickOnMapButton,
                          style: const TextStyle(
                            color: Color(0xFF0D9488),
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.chevron_right, size: 16, color: Color(0xFF0D9488)),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TimeField extends StatelessWidget {
  const _TimeField({required this.label, required this.value, required this.onTap});

  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: const Icon(Icons.access_time),
        ),
        child: Text(value),
      ),
    );
  }
}

class _DayCircle extends StatelessWidget {
  const _DayCircle({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: Container(
        width: 36,
        height: 36,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: selected ? const Color(0xFF0D9488) : Colors.white,
          border: selected ? null : Border.all(color: const Color(0xFF99F6E4)),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : const Color(0xFF475569),
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFCCFBF1),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.info_outline, color: Color(0xFF0D9488), size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Text(text, style: const TextStyle(color: Color(0xFF134E4A), fontSize: 13)),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFCCFBF1),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: const BoxDecoration(color: Color(0xFF0D9488), shape: BoxShape.circle),
              child: const Icon(Icons.check, color: Colors.white, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                text,
                style: const TextStyle(color: Color(0xFF134E4A), fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
