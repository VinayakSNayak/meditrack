import 'package:connectivity_plus/connectivity_plus.dart';
import 'local_cache_service.dart';

/// SyncService handles syncing offline-cached data when connectivity is restored.
/// Note: With the snooze-only reminder model, medicine status is no longer
/// cached offline. This service clears any stale cache from previous versions.
class SyncService {
  static Future<void> syncPendingStatuses() async {
    try {
      final connectivity =
          await Connectivity().checkConnectivity();
      final isOffline = connectivity.isEmpty ||
          connectivity.every((r) => r == ConnectivityResult.none);
      if (isOffline) return;

      // Clear any stale pending statuses from previous app version
      final pending = await LocalCacheService.getPendingStatuses();
      if (pending.isEmpty) return;

      // Previous version stored taken/missed status offline.
      // Since we no longer track taken/missed, clear the cache.
      await LocalCacheService.clearPending();
    } catch (_) {
      // Best-effort — do not crash
    }
  }
}