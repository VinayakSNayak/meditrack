import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'firestore_service.dart';

enum ReportType { prescription, healthRecords, combined }

/// Internal helper to pass section data to the PDF builder.
class _SectionData {
  final String title;
  final String icon;
  final List<pw.Widget> rows;
  const _SectionData({
    required this.title,
    required this.icon,
    required this.rows,
  });
}

class PdfService {
  static final _firestore = FirebaseFirestore.instance;

  static String get _uid => FirebaseAuth.instance.currentUser?.uid ?? '';

  // ========================= TARGETED DATA FETCHERS =========================

  static Future<List<Map<String, dynamic>>> _getPrescriptionsForMember(
      String memberId) async {
    try {
      // Sort by visitDate descending so newest prescriptions appear first.
      // Fresh fetch from Firestore ensures deleted prescriptions are excluded.
      final snap = await _firestore
          .collection('users')
          .doc(_uid)
          .collection('members')
          .doc(memberId)
          .collection('prescriptions')
          .orderBy('visitDate', descending: true)
          .get();

      final result = <Map<String, dynamic>>[];
      for (final doc in snap.docs) {
        final data = Map<String, dynamic>.from(doc.data());
        data['prescriptionId'] = doc.id;

        // Fetch medicines for this prescription
        try {
          final medsSnap = await _firestore
              .collection('users')
              .doc(_uid)
              .collection('members')
              .doc(memberId)
              .collection('prescriptions')
              .doc(doc.id)
              .collection('medicines')
              .orderBy('createdAt')
              .get();
          data['medicines'] =
              medsSnap.docs.map((m) => m.data()).toList();
        } catch (_) {
          data['medicines'] = <Map<String, dynamic>>[];
        }

        result.add(data);
      }
      return result;
    } catch (_) {
      return [];
    }
  }

  static Future<List<Map<String, dynamic>>> _getConditionsForMember(
      String memberId) async {
    try {
      final snap = await _firestore
          .collection('users')
          .doc(_uid)
          .collection('members')
          .doc(memberId)
          .collection('conditions')
          .get();
      return snap.docs.map((d) => d.data()).toList();
    } catch (_) {
      return [];
    }
  }

  static Future<List<Map<String, dynamic>>> _getVitalsForMember(
      String memberId) async {
    try {
      final List<Map<String, dynamic>> result = [];
      final memberRef = _firestore
          .collection('users')
          .doc(_uid)
          .collection('members')
          .doc(memberId);

      // Order by createdAt descending — matches the app's own query logic.
      // This ensures newly edited values appear first, not old recordDate values.
      final bodySnap = await memberRef
          .collection('bodyVitals')
          .orderBy('createdAt', descending: true)
          .get();
      // Deduplicate: keep only the latest entry per type
      final seenBodyTypes = <String>{};
      for (final d in bodySnap.docs) {
        final type = d.data()['type'] as String? ?? '';
        if (seenBodyTypes.add(type)) result.add(d.data());
      }

      final bloodSnap = await memberRef
          .collection('bloodRecords')
          .orderBy('createdAt', descending: true)
          .get();
      final seenBloodTypes = <String>{};
      for (final d in bloodSnap.docs) {
        final type = d.data()['type'] as String? ?? '';
        if (seenBloodTypes.add(type)) result.add(d.data());
      }

      // Also include other records if they exist
      try {
        final otherSnap = await memberRef
            .collection('otherRecords')
            .orderBy('createdAt', descending: true)
            .get();
        final seenOtherTypes = <String>{};
        for (final d in otherSnap.docs) {
          final type = d.data()['type'] as String? ?? '';
          if (seenOtherTypes.add(type)) result.add(d.data());
        }
      } catch (_) {
        // otherRecords collection may not exist — ignore
      }

      return result;
    } catch (_) {
      return [];
    }
  }

  // ========================= PUBLIC REPORT GENERATORS =========================

  /// Generate a prescription-only PDF for the specified member.
  static Future<Uint8List> generatePrescriptionReport({
    required String memberId,
    required String memberName,
    required int memberAge,
    required String memberRelation,
  }) async {
    final prescriptions = await _getPrescriptionsForMember(memberId);
    return _buildPdf(
      memberName: memberName,
      memberAge: memberAge,
      memberRelation: memberRelation,
      reportTitle: 'Prescription Report',
      sections: [
        _SectionData(
          title: 'Prescriptions',
          icon: '💊',
          rows: prescriptions.isEmpty
              ? [_noDataRow('No prescriptions recorded')]
              : prescriptions.map(_prescriptionRow).toList(),
        ),
      ],
    );
  }

