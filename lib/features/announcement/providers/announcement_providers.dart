import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api_client.dart';
import '../data/announcement_api.dart';

final announcementApiProvider =
    Provider<AnnouncementApi>((ref) => AnnouncementApi(ref.watch(dioProvider)));

final announcementListProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) {
  return ref.watch(announcementApiProvider).getAnnouncements();
});
