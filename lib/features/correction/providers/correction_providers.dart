import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api_client.dart';
import '../data/correction_api.dart';

final correctionApiProvider =
    Provider<CorrectionApi>((ref) => CorrectionApi(ref.watch(dioProvider)));

final pendingCorrectionsProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) {
  return ref.watch(correctionApiProvider).getPendingCorrections();
});
