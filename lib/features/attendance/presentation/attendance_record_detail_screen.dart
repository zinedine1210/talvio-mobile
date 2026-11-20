import 'package:flutter/material.dart';

import '../../../core/formatters.dart';
import '../../../l10n/app_localizations.dart';

/// Full detail of one attendance record — reached from the personal
/// attendance report (tap a day-row). Shows exactly what the backend
/// stored for that day: both clock events, radius/face-match signals, and
/// the HR note/review outcome if it was ever flagged.
class AttendanceRecordDetailScreen extends StatelessWidget {
  const AttendanceRecordDetailScreen({super.key, required this.record});

  final Map<String, dynamic> record;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final date = DateTime.tryParse(record['date']?.toString() ?? '');
    final note = record['note']?.toString();
    final faceScore = record['face_match_score'] as num?;
    final faceStatus = record['face_match_status']?.toString();
    final reviewedAt = record['reviewed_at']?.toString();

    return Scaffold(
      appBar: AppBar(
        title: Text(date != null
            ? '${t.attendanceDetailTitle} — ${formatDateLong(date)}'
            : t.attendanceDetailTitle),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _ClockSection(
            title: t.clockInTimeLabel,
            timeIso: record['clock_in_at']?.toString(),
            photoUrl: record['clock_in_photo_url']?.toString(),
            withinRadius: record['is_within_radius_in'] == true,
          ),
          const SizedBox(height: 16),
          _ClockSection(
            title: t.clockOutTimeLabel,
            timeIso: record['clock_out_at']?.toString(),
            photoUrl: record['clock_out_photo_url']?.toString(),
            withinRadius: record['is_within_radius_out'] == true,
          ),
          if (faceStatus != null) ...[
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(Icons.face_retouching_natural, color: Theme.of(context).colorScheme.primary),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        faceScore != null
                            ? '${t.faceMatchLabel}: $faceStatus (${(faceScore * 100).toStringAsFixed(0)}%)'
                            : '${t.faceMatchLabel}: $faceStatus',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          if (note != null && note.isNotEmpty) ...[
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(t.noteLabel, style: const TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    Text(note),
                  ],
                ),
              ),
            ),
          ],
          if (reviewedAt != null) ...[
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  '${t.reviewSuccessMessage}: ${formatDateTimeLong(DateTime.parse(reviewedAt))}',
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ClockSection extends StatelessWidget {
  const _ClockSection({
    required this.title,
    required this.timeIso,
    required this.photoUrl,
    required this.withinRadius,
  });

  final String title;
  final String? timeIso;
  final String? photoUrl;
  final bool withinRadius;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    if (timeIso == null || timeIso!.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text('$title: —'),
        ),
      );
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text(formatDateTimeLong(DateTime.parse(timeIso!))),
            const SizedBox(height: 8),
            Chip(
              avatar: Icon(
                withinRadius ? Icons.check_circle_outline : Icons.error_outline,
                size: 18,
                color: withinRadius ? colorScheme.onTertiaryContainer : colorScheme.onErrorContainer,
              ),
              label: Text(withinRadius ? t.withinRadiusLabel : t.outsideRadiusLabel),
              backgroundColor: withinRadius ? colorScheme.tertiaryContainer : colorScheme.errorContainer,
            ),
            if (photoUrl != null && photoUrl!.isNotEmpty) ...[
              const SizedBox(height: 12),
              GestureDetector(
                onTap: () => showDialog(
                  context: context,
                  builder: (context) => Dialog(child: Image.network(photoUrl!)),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(photoUrl!, height: 160, fit: BoxFit.cover),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