  /// Generate a health-records-only PDF for the specified member.
  static Future<Uint8List> generateHealthRecordsReport({
    required String memberId,
    required String memberName,
    required int memberAge,
    required String memberRelation,
  }) async {
    final conditions = await _getConditionsForMember(memberId);
    final vitals = await _getVitalsForMember(memberId);
    return _buildPdf(
      memberName: memberName,
      memberAge: memberAge,
      memberRelation: memberRelation,
      reportTitle: 'Health Records Report',
      sections: [
        _SectionData(
          title: 'Existing Conditions',
          icon: '🏥',
          rows: conditions.isEmpty
              ? [_noDataRow('No conditions recorded')]
              : conditions.map(_conditionRow).toList(),
        ),
        _SectionData(
          title: 'Recent Health Vitals',
          icon: '📊',
          rows: vitals.isEmpty
              ? [_noDataRow('No vitals recorded')]
              : vitals.map(_vitalRow).toList(),
        ),
      ],
    );
  }

  /// Generate a complete health report PDF for the active member.
  static Future<Uint8List> generateHealthReport({
    required String memberName,
    required int memberAge,
    required String memberRelation,
    String? memberId,
  }) async {
    List<Map<String, dynamic>> prescriptions;
    List<Map<String, dynamic>> conditions;
    List<Map<String, dynamic>> vitals;

    if (memberId != null) {
      final results = await Future.wait([
        _getPrescriptionsForMember(memberId),
        _getConditionsForMember(memberId),
        _getVitalsForMember(memberId),
      ]);
      prescriptions = results[0];
      conditions = results[1];
      vitals = results[2];
    } else {
      // Fallback to active member context
      final results = await Future.wait([
        FirestoreService.getActivePrescriptionsForContext(),
        FirestoreService.getConditionsForContext(),
        FirestoreService.getRecentVitalsForContext(),
      ]);
      prescriptions = results[0];
      conditions = results[1];
      vitals = results[2];
    }

    return _buildPdf(
      memberName: memberName,
      memberAge: memberAge,
      memberRelation: memberRelation,
      reportTitle: 'Combined Health Report',
      sections: [
        _SectionData(
          title: 'Active Prescriptions',
          icon: '💊',
          rows: prescriptions.isEmpty
              ? [_noDataRow('No prescriptions recorded')]
              : prescriptions.map(_prescriptionRow).toList(),
        ),
        _SectionData(
          title: 'Existing Conditions',
          icon: '🏥',
          rows: conditions.isEmpty
              ? [_noDataRow('No conditions recorded')]
              : conditions.map(_conditionRow).toList(),
        ),
        _SectionData(
          title: 'Recent Health Vitals',
          icon: '📊',
          rows: vitals.isEmpty
              ? [_noDataRow('No vitals recorded')]
              : vitals.map(_vitalRow).toList(),
        ),
      ],
    );
  }

  // ========================= INTERNAL PDF BUILDER =========================

