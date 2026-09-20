import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api_client.dart';
import '../data/onboarding_api.dart';

final onboardingApiProvider =
    Provider<OnboardingApi>((ref) => OnboardingApi(ref.watch(dioProvider)));
