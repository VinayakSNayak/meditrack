import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'notification_service.dart';

class FirestoreService {
  static final FirebaseFirestore _firestore =
      FirebaseFirestore.instance;
  static final FirebaseAuth _auth =
      FirebaseAuth.instance;

  static String get uid => _auth.currentUser!.uid;

  static DocumentReference<Map<String, dynamic>> get _userDoc =>
      _firestore.collection('users').doc(uid);

  // =========================================================
  // ================= MEMBER MANAGEMENT =====================
  // =========================================================

  static Future<void> createUserWithSelfMember(String name) async {
    final memberRef = _userDoc.collection('members').doc();

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

  static Future<void> setActiveMember(String memberId) async {
    await _userDoc.update({'activeMemberId': memberId});
  }

  static Stream<String?> getActiveMemberId() {
    return _userDoc.snapshots().map((snapshot) {
      return snapshot.data()?['activeMemberId'] as String?;
    });
  }

  static Future<String?> _getMemberId() async {
    final snapshot = await _userDoc.get();
    return snapshot.data()?['activeMemberId'];
  }

  static Future<CollectionReference<Map<String, dynamic>>?>
  getMemberCollection(String collectionName) async {
    final memberId = await _getMemberId();
    if (memberId == null) return null;

    return _userDoc
        .collection('members')
        .doc(memberId)
        .collection(collectionName);
  }

  static Stream<DocumentSnapshot<Map<String, dynamic>>> getActiveMember() async* {
    final memberId = await _getMemberId();
    if (memberId == null) return;

    yield* _userDoc.collection('members').doc(memberId).snapshots();
  }

  static Stream<DocumentSnapshot<Map<String, dynamic>>> getAccountOwner() {
    return _userDoc
        .collection('members')
        .where('isSelf', isEqualTo: true)
        .limit(1)
        .snapshots()
        .map((query) => query.docs.first);
  }

  static Future<void> updateActiveMemberProfile({
    required String name,
    required int age,
    required String relation,
  }) async {
    final memberId = await _getMemberId();
    if (memberId == null) return;

    await _userDoc.collection('members').doc(memberId).update({
      'name': name,
      'age': age,
      'relation': relation,
    });
  }

  // =========================================================
  // ================= PRESCRIPTIONS =========================
  // =========================================================

  static Future<void> addPrescription({
    required String medicineName,
    required String foodTiming,
    String? dosage,
    required DateTime time,
    String? notes,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final collection =
    await getMemberCollection('prescriptions');
    if (collection == null) return;

    final docRef = collection.doc();

    final notificationId =
    await NotificationService.scheduleDailyNotification(
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
      'startDate':
      startDate != null ? Timestamp.fromDate(startDate) : null,
      'endDate':
      endDate != null ? Timestamp.fromDate(endDate) : null,
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
    final collection =
    await getMemberCollection('prescriptions');
    if (collection == null) return;

    await collection.doc(prescriptionId).update({
      'medicineName': medicineName,
      'foodTiming': foodTiming,
      'dosage': dosage ?? '',
      'time': Timestamp.fromDate(time),
      'notes': notes ?? '',
      'startDate':
      startDate != null ? Timestamp.fromDate(startDate) : null,
      'endDate':
      endDate != null ? Timestamp.fromDate(endDate) : null,
    });
  }

  static Future<void> deletePrescription(
      String prescriptionId, int notificationId) async {
    final collection =
    await getMemberCollection('prescriptions');
    if (collection == null) return;

    await NotificationService.cancelNotification(notificationId);
    await collection.doc(prescriptionId).delete();
  }

  static Stream<QuerySnapshot<Map<String, dynamic>>>
  getPrescriptions() async* {
    final collection =
    await getMemberCollection('prescriptions');
    if (collection == null) return;

    yield* collection
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  static Future<void> markMedicineStatus({
    required String prescriptionId,
    required String status,
  }) async {
    final collection =
    await getMemberCollection('prescriptions');
    if (collection == null) return;

    final today = DateTime.now();
    final dateId =
        "${today.year}-${today.month}-${today.day}";

    await collection
        .doc(prescriptionId)
        .collection('dailyStatus')
        .doc(dateId)
        .set({
      'status': status,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  // =========================================================
  // ================= HEALTH MODULE =========================
  // =========================================================

  static Future<void> addBodyVitalMetric({
    required String type,
    required dynamic value,
    required String unit,
    required DateTime recordDate,
  }) async {
    final collection =
    await getMemberCollection('bodyVitals');
    if (collection == null) return;

    await collection.add({
      'type': type,
      'value': value,
      'unit': unit,
      'recordDate': Timestamp.fromDate(recordDate),
      'recordTime': FieldValue.serverTimestamp(),
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  static Future<void> updateBodyVitalMetric({
    required String docId,
    required String type,
    required dynamic value,
    required String unit,
    required DateTime recordDate,
  }) async {
    final collection =
    await getMemberCollection('bodyVitals');
    if (collection == null) return;

    await collection.add({
      'type': type,
      'value': value,
      'unit': unit,
      'recordDate': Timestamp.fromDate(recordDate),
      'recordTime': FieldValue.serverTimestamp(),
      'isEdited': true,
      'editedFrom': docId,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  static Future<void> deleteBodyVital(String docId) async {
    final collection =
    await getMemberCollection('bodyVitals');
    if (collection == null) return;

    await collection.doc(docId).delete();
  }

  static Stream<QuerySnapshot<Map<String, dynamic>>>
  getBodyVitalMetrics() async* {
    final collection =
    await getMemberCollection('bodyVitals');
    if (collection == null) return;

    yield* collection
        .orderBy('recordDate', descending: true)
        .snapshots();
  }

  static Future<void> addBloodMetric({
    required String type,
    required dynamic value,
    required String unit,
    required DateTime recordDate,
  }) async {
    final collection =
    await getMemberCollection('bloodRecords');
    if (collection == null) return;

    await collection.add({
      'type': type,
      'value': value,
      'unit': unit,
      'recordDate': Timestamp.fromDate(recordDate),
      'recordTime': FieldValue.serverTimestamp(),
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  static Future<void> updateBloodMetric({
    required String docId,
    required String type,
    required dynamic value,
    required String unit,
    required DateTime recordDate,
  }) async {
    final collection =
    await getMemberCollection('bloodRecords');
    if (collection == null) return;

    await collection.add({
      'type': type,
      'value': value,
      'unit': unit,
      'recordDate': Timestamp.fromDate(recordDate),
      'recordTime': FieldValue.serverTimestamp(),
      'isEdited': true,
      'editedFrom': docId,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  static Future<void> deleteBloodMetric(String docId) async {
    final collection =
    await getMemberCollection('bloodRecords');
    if (collection == null) return;

    await collection.doc(docId).delete();
  }

  static Stream<QuerySnapshot<Map<String, dynamic>>>
  getBloodMetrics() async* {
    final collection =
    await getMemberCollection('bloodRecords');
    if (collection == null) return;

    yield* collection
        .orderBy('recordDate', descending: true)
        .snapshots();
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
    final collection =
    await getMemberCollection('conditions');
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
    final collection =
    await getMemberCollection('conditions');
    if (collection == null) return;

    await collection.doc(docId).update({
      'conditionName': conditionName,
      'diagnosedDate': Timestamp.fromDate(diagnosedDate),
      'status': status,
      'hasMedication': hasMedication,
      'medication': medication,
      'doctorName': doctorName,
      'notes': notes,
    });
  }

  static Future<void> deleteCondition(String docId) async {
    final collection =
    await getMemberCollection('conditions');
    if (collection == null) return;

    await collection.doc(docId).delete();
  }

  static Future<void> addOtherRecord({
    required String recordName,
    required String measurement,
    required DateTime recordDate,
  }) async {
    final collection =
    await getMemberCollection('otherRecords');
    if (collection == null) return;

    await collection.add({
      'recordName': recordName,
      'measurement': measurement,
      'recordDate': Timestamp.fromDate(recordDate),
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  static Future<void> updateOtherRecord({
    required String docId,
    required String recordName,
    required String measurement,
    required DateTime recordDate,
  }) async {
    final collection =
    await getMemberCollection('otherRecords');
    if (collection == null) return;

    await collection.doc(docId).update({
      'recordName': recordName,
      'measurement': measurement,
      'recordDate': Timestamp.fromDate(recordDate),
    });
  }

  static Future<void> deleteOtherRecord(String docId) async {
    final collection =
    await getMemberCollection('otherRecords');
    if (collection == null) return;

    await collection.doc(docId).delete();
  }
}