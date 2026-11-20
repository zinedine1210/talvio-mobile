import 'package:flutter/material.dart';

import '../../../core/formatters.dart';
import '../../../l10n/app_localizations.dart';

/// "09c Detail Pengumuman" — just the full body, since the list card
/// already truncates it to 2 lines.
class AnnouncementDetailScreen extends StatelessWidget {
  const AnnouncementDetailScreen({super.key, required this.announcement});

  final Map<String, dynamic> announcement;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final created = DateTime.tryParse(announcement['created_at']?.toString() ?? '');

    return Scaffold(
      appBar: AppBar(title: Text(t.announcementsTitle)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          DecoratedBox(
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: const BoxDecoration(
                            color: Color(0xFFCCFBF1), shape: BoxShape.circle),
                        child: const Icon(Icons.campaign_outlined,
                            color: Color(0xFF0D9488), size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          announcement['title']?.toString() ?? '-',
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(announcement['body']?.toString() ?? ''),
                  const SizedBox(height: 12),
                  Text(
                    created != null ? formatDateTimeLong(created) : '',
                    style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
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
