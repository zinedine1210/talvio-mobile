import 'package:dio/dio.dart';

class OnboardingApi {
  OnboardingApi(this._dio);
  final Dio _dio;

  Future<void> submit(Map<String, dynamic> payload) async {
    await _dio.post('/company/onboarding', data: payload);
  }
}
