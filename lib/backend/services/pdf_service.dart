import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'firestore_service.dart';

class PdfService {
  /// Generate a complete health report PDF for the active member.
  static Future<Uint8List> generateHealthReport({
    required String memberName,
    required int memberAge,
    required String memberRelation,
  }) async {
    final pdf = pw.Document();

    // Fetch all data in parallel
    final results = await Future.wait([
      FirestoreService.getActivePrescriptionsForContext(),
      FirestoreService.getConditionsForContext(),
      FirestoreService.getRecentVitalsForContext(),
    ]);

    final prescriptions = results[0];
    final conditions = results[1];
    final vitals = results[2];

    final generatedDate =
        DateFormat('dd MMMM yyyy, hh:mm a').format(DateTime.now());

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        header: (context) => _buildHeader(memberName, generatedDate),
        footer: (context) => _buildFooter(context),
        build: (context) => [
          _buildMemberSection(memberName, memberAge, memberRelation),
          pw.SizedBox(height: 20),
          _buildSection(
            title: 'Active Prescriptions',
            icon: '💊',
            content: prescriptions.isEmpty
                ? [_noDataRow('No prescriptions recorded')]
                : prescriptions.map((p) => _prescriptionRow(p)).toList(),
          ),
          pw.SizedBox(height: 20),
          _buildSection(
            title: 'Existing Conditions',
            icon: '🏥',
            content: conditions.isEmpty
                ? [_noDataRow('No conditions recorded')]
                : conditions.map((c) => _conditionRow(c)).toList(),
          ),
          pw.SizedBox(height: 20),
          _buildSection(
            title: 'Recent Health Vitals',
            icon: '📊',
            content: vitals.isEmpty
                ? [_noDataRow('No vitals recorded')]
                : vitals.map((v) => _vitalRow(v)).toList(),
          ),
          pw.SizedBox(height: 24),
          _buildDisclaimer(),
        ],
      ),
    );

    return pdf.save();
  }

  // ========================= HEADER / FOOTER =========================

  static pw.Widget _buildHeader(String memberName, String date) {
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
                'MediTrack Health Report',
                style: pw.TextStyle(
                  fontSize: 20,
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

  static pw.Widget _prescriptionRow(Map<String, dynamic> p) {
    final name = p['medicineName'] as String? ?? 'Unknown';
    final dosage = p['dosage'] as String? ?? '';
    final timing = p['foodTiming'] as String? ?? '';
    final timeStamp = p['time'] as Timestamp?;
    final timeStr = timeStamp != null
        ? DateFormat('hh:mm a').format(timeStamp.toDate())
        : '';

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
              child: pw.Text(dosage, style: const pw.TextStyle(fontSize: 10))),
          pw.Expanded(
              flex: 2,
              child: pw.Text(timing,
                  style: const pw.TextStyle(fontSize: 10))),
          pw.Expanded(
              flex: 2,
              child: pw.Text(timeStr,
                  style: const pw.TextStyle(fontSize: 10))),
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
    final dateStamp = v['recordDate'] as Timestamp?;
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

