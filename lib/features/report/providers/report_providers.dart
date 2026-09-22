import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api_client.dart';
import '../data/report_api.dart';

final reportApiProvider = Provider<ReportApi>((ref) => ReportApi(ref.watch(dioProvider)));
