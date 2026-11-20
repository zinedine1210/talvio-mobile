import 'package:go_router/go_router.dart';
import '../features/auth/presentation/register_company_screen.dart';
import '../features/auth/presentation/login_screen.dart';
import '../features/onboarding/presentation/onboarding_wizard_screen.dart';
import '../features/dashboard/presentation/home_screen.dart';
import '../features/dashboard/presentation/notifications_screen.dart';
import '../features/approval/presentation/persetujuan_hub_screen.dart';
import '../features/organization/presentation/master_organisasi_hub_screen.dart';
import 'app_shell.dart';
import '../features/employee/presentation/employee_list_screen.dart';
import '../features/employee/presentation/employee_form_screen.dart';
import '../features/employee/presentation/department_list_screen.dart';
import '../features/company/presentation/company_settings_screen.dart';
import '../features/employee/presentation/my_profile_screen.dart';
import '../features/employee/presentation/profile_settings_screen.dart';
import '../features/employee/presentation/profile_language_screen.dart';
import '../features/employee/presentation/profile_help_screen.dart';
import '../features/employee/presentation/change_password_screen.dart';
import '../features/attendance/presentation/attendance_screen.dart';
import '../features/attendance/presentation/attendance_report_screen.dart';
import '../features/attendance/presentation/camera_capture_screen.dart';
import '../features/attendance/presentation/pending_review_screen.dart';
import '../features/attendance/presentation/attendance_record_detail_screen.dart';
import '../features/leave/presentation/leave_form_screen.dart';
import '../features/leave/presentation/my_leave_screen.dart';
import '../features/request/presentation/permohonan_hub_screen.dart';
import '../features/leave/presentation/leave_approvals_screen.dart';
import '../features/leave/presentation/approval_config_screen.dart';
import '../features/correction/presentation/correction_form_screen.dart';
import '../features/correction/presentation/correction_approvals_screen.dart';
import '../features/overtime/presentation/overtime_form_screen.dart';
import '../features/overtime/presentation/my_overtime_screen.dart';
import '../features/overtime/presentation/overtime_approvals_screen.dart';
import '../features/report/presentation/reports_screen.dart';
import '../features/report/presentation/laporan_overview_screen.dart';
import '../features/announcement/presentation/announcement_list_screen.dart';
import '../features/announcement/presentation/announcement_detail_screen.dart';
import '../features/announcement/presentation/announcement_form_screen.dart';
import '../features/payroll/presentation/salary_components_screen.dart';
import '../features/payroll/presentation/employee_salary_list_screen.dart';
import '../features/payroll/presentation/employee_salary_detail_screen.dart';
import '../features/payroll/presentation/payroll_runs_screen.dart';
import '../features/payroll/presentation/payroll_hub_screen.dart';
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
    // Urutan branch di sini adalah index tetap yang dipakai AppShell
    // (home=0, attendance=1, employees=2, leave=3, approvals=4, profile=5)
    // untuk memetakan 4 tab yang ditampilkan per role ke branch yang
    // sesuai — jangan ubah urutan tanpa ikut ubah konstanta di app_shell.
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) => AppShell(navigationShell: navigationShell),
      branches: [
        StatefulShellBranch(routes: [
          GoRoute(path: '/home', builder: (context, state) => const HomeScreen()),
        ]),
        StatefulShellBranch(routes: [
          GoRoute(path: '/attendance', builder: (context, state) => const AttendanceScreen()),
        ]),
        StatefulShellBranch(routes: [
          GoRoute(path: '/employees', builder: (context, state) => const EmployeeListScreen()),
        ]),
        StatefulShellBranch(routes: [
          // Branch "Permohonan" (employee) — figma "07 Ajukan Permohonan".
          // Riwayat permohonan yang sudah diajukan masih di MyLeaveScreen,
          // dipush terpisah lewat '/leave/history' kalau dibutuhkan nanti.
          GoRoute(path: '/leave', builder: (context, state) => const PermohonanHubScreen()),
        ]),
        StatefulShellBranch(routes: [
          // Branch "Persetujuan" (HR) — figma "11 Persetujuan". Grouped
          // per-type counts (incl. corrections) still live at
          // '/notifications', reachable via the bell icon.
          GoRoute(path: '/approvals', builder: (context, state) => const PersetujuanHubScreen()),
        ]),
        StatefulShellBranch(routes: [
          GoRoute(path: '/profile', builder: (context, state) => const MyProfileScreen()),
        ]),
      ],
    ),
    GoRoute(
      path: '/notifications',
      builder: (context, state) => const NotificationsScreen(),
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
      path: '/organization',
      builder: (context, state) => const MasterOrganisasiHubScreen(),
    ),
    GoRoute(
      path: '/company/settings',
      builder: (context, state) => const CompanySettingsScreen(),
    ),
    GoRoute(
      path: '/attendance/capture',
      // `extra` carries the employee's enrolled profile photo URL when the
      // caller wants live face-match verification (attendance clock-in/out);
      // omitted for plain liveness-only capture (e.g. profile photo setup).
      builder: (context, state) => CameraCaptureScreen(profilePhotoUrl: state.extra as String?),
    ),
    GoRoute(
      path: '/profile/settings',
      builder: (context, state) => const ProfileSettingsScreen(),
    ),
    GoRoute(
      path: '/profile/language',
      builder: (context, state) => const ProfileLanguageScreen(),
    ),
    GoRoute(
      path: '/profile/help',
      builder: (context, state) => const ProfileHelpScreen(),
    ),
    GoRoute(
      path: '/profile/change-password',
      builder: (context, state) => const ChangePasswordScreen(),
    ),
    GoRoute(
      path: '/attendance/report',
      builder: (context, state) => const AttendanceReportScreen(),
    ),
    GoRoute(
      path: '/attendance/pending-review',
      builder: (context, state) => const PendingReviewScreen(),
    ),
    GoRoute(
      path: '/attendance/record-detail',
      builder: (context, state) =>
          AttendanceRecordDetailScreen(record: state.extra as Map<String, dynamic>),
    ),
    GoRoute(
      path: '/leave/history',
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
      builder: (context, state) => const LaporanOverviewScreen(),
    ),
    GoRoute(
      path: '/reports/detail',
      builder: (context, state) => const ReportsScreen(),
    ),
    GoRoute(
      path: '/announcements',
      builder: (context, state) => const AnnouncementListScreen(),
    ),
    GoRoute(
      path: '/announcements/detail',
      builder: (context, state) =>
          AnnouncementDetailScreen(announcement: state.extra as Map<String, dynamic>),
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
      path: '/payroll',
      builder: (context, state) => const PayrollHubScreen(),
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