  static Future<Uint8List> _buildPdf({
    required String memberName,
    required int memberAge,
    required String memberRelation,
    required String reportTitle,
    required List<_SectionData> sections,
  }) async {
    final pdf = pw.Document();
    final generatedDate =
        DateFormat('dd MMMM yyyy, hh:mm a').format(DateTime.now());

    final List<pw.Widget> body = [
      _buildMemberSection(memberName, memberAge, memberRelation),
    ];
    for (final section in sections) {
      body.add(pw.SizedBox(height: 20));
      body.add(_buildSection(
        title: section.title,
        icon: section.icon,
        content: section.rows,
      ));
    }
    body.add(pw.SizedBox(height: 24));
    body.add(_buildDisclaimer());

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        header: (context) =>
            _buildHeader(memberName, generatedDate, reportTitle),
        footer: (context) => _buildFooter(context),
        build: (context) => body,
      ),
    );

    return pdf.save();
  }

  // ========================= HEADER / FOOTER =========================

  static pw.Widget _buildHeader(
      String memberName, String date, String reportTitle) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(bottom: 12),
      decoration: const pw.BoxDecoration(
        border: pw.Border(
          bottom: pw.BorderSide(color: PdfColors.green700, width: 2),
        ),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'MediTrack — $reportTitle',
                style: pw.TextStyle(
                  fontSize: 18,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.green800,
                ),
              ),
              pw.Text(
                'For: $memberName',
                style: pw.TextStyle(
                    fontSize: 13, color: PdfColors.grey700),
              ),
            ],
          ),
          pw.Text(
            'Generated: $date',
            style: pw.TextStyle(fontSize: 10, color: PdfColors.grey600),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildFooter(pw.Context context) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(top: 8),
      decoration: const pw.BoxDecoration(
        border: pw.Border(
          top: pw.BorderSide(color: PdfColors.grey300),
        ),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            '⚠️ This report is for personal reference only. Consult a doctor for medical advice.',
            style: pw.TextStyle(fontSize: 8, color: PdfColors.grey500),
          ),
          pw.Text(
            'Page ${context.pageNumber} of ${context.pagesCount}',
            style: pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
          ),
        ],
      ),
    );
  }

  // ========================= SECTIONS =========================

  static pw.Widget _buildMemberSection(
      String name, int age, String relation) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(
        color: PdfColors.green50,
        borderRadius: pw.BorderRadius.circular(8),
        border: pw.Border.all(color: PdfColors.green200),
      ),
      child: pw.Row(
        children: [
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('Patient Profile',
                    style: pw.TextStyle(
                        fontSize: 14,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.green800)),
                pw.SizedBox(height: 8),
                pw.Text('Name: $name',
                    style: const pw.TextStyle(fontSize: 12)),
                pw.Text('Age: $age years',
                    style: const pw.TextStyle(fontSize: 12)),
                pw.Text('Relation: $relation',
                    style: const pw.TextStyle(fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildSection({
    required String title,
    required String icon,
    required List<pw.Widget> content,
  }) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Container(
          padding:
              const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: const pw.BoxDecoration(
            color: PdfColors.green700,
            borderRadius:
                pw.BorderRadius.only(topLeft: pw.Radius.circular(6), topRight: pw.Radius.circular(6)),
          ),
          child: pw.Text(
            '$icon  $title',
            style: pw.TextStyle(
              fontSize: 13,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.white,
            ),
          ),
        ),
        pw.Container(
          padding: const pw.EdgeInsets.all(12),
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: PdfColors.green200),
            borderRadius: const pw.BorderRadius.only(
              bottomLeft: pw.Radius.circular(6),
              bottomRight: pw.Radius.circular(6),
            ),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: content,
          ),
        ),
      ],
    );
  }

  // ========================= ROW BUILDERS =========================

  /// Builds a grouped prescription block: header (name / hospital / date)
  /// followed by a sub-list of medicines belonging to this prescription.
  static pw.Widget _prescriptionRow(Map<String, dynamic> p) {
    final name =
        p['name'] as String? ?? p['medicineName'] as String? ?? 'Unknown';
    final hospital = p['hospitalName'] as String? ?? '';
    final diagnosis = p['diagnosis'] as String? ?? '';
    final visitTs = p['visitDate'] as Timestamp?;
    final visitStr = visitTs != null
        ? DateFormat('dd MMM yyyy').format(visitTs.toDate())
        : '';

    final medicines =
        (p['medicines'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? [];

    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 10),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.green100),
        borderRadius: pw.BorderRadius.circular(5),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          // ── Prescription header ──────────────────────────────────
          pw.Container(
            padding:
                const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: const pw.BoxDecoration(
              color: PdfColors.green50,
              borderRadius: pw.BorderRadius.only(
                topLeft: pw.Radius.circular(5),
                topRight: pw.Radius.circular(5),
              ),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  name,
                  style: pw.TextStyle(
                      fontSize: 11, fontWeight: pw.FontWeight.bold),
                ),
                pw.SizedBox(height: 3),
                pw.Row(
                  children: [
                    if (hospital.isNotEmpty) ...[
                      pw.Text('Hospital: $hospital',
                          style: const pw.TextStyle(
                              fontSize: 9, color: PdfColors.grey700)),
                      pw.SizedBox(width: 12),
                    ],
                    if (diagnosis.isNotEmpty) ...[
                      pw.Text('Diagnosis: $diagnosis',
                          style: const pw.TextStyle(
                              fontSize: 9, color: PdfColors.grey700)),
                      pw.SizedBox(width: 12),
                    ],
                    if (visitStr.isNotEmpty)
                      pw.Text('Visit: $visitStr',
                          style: const pw.TextStyle(
                              fontSize: 9, color: PdfColors.grey600)),
                  ],
                ),
              ],
            ),
          ),
          // ── Medicines list ───────────────────────────────────────
          pw.Padding(
            padding: const pw.EdgeInsets.all(8),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: medicines.isEmpty
                  ? [
                      pw.Text('  No medicines recorded',
                          style: pw.TextStyle(
                              fontSize: 9,
                              color: PdfColors.grey500,
                              fontStyle: pw.FontStyle.italic)),
                    ]
                  : medicines.map(_medicineSubRow).toList(),
            ),
          ),
        ],
      ),
    );
  }

  /// One line per medicine inside a prescription block.
  static pw.Widget _medicineSubRow(Map<String, dynamic> m) {
    final name = m['medicineName'] as String? ?? 'Unknown';
    final dosage = m['dosage'] as String? ?? '';
    final frequency = m['frequency'] as String? ?? '';
    final foodTiming = m['foodTiming'] as String? ?? '';

    final details = [
      if (dosage.isNotEmpty) dosage,
      if (frequency.isNotEmpty) frequency,
      if (foodTiming.isNotEmpty) foodTiming,
    ].join(' • ');

    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        children: [
          pw.Text('  ◦ ',
              style: const pw.TextStyle(fontSize: 10, color: PdfColors.green700)),
          pw.Expanded(
            child: pw.Text(
              name + (details.isNotEmpty ? '   ($details)' : ''),
              style: const pw.TextStyle(fontSize: 10),
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _conditionRow(Map<String, dynamic> c) {
    final name = c['conditionName'] as String? ?? 'Unknown';
    final status = c['status'] as String? ?? '';
    final medication = c['medication'] as String? ?? '';

    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 4),
      child: pw.Row(
        children: [
          pw.Expanded(
              flex: 3,
              child: pw.Text('• $name',
                  style: pw.TextStyle(
                      fontWeight: pw.FontWeight.bold, fontSize: 11))),
          pw.Expanded(
              flex: 2,
              child: pw.Text('Status: $status',
                  style: const pw.TextStyle(fontSize: 10))),
          pw.Expanded(
              flex: 3,
              child: pw.Text(
                  medication.isNotEmpty ? 'Medication: $medication' : '',
                  style: const pw.TextStyle(fontSize: 10))),
        ],
      ),
    );
  }

  static pw.Widget _vitalRow(Map<String, dynamic> v) {
    final type = v['type'] as String? ?? 'Unknown';
    final value = v['value']?.toString() ?? '';
    final unit = v['unit'] as String? ?? '';
    // Prefer recordDate; fall back to createdAt (used by history-aware records)
    final dateStamp =
        (v['recordDate'] ?? v['createdAt']) as Timestamp?;
    final dateStr = dateStamp != null
        ? DateFormat('dd MMM yyyy').format(dateStamp.toDate())
        : '';

    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 4),
      child: pw.Row(
        children: [
          pw.Expanded(
              flex: 3,
              child: pw.Text('• $type',
                  style: pw.TextStyle(
                      fontWeight: pw.FontWeight.bold, fontSize: 11))),
          pw.Expanded(
              flex: 2,
              child: pw.Text('$value $unit',
                  style: const pw.TextStyle(fontSize: 10))),
          pw.Expanded(
              flex: 2,
              child: pw.Text(dateStr,
                  style: const pw.TextStyle(fontSize: 10))),
        ],
      ),
    );
  }

  static pw.Widget _noDataRow(String message) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 4),
      child: pw.Text(message,
          style: pw.TextStyle(fontSize: 10, color: PdfColors.grey600,
          fontStyle: pw.FontStyle.italic)),
    );
  }

  static pw.Widget _buildDisclaimer() {
    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: PdfColors.orange50,
        borderRadius: pw.BorderRadius.circular(6),
        border: pw.Border.all(color: PdfColors.orange200),
      ),
      child: pw.Text(
        '⚠️ Medical Disclaimer: This report is generated from self-reported data in the MediTrack app. It is intended for personal reference and should NOT replace professional medical advice, diagnosis, or treatment. Always consult a qualified healthcare professional.',
        style: pw.TextStyle(
            fontSize: 9, color: PdfColors.orange900,
            fontStyle: pw.FontStyle.italic),
      ),
    );
  }
}

