import 'package:get/get.dart';

import '../../../../core/services/session/session_service.dart';
import '../../domain/usecases/end_duty_usecase.dart';
import '../../domain/usecases/start_duty_usecase.dart';

class DutyController extends GetxController {
  final SessionService _session;
  final StartDutyUseCase _startDuty;
  final EndDutyUseCase _endDuty;

  DutyController(this._session, this._startDuty, this._endDuty);

  final isLoading = false.obs;
  final error = RxnString();

  String? get activeDutyId => _session.activeDutyId;

  Future<void> startDuty() async {
    isLoading.value = true;
    error.value = null;
    try {
      await _startDuty();
      update();
    } catch (e) {
      error.value = e.toString();
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> endDuty({required bool uploadReport}) async {
    isLoading.value = true;
    error.value = null;
    try {
      await _endDuty(uploadReport: uploadReport);
      update();
    } catch (e) {
      error.value = e.toString();
    } finally {
      isLoading.value = false;
    }
  }
}
