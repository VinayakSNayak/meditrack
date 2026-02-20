import 'package:connectivity_plus/connectivity_plus.dart';
import 'local_cache_service.dart';
import 'firestore_service.dart';

class SyncService {
  static Future<void> syncPendingStatuses() async {
    final connectivity =
    await Connectivity()
        .checkConnectivity();

    if (connectivity ==
        ConnectivityResult.none) {
      return;
    }

    final pending =
    await LocalCacheService
        .getPendingStatuses();

    if (pending.isEmpty) {
      return;
    }

    for (final item in pending) {
      final prescriptionId =
      item['prescriptionId'];
      final status = item['status'];

      await FirestoreService
          .markMedicineStatus(
        prescriptionId:
        prescriptionId,
        status: status,
      );
    }

    await LocalCacheService
        .clearPending();
  }
}