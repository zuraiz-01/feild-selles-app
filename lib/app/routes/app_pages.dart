import 'package:get/get.dart';

import '../../features/auth/presentation/bindings/auth_binding.dart';
import '../../features/auth/presentation/bindings/splash_binding.dart';
import '../../features/auth/presentation/pages/bootstrap_accounts_page.dart';
import '../../features/auth/presentation/pages/login_page.dart';
import '../../features/auth/presentation/pages/splash_page.dart';
import '../../features/dashboard/presentation/pages/admin_dashboard_page.dart';
import '../../features/dashboard/presentation/pages/admin_dsfs_page.dart';
import '../../features/dashboard/presentation/pages/admin_shops_page.dart';
import '../../features/dashboard/presentation/pages/admin_products_page.dart';
import '../../features/dashboard/presentation/pages/admin_map_page.dart';
import '../../features/dashboard/presentation/pages/admin_seed_sample_page.dart';
import '../../features/dashboard/presentation/pages/distributor_dashboard_page.dart';
import '../../features/dsf/presentation/pages/dsf_home_page.dart';
import '../../features/dsf/presentation/pages/dsf_add_order_page.dart';
import '../../features/dsf/presentation/pages/dsf_add_stock_page.dart';
import '../../features/dsf/presentation/pages/shops_to_visit_page.dart';
import '../../features/dsf/presentation/pages/dsf_shop_visit_page.dart';
import '../../features/dsf/presentation/pages/dsf_products_page.dart';
import '../../features/duty/presentation/bindings/duty_binding.dart';
import '../../features/seed_import/presentation/bindings/seed_import_binding.dart';
import '../../features/seed_import/presentation/bindings/seed_tsa_binding.dart';
import '../../features/seed_import/presentation/pages/seed_import_page.dart';
import '../../features/seed_import/presentation/pages/shop_detail_page.dart';
import '../../features/seed_import/presentation/pages/tsa_account_page.dart';
import '../../features/seed_import/presentation/pages/tsa_detail_page.dart';
import '../../features/seed_import/presentation/pages/tsa_list_page.dart';
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
      name: AppRoutes.bootstrapAccounts,
      page: () => const BootstrapAccountsPage(),
    ),
    GetPage(
      name: AppRoutes.adminDashboard,
      page: () => const AdminDashboardPage(),
    ),
    GetPage(name: AppRoutes.adminDsfs, page: () => const AdminDsfsPage()),
    GetPage(name: AppRoutes.adminShops, page: () => const AdminShopsPage()),
    GetPage(
      name: AppRoutes.adminProducts,
      page: () => const AdminProductsPage(),
    ),
    GetPage(name: AppRoutes.adminMap, page: () => const AdminMapPage()),
    GetPage(
      name: AppRoutes.adminSeedSample,
      page: () => const AdminSeedSamplePage(),
    ),
    GetPage(
      name: AppRoutes.seedImport,
      page: () => const SeedImportPage(),
      binding: SeedImportBinding(),
    ),
    GetPage(name: AppRoutes.seedTsaList, page: () => const TsaListPage()),
    GetPage(
      name: AppRoutes.seedTsaAccount,
      page: () => const TsaAccountPage(),
      binding: SeedTsaBinding(),
    ),
    GetPage(name: AppRoutes.seedTsaDetail, page: () => const TsaDetailPage()),
    GetPage(name: AppRoutes.seedShopDetail, page: () => const ShopDetailPage()),
    GetPage(
      name: AppRoutes.dsfHome,
      page: () => const DsfHomePage(),
      binding: DutyBinding(),
    ),
    GetPage(name: AppRoutes.dsfShops, page: () => const ShopsToVisitPage()),
    GetPage(name: AppRoutes.dsfShopVisit, page: () => const DsfShopVisitPage()),
    GetPage(name: AppRoutes.dsfAddOrder, page: () => const DsfAddOrderPage()),
    GetPage(name: AppRoutes.dsfAddStock, page: () => const DsfAddStockPage()),
    GetPage(name: AppRoutes.dsfProducts, page: () => const DsfProductsPage()),
    GetPage(
      name: AppRoutes.distributorDashboard,
      page: () => const DistributorDashboardPage(),
    ),
  ];
}
