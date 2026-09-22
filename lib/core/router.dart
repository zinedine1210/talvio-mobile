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
import '../features/correction/presentation/correction_form_screen.dart';
import '../features/correction/presentation/correction_approvals_screen.dart';
import '../features/overtime/presentation/overtime_form_screen.dart';
import '../features/overtime/presentation/my_overtime_screen.dart';
import '../features/overtime/presentation/overtime_approvals_screen.dart';
import '../features/report/presentation/reports_screen.dart';
import '../features/announcement/presentation/announcement_list_screen.dart';
import '../features/announcement/presentation/announcement_form_screen.dart';
import '../features/payroll/presentation/salary_components_screen.dart';
import '../features/payroll/presentation/employee_salary_list_screen.dart';
import '../features/payroll/presentation/employee_salary_detail_screen.dart';
import '../features/payroll/presentation/payroll_runs_screen.dart';
import '../features/payroll/presentation/payroll_run_detail_screen.dart';
import '../features/payroll/presentation/my_payslip_screen.dart';

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
      // `extra` carries the employee's enrolled profile photo URL when the
      // caller wants live face-match verification (attendance clock-in/out);
      // omitted for plain liveness-only capture (e.g. profile photo setup).
      builder: (context, state) => CameraCaptureScreen(profilePhotoUrl: state.extra as String?),
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
    GoRoute(
      path: '/corrections/new',
      builder: (context, state) => const CorrectionFormScreen(),
    ),
    GoRoute(
      path: '/corrections/approvals',
      builder: (context, state) => const CorrectionApprovalsScreen(),
    ),
    GoRoute(
      path: '/overtime',
      builder: (context, state) => const MyOvertimeScreen(),
    ),
    GoRoute(
      path: '/overtime/new',
      builder: (context, state) => const OvertimeFormScreen(),
    ),
    GoRoute(
      path: '/overtime/approvals',
      builder: (context, state) => const OvertimeApprovalsScreen(),
    ),
    GoRoute(
      path: '/reports',
      builder: (context, state) => const ReportsScreen(),
    ),
    GoRoute(
      path: '/announcements',
      builder: (context, state) => const AnnouncementListScreen(),
    ),
    GoRoute(
      path: '/announcements/new',
      builder: (context, state) => const AnnouncementFormScreen(),
    ),
    GoRoute(
      path: '/payroll/salary-components',
      builder: (context, state) => const SalaryComponentsScreen(),
    ),
    GoRoute(
      path: '/payroll/employees',
      builder: (context, state) => const EmployeeSalaryListScreen(),
    ),
    GoRoute(
      path: '/payroll/employees/salary',
      builder: (context, state) =>
          EmployeeSalaryDetailScreen(employee: state.extra as Map<String, dynamic>),
    ),
    GoRoute(
      path: '/payroll/runs',
      builder: (context, state) => const PayrollRunsScreen(),
    ),
    GoRoute(
      path: '/payroll/runs/:id',
      builder: (context, state) =>
          PayrollRunDetailScreen(runId: int.parse(state.pathParameters['id']!)),
    ),
    GoRoute(
      path: '/payroll/my-slips',
      builder: (context, state) => const MyPayslipScreen(),
    ),
  ],
);
