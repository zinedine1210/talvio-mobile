import 'package:go_router/go_router.dart';
import '../features/auth/presentation/register_company_screen.dart';
import '../features/auth/presentation/login_screen.dart';
import '../features/onboarding/presentation/onboarding_wizard_screen.dart';
import '../features/dashboard/presentation/home_screen.dart';

final appRouter = GoRouter(
  initialLocation: '/register-company',
  routes: [
    GoRoute(
      path: '/register-company',
      builder: (context, state) => const RegisterCompanyScreen(),
    ),
    GoRoute(
      path: '/login',
      builder: (context, state) => const LoginScreen(),
    ),
    GoRoute(
      path: '/onboarding',
      builder: (context, state) => const OnboardingWizardScreen(),
    ),
    GoRoute(
      path: '/home',
      builder: (context, state) => const HomeScreen(),
    ),
  ],
);
