import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:get/get.dart';

import '../../../../core/domain/services/geofence_policy.dart';
import '../../../../core/services/location/background_tracking_service.dart';
import '../../../../core/services/location/location_service.dart';
import '../../../../core/services/session/session_service.dart';
import '../../../distributors/data/datasources/distributors_remote_ds.dart';
import '../../../reports/data/datasources/report_storage_ds.dart';
import '../../../reports/data/datasources/reports_remote_ds.dart';
import '../../../reports/data/repositories/reports_repository_impl.dart';
import '../../../reports/domain/export/excel_exporter.dart';
import '../../../reports/domain/repositories/reports_repository.dart';
import '../../../reports/domain/usecases/build_daily_report_usecase.dart';
import '../../../tracking/data/datasources/tracking_remote_ds.dart';
import '../../data/datasources/duty_remote_ds.dart';
import '../../data/repositories/duty_repository_impl.dart';
import '../../domain/usecases/end_duty_usecase.dart';
import '../../domain/usecases/start_duty_usecase.dart';
import '../controllers/duty_controller.dart';

class DutyBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<DutyRemoteDataSource>(
      () => DutyRemoteDataSource(FirebaseFirestore.instance),
    );
    Get.lazyPut<DutyRepositoryImpl>(
      () => DutyRepositoryImpl(Get.find<DutyRemoteDataSource>()),
    );

    Get.lazyPut<DistributorsRemoteDataSource>(
      () => DistributorsRemoteDataSource(FirebaseFirestore.instance),
    );

    Get.lazyPut<TrackingRemoteDataSource>(
      () => TrackingRemoteDataSource(FirebaseFirestore.instance),
    );

    Get.put<BackgroundTrackingService>(
      BackgroundTrackingService(
        Get.find<LocationService>(),
        Get.find<TrackingRemoteDataSource>(),
        Get.find<SessionService>(),
      ),
      permanent: true,
    );

    Get.lazyPut<ExcelExporter>(() => ExcelExporter());
    Get.lazyPut<ReportStorageDataSource>(
      () => ReportStorageDataSource(FirebaseStorage.instance),
    );
    Get.lazyPut<ReportsRemoteDataSource>(
      () => ReportsRemoteDataSource(FirebaseFirestore.instance),
    );
    Get.lazyPut<ReportsRepository>(
      () => ReportsRepositoryImpl(
        Get.find<ReportStorageDataSource>(),
        Get.find<ReportsRemoteDataSource>(),
      ),
    );

    Get.lazyPut<BuildDailyReportUseCase>(
      () => BuildDailyReportUseCase(
        Get.find<DutyRepositoryImpl>(),
        Get.find<ExcelExporter>(),
        Get.find<ReportsRepository>(),
      ),
    );

    Get.lazyPut<StartDutyUseCase>(
      () => StartDutyUseCase(
        Get.find<SessionService>(),
        Get.find<LocationService>(),
        Get.find<GeofencePolicy>(),
        Get.find<DistributorsRemoteDataSource>(),
        Get.find<DutyRepositoryImpl>(),
        Get.find<BackgroundTrackingService>(),
      ),
    );

    Get.lazyPut<EndDutyUseCase>(
      () => EndDutyUseCase(
        Get.find<SessionService>(),
        Get.find<LocationService>(),
        Get.find<DutyRepositoryImpl>(),
        Get.find<BackgroundTrackingService>(),
        Get.find<BuildDailyReportUseCase>(),
      ),
    );

    Get.lazyPut<DutyController>(
      () => DutyController(
        Get.find<SessionService>(),
        Get.find<StartDutyUseCase>(),
        Get.find<EndDutyUseCase>(),
      ),
    );
  }
}
