import 'package:go_router/go_router.dart';
import '../features/auth/presentation/register_company_screen.dart';
import '../features/auth/presentation/login_screen.dart';
import '../features/onboarding/presentation/onboarding_wizard_screen.dart';
import '../features/dashboard/presentation/home_screen.dart';
import '../features/employee/presentation/employee_list_screen.dart';
import '../features/employee/presentation/employee_form_screen.dart';
import '../features/employee/presentation/department_list_screen.dart';
import '../features/employee/presentation/my_profile_screen.dart';

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
    GoRoute(
      path: '/employees',
      builder: (context, state) => const EmployeeListScreen(),
    ),
    GoRoute(
      path: '/employees/new',
      builder: (context, state) => const EmployeeFormScreen(),
    ),
    GoRoute(
      path: '/employees/edit',
      builder: (context, state) =>
          EmployeeFormScreen(employee: state.extra as Map<String, dynamic>?),
    ),
    GoRoute(
      path: '/departments',
      builder: (context, state) => const DepartmentListScreen(),
    ),
    GoRoute(
      path: '/profile',
      builder: (context, state) => const MyProfileScreen(),
    ),
  ],
);
