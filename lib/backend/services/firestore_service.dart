import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'notification_service.dart';

class FirestoreService {
  static final FirebaseFirestore _firestore =
      FirebaseFirestore.instance;
  static final FirebaseAuth _auth =
      FirebaseAuth.instance;

  static String get _uid =>
      _auth.currentUser!.uid;

  static DocumentReference<Map<String, dynamic>> get _userDoc =>
      _firestore.collection('users').doc(_uid);

  // ================= MEMBER =================

  static Future<void> createUserWithSelfMember(
      String name) async {
    final memberRef =
    _userDoc.collection('members').doc();

    await _userDoc.set({
      'activeMemberId': memberRef.id,
    });

    await memberRef.set({
      'name': name,
      'age': 0,
      'relation': 'Self',
      'isSelf': true,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  static Future<void> addMember({
    required String name,
    required int age,
    required String relation,
  }) async {
    await _userDoc.collection('members').add({
      'name': name,
      'age': age,
      'relation': relation,
      'isSelf': false,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  static Stream<QuerySnapshot<Map<String, dynamic>>> getMembers() {
    return _userDoc
        .collection('members')
        .orderBy('createdAt')
        .snapshots();
  }

  static Future<void> setActiveMember(
      String memberId) async {
    await _userDoc.update({
      'activeMemberId': memberId,
    });
  }

  static Stream<String?> getActiveMemberId() {
    return _userDoc.snapshots().map((snapshot) {
      if (!snapshot.exists) return null;
      final data = snapshot.data();
      return data?['activeMemberId'] as String?;
    });
  }

  static Future<String?> _getMemberId() async {
    return await getActiveMemberId().first;
  }

  static Stream<DocumentSnapshot<Map<String, dynamic>>>
  getActiveMember() async* {
    final memberId = await _getMemberId();
    if (memberId == null) return;

    yield* _userDoc
        .collection('members')
        .doc(memberId)
        .snapshots();
  }

  static Future<void>
  updateActiveMemberProfile({
    required String name,
    required int age,
    required String relation,
  }) async {
    final memberId = await _getMemberId();
    if (memberId == null) return;

    await _userDoc
        .collection('members')
        .doc(memberId)
        .update({
      'name': name,
      'age': age,
      'relation': relation,
    });
  }

  static Stream<DocumentSnapshot<Map<String, dynamic>>>
  getAccountOwner() {
    return _userDoc
        .collection('members')
        .where('isSelf', isEqualTo: true)
        .limit(1)
        .snapshots()
        .map((query) => query.docs.first);
  }

  // ================= PRESCRIPTIONS =================

  static Future<void> addPrescription({
    required String medicineName,
    required String foodTiming,
    String? dosage,
    required DateTime time,
    String? notes,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final memberId = await _getMemberId();
    if (memberId == null) return;

    final docRef = _userDoc
        .collection('members')
        .doc(memberId)
        .collection('prescriptions')
        .doc();

    final notificationId =
    await NotificationService
        .scheduleDailyNotification(
      title: medicineName,
      body: foodTiming,
      time: time,
      payload: docRef.id,
    );

    await docRef.set({
      'medicineName': medicineName,
      'foodTiming': foodTiming,
      'dosage': dosage ?? '',
      'time': Timestamp.fromDate(time),
      'notes': notes ?? '',
      'startDate': startDate != null
          ? Timestamp.fromDate(startDate)
          : null,
      'endDate': endDate != null
          ? Timestamp.fromDate(endDate)
          : null,
      'notificationId': notificationId,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  static Future<void> updatePrescription({
    required String prescriptionId,
    required String medicineName,
    required String foodTiming,
    String? dosage,
    required DateTime time,
    String? notes,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final memberId = await _getMemberId();
    if (memberId == null) return;

    await _userDoc
        .collection('members')
        .doc(memberId)
        .collection('prescriptions')
        .doc(prescriptionId)
        .update({
      'medicineName': medicineName,
      'foodTiming': foodTiming,
      'dosage': dosage ?? '',
      'time': Timestamp.fromDate(time),
      'notes': notes ?? '',
      'startDate': startDate != null
          ? Timestamp.fromDate(startDate)
          : null,
      'endDate': endDate != null
          ? Timestamp.fromDate(endDate)
          : null,
    });
  }

  static Future<void> deletePrescription(
      String prescriptionId,
      int notificationId) async {
    final memberId = await _getMemberId();
    if (memberId == null) return;

    await NotificationService
        .cancelNotification(notificationId);

    await _userDoc
        .collection('members')
        .doc(memberId)
        .collection('prescriptions')
        .doc(prescriptionId)
        .delete();
  }

  static Stream<QuerySnapshot<Map<String, dynamic>>>
  getPrescriptions() async* {
    final memberId = await _getMemberId();
    if (memberId == null) return;

    yield* _userDoc
        .collection('members')
        .doc(memberId)
        .collection('prescriptions')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  // ================= STATUS =================

  static Future<void> markMedicineStatus({
    required String prescriptionId,
    required String status,
  }) async {
    final memberId = await _getMemberId();
    if (memberId == null) return;

    final today = DateTime.now();
    final dateId =
        "${today.year}-${today.month}-${today.day}";

    await _userDoc
        .collection('members')
        .doc(memberId)
        .collection('prescriptions')
        .doc(prescriptionId)
        .collection('dailyStatus')
        .doc(dateId)
        .set({
      'status': status,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  static Stream<QuerySnapshot<Map<String, dynamic>>>
  getTodayStatus(String prescriptionId) async* {
    final memberId = await _getMemberId();
    if (memberId == null) return;

    final today = DateTime.now();
    final dateId =
        "${today.year}-${today.month}-${today.day}";

    yield* _userDoc
        .collection('members')
        .doc(memberId)
        .collection('prescriptions')
        .doc(prescriptionId)
        .collection('dailyStatus')
        .where(FieldPath.documentId,
        isEqualTo: dateId)
        .snapshots();
  }

  // ================= TODAY COUNTS =================

  static Stream<int> getTodayTakenCountStream() async* {
    final memberId = await _getMemberId();
    if (memberId == null) return;

    final today = DateTime.now();
    final dateId =
        "${today.year}-${today.month}-${today.day}";

    yield* _userDoc
        .collection('members')
        .doc(memberId)
        .collection('prescriptions')
        .snapshots()
        .asyncMap((snapshot) async {
      int count = 0;

      for (var doc in snapshot.docs) {
        final statusDoc = await doc.reference
            .collection('dailyStatus')
            .doc(dateId)
            .get();

        if (statusDoc.exists) {
          final data = statusDoc.data();
          if (data != null &&
              data['status'] == 'taken') {
            count++;
          }
        }
      }

      return count;
    });
  }

  static Stream<int> getTodayMissedCountStream() async* {
    final memberId = await _getMemberId();
    if (memberId == null) return;

    final today = DateTime.now();
    final dateId =
        "${today.year}-${today.month}-${today.day}";

    yield* _userDoc
        .collection('members')
        .doc(memberId)
        .collection('prescriptions')
        .snapshots()
        .asyncMap((snapshot) async {
      int count = 0;

      for (var doc in snapshot.docs) {
        final statusDoc = await doc.reference
            .collection('dailyStatus')
            .doc(dateId)
            .get();

        if (statusDoc.exists) {
          final data = statusDoc.data();
          if (data != null &&
              data['status'] == 'missed') {
            count++;
          }
        }
      }

      return count;
    });
  }
  // ================= TODAY PRESCRIPTIONS =================

  static Stream<QuerySnapshot<Map<String, dynamic>>>
  getTodayPrescriptionsStream() async* {
    final memberId = await _getMemberId();
    if (memberId == null) return;

    yield* _userDoc
        .collection('members')
        .doc(memberId)
        .collection('prescriptions')
        .snapshots();
  }

  // ================= WEEKLY ANALYTICS =================

  static Stream<List<int>> getWeeklyTakenHistoryStream() async* {
    final memberId = await _getMemberId();
    if (memberId == null) return;

    final now = DateTime.now();

    yield* _userDoc
        .collection('members')
        .doc(memberId)
        .collection('prescriptions')
        .snapshots()
        .asyncMap((snapshot) async {
      List<int> weekly = List.generate(7, (_) => 0);

      for (int i = 0; i < 7; i++) {
        final date = now.subtract(Duration(days: i));
        final dateId =
            "${date.year}-${date.month}-${date.day}";

        for (var doc in snapshot.docs) {
          final statusDoc = await doc.reference
              .collection('dailyStatus')
              .doc(dateId)
              .get();

          if (statusDoc.exists) {
            final data = statusDoc.data();
            if (data != null &&
                data['status'] == 'taken') {
              weekly[i]++;
            }
          }
        }
      }

      return weekly;
    });
  }

// ================= STREAK =================

  static Stream<int> getCurrentStreakStream() async* {
    final memberId = await _getMemberId();
    if (memberId == null) return;

    final now = DateTime.now();

    yield* _userDoc
        .collection('members')
        .doc(memberId)
        .collection('prescriptions')
        .snapshots()
        .asyncMap((snapshot) async {
      int streak = 0;

      for (int i = 0; i < 30; i++) {
        final date = now.subtract(Duration(days: i));
        final dateId =
            "${date.year}-${date.month}-${date.day}";

        bool allTaken = true;

        for (var doc in snapshot.docs) {
          final statusDoc = await doc.reference
              .collection('dailyStatus')
              .doc(dateId)
              .get();

          if (!statusDoc.exists ||
              statusDoc.data()?['status'] !=
                  'taken') {
            allTaken = false;
            break;
          }
        }

        if (allTaken) {
          streak++;
        } else {
          break;
        }
      }

      return streak;
    });
  }

  // ================= OPTIMIZED WEEKLY DATA =================

  static Stream<Map<String, int>> getWeeklyStatusSummaryStream() async* {
    final memberId = await _getMemberId();
    if (memberId == null) return;

    final now = DateTime.now();
    final startOfWeek = now.subtract(const Duration(days: 6));

    yield* _userDoc
        .collection('members')
        .doc(memberId)
        .collection('prescriptions')
        .snapshots()
        .asyncMap((prescriptionSnap) async {
      Map<String, int> result = {};

      for (int i = 0; i < 7; i++) {
        final date = startOfWeek.add(Duration(days: i));
        final dateId =
            "${date.year}-${date.month}-${date.day}";
        result[dateId] = 0;
      }

      for (var doc in prescriptionSnap.docs) {
        for (int i = 0; i < 7; i++) {
          final date = startOfWeek.add(Duration(days: i));
          final dateId =
              "${date.year}-${date.month}-${date.day}";

          final statusDoc = await doc.reference
              .collection('dailyStatus')
              .doc(dateId)
              .get();

          if (statusDoc.exists &&
              statusDoc.data()?['status'] == 'taken') {
            result[dateId] =
                (result[dateId] ?? 0) + 1;
          }
        }
      }

      return result;
    });
  }

// ================= MONTH HEATMAP =================

  static Stream<Map<String, bool>> getMonthlyHeatmapStream() async* {
    final memberId = await _getMemberId();
    if (memberId == null) return;

    final now = DateTime.now();
    final firstDay =
    DateTime(now.year, now.month, 1);

    yield* _userDoc
        .collection('members')
        .doc(memberId)
        .collection('prescriptions')
        .snapshots()
        .asyncMap((prescriptionSnap) async {
      Map<String, bool> heatmap = {};

      for (int i = 0; i < now.day; i++) {
        final date = firstDay.add(Duration(days: i));
        final dateId =
            "${date.year}-${date.month}-${date.day}";
        heatmap[dateId] = false;
      }

      for (var doc in prescriptionSnap.docs) {
        for (int i = 0; i < now.day; i++) {
          final date = firstDay.add(Duration(days: i));
          final dateId =
              "${date.year}-${date.month}-${date.day}";

          final statusDoc = await doc.reference
              .collection('dailyStatus')
              .doc(dateId)
              .get();

          if (statusDoc.exists &&
              statusDoc.data()?['status'] == 'taken') {
            heatmap[dateId] = true;
          }
        }
      }

      return heatmap;
    });
  }

}



