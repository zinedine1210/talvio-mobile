import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart' as ll;

import '../../../core/error_translator.dart';
import '../../../l10n/app_localizations.dart';
import '../../employee/providers/employee_providers.dart';
import '../../onboarding/presentation/office_location_picker.dart';
import '../providers/company_providers.dart';

/// HR-only: re-edit the same data the onboarding wizard collected once at
/// company creation (name, address, work hours, leave/overtime policy,
/// payroll cutoff, office locations) — this screen edits it in place via
/// PUT /company/settings and /company/locations/:id, never re-runs
/// POST /company/onboarding (that endpoint always CREATES new locations,
/// so calling it again here would duplicate the list instead of editing it).
class CompanySettingsScreen extends ConsumerStatefulWidget {
  const CompanySettingsScreen({super.key});

  @override
  ConsumerState<CompanySettingsScreen> createState() => _CompanySettingsScreenState();
}

class _CompanySettingsScreenState extends ConsumerState<CompanySettingsScreen> {
  final _nameController = TextEditingController();
  final _addressController = TextEditingController();
  final _lateToleranceController = TextEditingController();
  final _leaveQuotaController = TextEditingController();
  final _overtimeRateController = TextEditingController();
  final _cutoffDayController = TextEditingController();
  final _payDayController = TextEditingController();
  TimeOfDay _workStart = const TimeOfDay(hour: 7, minute: 0);
  TimeOfDay _workEnd = const TimeOfDay(hour: 16, minute: 0);
  bool _initialized = false;
  bool _isSaving = false;

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _lateToleranceController.dispose();
    _leaveQuotaController.dispose();
    _overtimeRateController.dispose();
    _cutoffDayController.dispose();
    _payDayController.dispose();
    super.dispose();
  }

  TimeOfDay? _parseTime(String? hhmm) {
    if (hhmm == null || !hhmm.contains(':')) return null;
    final parts = hhmm.split(':');
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h == null || m == null) return null;
    return TimeOfDay(hour: h, minute: m);
  }

  String _formatTime(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  void _fillFrom(Map<String, dynamic> company) {
    if (_initialized) return;
    _initialized = true;
    _nameController.text = company['name']?.toString() ?? '';
    _addressController.text = company['address']?.toString() ?? '';
    _lateToleranceController.text = '${company['late_tolerance_minutes'] ?? 15}';
    _leaveQuotaController.text = '${company['default_leave_quota'] ?? 12}';
    _overtimeRateController.text = '${company['overtime_rate_multiplier'] ?? 1.5}';
    _cutoffDayController.text = '${company['payroll_cutoff_day'] ?? 20}';
    _payDayController.text = '${company['payroll_pay_day'] ?? 25}';
    _workStart = _parseTime(company['work_start_time']?.toString()) ?? _workStart;
    _workEnd = _parseTime(company['work_end_time']?.toString()) ?? _workEnd;
  }

  Future<void> _pickTime(bool isStart) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: isStart ? _workStart : _workEnd,
    );
    if (picked == null) return;
    setState(() => isStart ? _workStart = picked : _workEnd = picked);
  }

  Future<void> _save() async {
    final t = AppLocalizations.of(context)!;
    setState(() => _isSaving = true);
    try {
      await ref.read(companyApiProvider).updateSettings({
        'name': _nameController.text.trim(),
        'address': _addressController.text.trim(),
        'work_start_time': _formatTime(_workStart),
        'work_end_time': _formatTime(_workEnd),
        'late_tolerance_minutes': int.tryParse(_lateToleranceController.text) ?? 0,
        'default_leave_quota': int.tryParse(_leaveQuotaController.text) ?? 0,
        'overtime_rate_multiplier': double.tryParse(_overtimeRateController.text) ?? 1.0,
        'payroll_cutoff_day': int.tryParse(_cutoffDayController.text) ?? 1,
        'payroll_pay_day': int.tryParse(_payDayController.text) ?? 1,
      });
      ref.invalidate(companyMeProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t.settingsSavedMessage)));
    } on DioException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(translateError(context, e))));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _addLocation() async {
    await _locationDialog(title: AppLocalizations.of(context)!.addLocationTitle);
  }

  Future<void> _editLocation(Map<String, dynamic> location) async {
    await _locationDialog(
      title: AppLocalizations.of(context)!.editLocationTitle,
      location: location,
    );
  }

  Future<void> _locationDialog({required String title, Map<String, dynamic>? location}) async {
    final t = AppLocalizations.of(context)!;
    final nameController = TextEditingController(text: location?['name']?.toString() ?? '');
    final radiusController =
        TextEditingController(text: location?['radius_meters']?.toString() ?? '100');
    ll.LatLng? point;
    final existingLat = location?['latitude'] as num?;
    final existingLng = location?['longitude'] as num?;
    if (existingLat != null && existingLng != null) {
      point = ll.LatLng(existingLat.toDouble(), existingLng.toDouble());
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(title),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: nameController,
                  decoration: InputDecoration(labelText: t.locationNameHint),
                  autofocus: true,
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () async {
                    final picked = await Navigator.of(context).push<ll.LatLng>(
                      MaterialPageRoute(builder: (_) => OfficeLocationPicker(initial: point)),
                    );
                    if (picked != null) setDialogState(() => point = picked);
                  },
                  icon: const Icon(Icons.map_outlined),
                  label: Text(t.pickOnMapButton),
                ),
                const SizedBox(height: 8),
                Text(
                  point == null
                      ? t.noLocationPickedHint
                      : '${point!.latitude.toStringAsFixed(6)}, ${point!.longitude.toStringAsFixed(6)}',
                  style: TextStyle(
                      color: point == null ? Colors.red : Theme.of(context).colorScheme.onSurfaceVariant,
                      fontSize: 12),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: radiusController,
                  decoration: InputDecoration(labelText: t.radiusLabel),
                  keyboardType: TextInputType.number,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(false), child: Text(t.cancelButton)),
            FilledButton(onPressed: () => Navigator.of(context).pop(true), child: Text(t.saveButton)),
          ],
        ),
      ),
    );
    if (confirmed != true) return;
    final radius = int.tryParse(radiusController.text);
    if (nameController.text.trim().isEmpty || point == null || radius == null) return;

    final payload = {
      'name': nameController.text.trim(),
      'latitude': point!.latitude,
      'longitude': point!.longitude,
      'radius_meters': radius,
    };
    try {
      if (location == null) {
        await ref.read(companyApiProvider).createLocation(payload);
      } else {
        await ref.read(companyApiProvider).updateLocation(location['id'] as int, payload);
      }
      ref.invalidate(locationListProvider);
    } on DioException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(translateError(context, e))));
    }
  }

  Future<void> _deactivateLocation(Map<String, dynamic> location) async {
    final t = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(t.deactivateLocationTitle),
        content: Text(t.confirmDeactivateLocation(location['name']?.toString() ?? '')),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: Text(t.cancelButton)),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(t.deactivateButton),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref.read(companyApiProvider).deactivateLocation(location['id'] as int);
      ref.invalidate(locationListProvider);
    } on DioException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(translateError(context, e))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final companyAsync = ref.watch(companyMeProvider);
    final locationsAsync = ref.watch(locationListProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: Text(t.companySettingsTitle)),
      floatingActionButton: FloatingActionButton(
        onPressed: _addLocation,
        child: const Icon(Icons.add_location_alt_outlined),
      ),
      body: companyAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(translateError(context, e))),
        data: (company) {
          _fillFrom(company);
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
            children: [
              TextField(
                controller: _nameController,
                decoration: InputDecoration(labelText: t.companyNameLabel),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _addressController,
                decoration: InputDecoration(labelText: t.addressLabel),
              ),
              const SizedBox(height: 12),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(t.clockInTimeLabel),
                trailing: Text(_formatTime(_workStart)),
                onTap: () => _pickTime(true),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(t.clockOutTimeLabel),
                trailing: Text(_formatTime(_workEnd)),
                onTap: () => _pickTime(false),
              ),
              TextField(
                controller: _lateToleranceController,
                decoration: InputDecoration(labelText: t.lateToleranceLabel),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _leaveQuotaController,
                decoration: InputDecoration(labelText: t.defaultLeaveQuotaLabel),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _overtimeRateController,
                decoration: InputDecoration(labelText: t.overtimeRateLabel),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _cutoffDayController,
                decoration: InputDecoration(labelText: t.payrollCutoffLabel),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _payDayController,
                decoration: InputDecoration(labelText: t.payrollPayDayLabel),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _isSaving ? null : _save,
                child: _isSaving
                    ? const SizedBox(
                        height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : Text(t.saveButton),
              ),
              const SizedBox(height: 28),
              Text(t.locationsSectionTitle,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              locationsAsync.when(
                loading: () => const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (e, _) => Text(translateError(context, e)),
                data: (locations) => Column(
                  children: [
                    for (final loc in locations)
                      Card(
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: colorScheme.primaryContainer,
                            child: Icon(Icons.location_on_outlined, color: colorScheme.onPrimaryContainer),
                          ),
                          title: Text(loc['name']?.toString() ?? '-',
                              style: const TextStyle(fontWeight: FontWeight.w600)),
                          subtitle: Text(
                              '${loc['latitude']}, ${loc['longitude']} — ${loc['radius_meters']}m'),
                          trailing: Wrap(
                            spacing: 4,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Chip(
                                label: Text(loc['status'] == 'active' ? t.activeStatus : t.inactiveStatus),
                                backgroundColor: loc['status'] == 'active'
                                    ? colorScheme.tertiaryContainer
                                    : colorScheme.surfaceContainerHighest,
                              ),
                              if (loc['status'] == 'active')
                                IconButton(
                                  icon: const Icon(Icons.delete_outline),
                                  onPressed: () => _deactivateLocation(loc),
                                ),
                            ],
                          ),
                          onTap: () => _editLocation(loc),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
