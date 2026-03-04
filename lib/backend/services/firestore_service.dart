import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../core/errors/app_exception.dart';

class FirestoreService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  static String get uid {
    final user = _auth.currentUser;
    if (user == null) throw const AuthException('User not authenticated');
    return user.uid;
  }

  static DocumentReference<Map<String, dynamic>> get _userDoc =>
      _firestore.collection('users').doc(uid);

  // =========================================================
  // ============= REACTIVE STREAM HELPER ====================
  // =========================================================

  /// Creates a Stream that automatically re-subscribes to the inner stream
  /// whenever activeMemberId changes. This is the core fix for Issue 1.
  static Stream<T> _memberStream<T>(
    Stream<T> Function(String memberId) factory,
  ) {
    late StreamController<T> controller;
    StreamSubscription? memberSub;
    StreamSubscription? dataSub;

    void subscribe(String memberId) {
      dataSub?.cancel();
      dataSub = factory(memberId).listen(
        (data) => controller.add(data),
        onError: (e) => controller.addError(e),
      );
    }

    controller = StreamController<T>(
      onListen: () {
        memberSub = getActiveMemberId().listen((memberId) {
          if (memberId != null) subscribe(memberId);
        });
      },
      onCancel: () {
        memberSub?.cancel();
        dataSub?.cancel();
      },
    );

    return controller.stream;
  }

  // =========================================================
  // ================= MEMBER MANAGEMENT =====================
  // =========================================================

  static Future<void> createUserWithSelfMember(String name) async {
    try {
      final memberRef = _userDoc.collection('members').doc();

      await _userDoc.set({
        'activeMemberId': memberRef.id,
        'createdAt': FieldValue.serverTimestamp(),
      });

      await memberRef.set({
        'name': name,
        'age': 0,
        'relation': 'Self',
        'isSelf': true,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw FirestoreException('Failed to create user profile: $e');
    }
  }

  static Future<void> addMember({
    required String name,
    required int age,
    required String relation,
  }) async {
    try {
      await _userDoc.collection('members').add({
        'name': name,
        'age': age,
        'relation': relation,
        'isSelf': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw FirestoreException('Failed to add member: $e');
    }
  }

  // Alias for backward-compatibility with add_family_screen
  static Future<void> addFamilyMember({
    required String name,
    required int age,
    required String relation,
    String gender = 'Not Specified',
    String bloodGroup = '',
    List<String> conditions = const [],
    bool isPrimary = false,
  }) =>
      addMember(name: name, age: age, relation: relation);

  static Stream<QuerySnapshot<Map<String, dynamic>>> getMembers() {
    return _userDoc
        .collection('members')
        .orderBy('createdAt')
        .snapshots();
  }

  // Alias for backward-compatibility with family_list_screen
  static Stream<QuerySnapshot<Map<String, dynamic>>> getFamilyMembers() =>
      getMembers();

  static Future<void> setActiveMember(String memberId) async {
    try {
      await _userDoc.update({'activeMemberId': memberId});
    } catch (e) {
      throw FirestoreException('Failed to switch member: $e');
    }
  }

  static Stream<String?> getActiveMemberId() {
    return _userDoc.snapshots().map((snapshot) {
      return snapshot.data()?['activeMemberId'] as String?;
    });
  }

  static Future<String?> getActiveMemberIdOnce() => _getActiveMemberId();

  static Future<String?> _getActiveMemberId() async {
    try {
      final snapshot = await _userDoc.get();
      return snapshot.data()?['activeMemberId'] as String?;
    } catch (e) {
      return null;
    }
  }

  static Future<CollectionReference<Map<String, dynamic>>?>
  getMemberCollection(String collectionName) async {
    final memberId = await _getActiveMemberId();
    if (memberId == null) return null;

    return _userDoc
        .collection('members')
        .doc(memberId)
        .collection(collectionName);
  }

  static Stream<DocumentSnapshot<Map<String, dynamic>>> getActiveMember() {
    return _memberStream((memberId) =>
        _userDoc.collection('members').doc(memberId).snapshots());
  }

  static Stream<DocumentSnapshot<Map<String, dynamic>>?> getAccountOwner() {
    return _userDoc
        .collection('members')
        .where('isSelf', isEqualTo: true)
        .limit(1)
        .snapshots()
        .map((query) => query.docs.isEmpty ? null : query.docs.first);
  }

  static Future<void> updateActiveMemberProfile({
    required String name,
    required int age,
    required String relation,
  }) async {
    try {
      final memberId = await _getActiveMemberId();
      if (memberId == null) return;

      await _userDoc.collection('members').doc(memberId).update({
        'name': name,
        'age': age,
        'relation': relation,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw FirestoreException('Failed to update profile: $e');
    }
  }

  // =========================================================
  // ================= PRESCRIPTIONS =========================
  // NOTE: Prescription CRUD is now handled by PrescriptionFirestoreService.
  // Only context helpers remain here for chatbot / dashboard use.
  // =========================================================


  // =========================================================
  // ================= HEALTH MODULE =========================
  // =========================================================

  static Future<void> addBodyVitalMetric({
    required String type,
    required dynamic value,
    required String unit,
    required DateTime recordDate,
  }) async {
    final collection = await getMemberCollection('bodyVitals');
    if (collection == null) return;

    await collection.add({
      'type': type,
      'value': value,
      'unit': unit,
      'recordDate': Timestamp.fromDate(recordDate),
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  // History fix: add a new document on every edit so all past values
  // are preserved and visible in the history screen.
  static Future<void> updateBodyVitalMetric({
    required String docId,
    required String type,
    required dynamic value,
    required String unit,
    required DateTime recordDate,
  }) async {
    final collection = await getMemberCollection('bodyVitals');
    if (collection == null) return;

    await collection.add({
      'type': type,
      'value': value,
      'unit': unit,
      'recordDate': Timestamp.fromDate(recordDate),
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  static Future<void> deleteBodyVital(String docId) async {
    final collection = await getMemberCollection('bodyVitals');
    if (collection == null) return;
    await collection.doc(docId).delete();
  }

  /// Deletes ALL history documents for a given vital type (used by view screen delete button).
  static Future<void> deleteAllBodyVitalsByType(String type) async {
    final collection = await getMemberCollection('bodyVitals');
    if (collection == null) return;
    final snap = await collection.where('type', isEqualTo: type).get();
    for (final doc in snap.docs) {
      await doc.reference.delete();
    }
  }

  static Stream<QuerySnapshot<Map<String, dynamic>>>
      getBodyVitalMetrics() {
    return _memberStream((memberId) => _userDoc
        .collection('members')
        .doc(memberId)
        .collection('bodyVitals')
        .orderBy('recordDate', descending: true)
        .snapshots());
  }

  static Future<void> addBloodMetric({
    required String type,
    required dynamic value,
    required String unit,
    required DateTime recordDate,
  }) async {
    final collection = await getMemberCollection('bloodRecords');
    if (collection == null) return;

    await collection.add({
      'type': type,
      'value': value,
      'unit': unit,
      'recordDate': Timestamp.fromDate(recordDate),
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  // History fix: add a new document on every edit so all past values
  // are preserved and visible in the history screen.
  static Future<void> updateBloodMetric({
    required String docId,
    required String type,
    required dynamic value,
    required String unit,
    required DateTime recordDate,
  }) async {
    final collection = await getMemberCollection('bloodRecords');
    if (collection == null) return;

    await collection.add({
      'type': type,
      'value': value,
      'unit': unit,
      'recordDate': Timestamp.fromDate(recordDate),
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  static Future<void> deleteBloodMetric(String docId) async {
    final collection = await getMemberCollection('bloodRecords');
    if (collection == null) return;
    await collection.doc(docId).delete();
  }

  /// Deletes ALL history documents for a given blood metric type.
  static Future<void> deleteAllBloodMetricsByType(String type) async {
    final collection = await getMemberCollection('bloodRecords');
    if (collection == null) return;
    final snap = await collection.where('type', isEqualTo: type).get();
    for (final doc in snap.docs) {
      await doc.reference.delete();
    }
  }

  static Stream<QuerySnapshot<Map<String, dynamic>>> getBloodMetrics() {
    return _memberStream((memberId) => _userDoc
        .collection('members')
        .doc(memberId)
        .collection('bloodRecords')
        .orderBy('recordDate', descending: true)
        .snapshots());
  }

  static Future<void> addCondition({
    required String conditionName,
    required DateTime diagnosedDate,
    required String status,
    required bool hasMedication,
    String? medication,
    String? doctorName,
    String? notes,
  }) async {
    final collection = await getMemberCollection('conditions');
    if (collection == null) return;

    await collection.add({
      'conditionName': conditionName,
      'diagnosedDate': Timestamp.fromDate(diagnosedDate),
      'status': status,
      'hasMedication': hasMedication,
      'medication': medication ?? '',
      'doctorName': doctorName ?? '',
      'notes': notes ?? '',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  static Future<void> updateCondition({
    required String docId,
    required String conditionName,
    required DateTime diagnosedDate,
    required String status,
    required bool hasMedication,
    required String medication,
    required String doctorName,
    required String notes,
  }) async {
    final collection = await getMemberCollection('conditions');
    if (collection == null) return;

    await collection.doc(docId).update({
      'conditionName': conditionName,
      'diagnosedDate': Timestamp.fromDate(diagnosedDate),
      'status': status,
      'hasMedication': hasMedication,
      'medication': medication,
      'doctorName': doctorName,
      'notes': notes,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  static Future<void> deleteCondition(String docId) async {
    final collection = await getMemberCollection('conditions');
    if (collection == null) return;
    await collection.doc(docId).delete();
  }

  static Stream<QuerySnapshot<Map<String, dynamic>>> getConditions() {
    return _memberStream((memberId) => _userDoc
        .collection('members')
        .doc(memberId)
        .collection('conditions')
        .orderBy('createdAt', descending: true)
        .snapshots());
  }

  static Future<void> addOtherRecord({
    required String recordName,
    required String measurement,
    required DateTime recordDate,
  }) async {
    final collection = await getMemberCollection('otherRecords');
    if (collection == null) return;

    await collection.add({
      'recordName': recordName,
      'measurement': measurement,
      'recordDate': Timestamp.fromDate(recordDate),
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  // History fix: add a new document on every edit so all past values
  // are preserved and visible in the history screen.
  static Future<void> updateOtherRecord({
    required String docId,
    required String recordName,
    required String measurement,
    required DateTime recordDate,
  }) async {
    final collection = await getMemberCollection('otherRecords');
    if (collection == null) return;

    await collection.add({
      'recordName': recordName,
      'measurement': measurement,
      'recordDate': Timestamp.fromDate(recordDate),
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  static Future<void> deleteOtherRecord(String docId) async {
    final collection = await getMemberCollection('otherRecords');
    if (collection == null) return;
    await collection.doc(docId).delete();
  }

  /// Deletes ALL history documents for a given other record name.
  static Future<void> deleteAllOtherRecordsByName(String recordName) async {
    final collection = await getMemberCollection('otherRecords');
    if (collection == null) return;
    final snap = await collection.where('recordName', isEqualTo: recordName).get();
    for (final doc in snap.docs) {
      await doc.reference.delete();
    }
  }

  static Stream<QuerySnapshot<Map<String, dynamic>>> getOtherRecords() {
    return _memberStream((memberId) => _userDoc
        .collection('members')
        .doc(memberId)
        .collection('otherRecords')
        .orderBy('recordDate', descending: true)
        .snapshots());
  }

  // =========================================================
  // ================= CHATBOT CONTEXT =======================
  // =========================================================

  static Future<List<Map<String, dynamic>>>
      getActivePrescriptionsForContext() async {
    try {
      final collection = await getMemberCollection('prescriptions');
      if (collection == null) return [];
      final snapshot = await collection.get();
      return snapshot.docs.map((doc) => doc.data()).toList();
    } catch (_) {
      return [];
    }
  }

  static Future<List<Map<String, dynamic>>> getConditionsForContext() async {
    try {
      final collection = await getMemberCollection('conditions');
      if (collection == null) return [];
      final snapshot = await collection.get();
      return snapshot.docs.map((doc) => doc.data()).toList();
    } catch (_) {
      return [];
    }
  }

  static Future<List<Map<String, dynamic>>> getRecentVitalsForContext() async {
    try {
      final List<Map<String, dynamic>> result = [];

      final bodyCollection = await getMemberCollection('bodyVitals');
      if (bodyCollection != null) {
        final snap = await bodyCollection
            .orderBy('recordDate', descending: true)
            .limit(5)
            .get();
        result.addAll(snap.docs.map((d) => d.data()));
      }

      final bloodCollection = await getMemberCollection('bloodRecords');
      if (bloodCollection != null) {
        final snap = await bloodCollection
            .orderBy('recordDate', descending: true)
            .limit(5)
            .get();
        result.addAll(snap.docs.map((d) => d.data()));
      }

      return result;
    } catch (_) {
      return [];
    }
  }

  // =========================================================
  // ================= DASHBOARD ANALYTICS ==================
  // =========================================================

  static Future<Map<String, int>> getWeeklyAdherenceCounts() async {
    try {
      final memberId = await _getActiveMemberId();
      if (memberId == null) return {};

      final last7 = List.generate(7, (i) {
        final d = DateTime.now().subtract(Duration(days: 6 - i));
        return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
      });

      final Map<String, int> takenPerDay = {for (final d in last7) d: 0};

      // Query new adherence_logs collection written by ReminderService.markTaken
      final logsSnap = await _userDoc
          .collection('members')
          .doc(memberId)
          .collection('adherence_logs')
          .where('scheduledDate', whereIn: last7)
          .where('status', isEqualTo: 'taken')
          .get();

      for (final doc in logsSnap.docs) {
        final dateId = doc.data()['scheduledDate'] as String?;
        if (dateId != null && takenPerDay.containsKey(dateId)) {
          takenPerDay[dateId] = (takenPerDay[dateId] ?? 0) + 1;
        }
      }

      return takenPerDay;
    } catch (_) {
      return {};
    }
  }

  static Future<double> getWeeklyAdherenceRate() async {
    try {
      final memberId = await _getActiveMemberId();
      if (memberId == null) return 0.0;

      final last7 = List.generate(7, (i) {
        final d = DateTime.now().subtract(Duration(days: 6 - i));
        return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
      });

      final logsRef = _userDoc
          .collection('members')
          .doc(memberId)
          .collection('adherence_logs');

      // Total scheduled = taken + skipped in last 7 days
      final allSnap = await logsRef
          .where('scheduledDate', whereIn: last7)
          .where('status', whereIn: ['taken', 'skipped'])
          .get();

      if (allSnap.docs.isEmpty) return 0.0;

      final takenCount =
          allSnap.docs.where((d) => d.data()['status'] == 'taken').length;
      return takenCount / allSnap.docs.length;
    } catch (_) {
      return 0.0;
    }
  }

  /// Monthly adherence — last 30 days count of taken doses per day
  static Future<Map<String, int>> getMonthlyAdherenceCounts() async {
    try {
      final memberId = await _getActiveMemberId();
      if (memberId == null) return {};

      final last30 = List.generate(30, (i) {
        final d = DateTime.now().subtract(Duration(days: 29 - i));
        return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
      });

      final Map<String, int> takenPerDay = {for (final d in last30) d: 0};

      // Firestore 'whereIn' supports up to 30 elements — fits exactly
      final logsSnap = await _userDoc
          .collection('members')
          .doc(memberId)
          .collection('adherence_logs')
          .where('scheduledDate', whereIn: last30)
          .where('status', isEqualTo: 'taken')
          .get();

      for (final doc in logsSnap.docs) {
        final dateId = doc.data()['scheduledDate'] as String?;
        if (dateId != null && takenPerDay.containsKey(dateId)) {
          takenPerDay[dateId] = (takenPerDay[dateId] ?? 0) + 1;
        }
      }

      return takenPerDay;
    } catch (_) {
      return {};
    }
  }

  /// Monthly adherence rate — 0.0 to 1.0
  static Future<double> getMonthlyAdherenceRate() async {
    try {
      final memberId = await _getActiveMemberId();
      if (memberId == null) return 0.0;

      final last30 = List.generate(30, (i) {
        final d = DateTime.now().subtract(Duration(days: 29 - i));
        return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
      });

      final logsRef = _userDoc
          .collection('members')
          .doc(memberId)
          .collection('adherence_logs');

      final allSnap = await logsRef
          .where('scheduledDate', whereIn: last30)
          .where('status', whereIn: ['taken', 'skipped'])
          .get();

      if (allSnap.docs.isEmpty) return 0.0;

      final takenCount =
          allSnap.docs.where((d) => d.data()['status'] == 'taken').length;
      return takenCount / allSnap.docs.length;
    } catch (_) {
      return 0.0;
    }
  }

  /// Stream of body vitals for the active member (real-time)
  static Stream<QuerySnapshot<Map<String, dynamic>>> getBodyVitals() {
    return _memberStream((memberId) => _userDoc
        .collection('members')
        .doc(memberId)
        .collection('bodyVitals')
        .orderBy('recordDate', descending: true)
        .limit(10)
        .snapshots());
  }
}

