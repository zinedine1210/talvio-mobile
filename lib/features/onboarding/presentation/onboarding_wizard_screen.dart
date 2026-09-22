import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/error_translator.dart';
import '../../../l10n/app_localizations.dart';
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
    final steps = [
      (
        title: t.officeLocationStep,
        content: Column(
          children: [
            for (var i = 0; i < _locations.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.location_on_outlined,
                                size: 20, color: Theme.of(context).colorScheme.primary),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(t.locationLabel(i + 1),
                                  style: const TextStyle(fontWeight: FontWeight.w700)),
                            ),
                            if (_locations.length > 1)
                              IconButton(
                                icon: const Icon(Icons.delete_outline),
                                onPressed: () => setState(() => _locations.removeAt(i)),
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _locations[i].nameController,
                          decoration: InputDecoration(labelText: t.locationNameHint),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _locations[i].latController,
                          decoration: InputDecoration(labelText: t.latitudeLabel),
                          keyboardType:
                              const TextInputType.numberWithOptions(decimal: true, signed: true),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _locations[i].lngController,
                          decoration: InputDecoration(labelText: t.longitudeLabel),
                          keyboardType:
                              const TextInputType.numberWithOptions(decimal: true, signed: true),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _locations[i].radiusController,
                          decoration: InputDecoration(labelText: t.radiusLabel),
                          keyboardType: TextInputType.number,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            TextButton.icon(
              onPressed: () => setState(() => _locations.add(_LocationEntry())),
              icon: const Icon(Icons.add),
              label: Text(t.addLocationButton),
            ),
          ],
        ),
      ),
      (
        title: t.workHoursStep,
        content: Column(
          children: [
            ListTile(
              title: Text(t.clockInTimeLabel),
              trailing: Text(_formatTime(_workStart)),
              onTap: () => _pickTime(true),
            ),
            ListTile(
              title: Text(t.clockOutTimeLabel),
              trailing: Text(_formatTime(_workEnd)),
              onTap: () => _pickTime(false),
            ),
            TextField(
              controller: _lateToleranceController,
              decoration: InputDecoration(labelText: t.lateToleranceLabel),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
      ),
      (
        title: t.leaveOvertimePolicyStep,
        content: Column(
          children: [
            TextField(
              controller: _leaveQuotaController,
              decoration: InputDecoration(labelText: t.defaultLeaveQuotaLabel),
              keyboardType: TextInputType.number,
            ),
            TextField(
              controller: _overtimeRateController,
              decoration: InputDecoration(labelText: t.overtimeRateLabel),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
            ),
          ],
        ),
      ),
      (
        title: t.payrollStep,
        content: Column(
          children: [
            TextField(
              controller: _cutoffDayController,
              decoration: InputDecoration(labelText: t.payrollCutoffLabel),
              keyboardType: TextInputType.number,
            ),
            TextField(
              controller: _payDayController,
              decoration: InputDecoration(labelText: t.payrollPayDayLabel),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
      ),
    ];

    void onContinue() {
      if (_currentStep == 0 && !_locationsValid) {
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
      appBar: AppBar(title: Text(t.companySetupTitle)),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: LinearProgressIndicator(value: (_currentStep + 1) / steps.length),
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
                  TextButton(
                    onPressed: () => setState(() => _currentStep -= 1),
                    child: Text(t.backButton),
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
