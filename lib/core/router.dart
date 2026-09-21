import 'package:go_router/go_router.dart';
import '../features/auth/presentation/register_company_screen.dart';
import '../features/auth/presentation/login_screen.dart';
import '../features/onboarding/presentation/onboarding_wizard_screen.dart';
import '../features/dashboard/presentation/home_screen.dart';
import '../features/employee/presentation/employee_list_screen.dart';
import '../features/employee/presentation/employee_form_screen.dart';
import '../features/employee/presentation/department_list_screen.dart';
import '../features/employee/presentation/my_profile_screen.dart';
import '../features/attendance/presentation/attendance_screen.dart';
import '../features/attendance/presentation/camera_capture_screen.dart';
import '../features/attendance/presentation/pending_review_screen.dart';
import '../features/leave/presentation/leave_form_screen.dart';
import '../features/leave/presentation/my_leave_screen.dart';
import '../features/leave/presentation/leave_approvals_screen.dart';
import '../features/leave/presentation/approval_config_screen.dart';

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
    GoRoute(
      path: '/attendance',
      builder: (context, state) => const AttendanceScreen(),
    ),
    GoRoute(
      path: '/attendance/capture',
      builder: (context, state) => const CameraCaptureScreen(),
    ),
    GoRoute(
      path: '/attendance/pending-review',
      builder: (context, state) => const PendingReviewScreen(),
    ),
    GoRoute(
      path: '/leave',
      builder: (context, state) => const MyLeaveScreen(),
    ),
    GoRoute(
      path: '/leave/new',
      builder: (context, state) => const LeaveFormScreen(),
    ),
    GoRoute(
      path: '/leave/approvals',
      builder: (context, state) => const LeaveApprovalsScreen(),
    ),
    GoRoute(
      path: '/company/approval-configs',
      builder: (context, state) => const ApprovalConfigScreen(),
    ),
  ],
);
