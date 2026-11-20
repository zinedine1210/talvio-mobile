import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api_client.dart';
import '../data/company_api.dart';

final companyApiProvider = Provider<CompanyApi>((ref) => CompanyApi(ref.watch(dioProvider)));

final companyMeProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) {
  return ref.watch(companyApiProvider).getMe();
});
