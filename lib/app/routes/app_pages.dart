import 'package:get/get.dart';

import '../../features/auth/presentation/bindings/auth_binding.dart';
import '../../features/auth/presentation/bindings/splash_binding.dart';
import '../../features/auth/presentation/pages/login_page.dart';
import '../../features/auth/presentation/pages/splash_page.dart';
import '../../features/dashboard/presentation/pages/admin_dashboard_page.dart';
import '../../features/dashboard/presentation/pages/distributor_dashboard_page.dart';
import '../../features/dsf/presentation/pages/dsf_home_page.dart';
import '../../features/duty/presentation/bindings/duty_binding.dart';
import 'app_routes.dart';

abstract class AppPages {
  static final pages = <GetPage<dynamic>>[
    GetPage(
      name: AppRoutes.splash,
      page: () => const SplashPage(),
      binding: SplashBinding(),
    ),
    GetPage(
      name: AppRoutes.login,
      page: () => const LoginPage(),
      binding: AuthBinding(),
    ),
    GetPage(
      name: AppRoutes.adminDashboard,
      page: () => const AdminDashboardPage(),
    ),
    GetPage(
      name: AppRoutes.dsfHome,
      page: () => const DsfHomePage(),
      binding: DutyBinding(),
    ),
    GetPage(
      name: AppRoutes.distributorDashboard,
      page: () => const DistributorDashboardPage(),
    ),
  ];
}
