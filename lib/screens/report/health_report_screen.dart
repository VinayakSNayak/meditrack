import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import '../../backend/services/firestore_service.dart';
import '../../backend/services/pdf_service.dart';

class HealthReportScreen extends StatefulWidget {
  const HealthReportScreen({super.key});

  @override
  State<HealthReportScreen> createState() => _HealthReportScreenState();
}

class _HealthReportScreenState extends State<HealthReportScreen> {
  bool _isGenerating = false;
  String? _memberName;
  int? _memberAge;
  String? _memberRelation;

  @override
  void initState() {
    super.initState();
    _loadMemberInfo();
  }

  Future<void> _loadMemberInfo() async {
    final snapshot = await FirestoreService.getActiveMember().first;
    if (snapshot.exists && mounted) {
      final data = snapshot.data() as Map<String, dynamic>;
      setState(() {
        _memberName = data['name'] as String? ?? 'User';
        _memberAge = (data['age'] as num?)?.toInt() ?? 0;
        _memberRelation = data['relation'] as String? ?? 'Self';
      });
    }
  }

  Future<void> _generateAndShare() async {
    if (_memberName == null) return;
    setState(() => _isGenerating = true);

    try {
      final pdfBytes = await PdfService.generateHealthReport(
        memberName: _memberName!,
        memberAge: _memberAge ?? 0,
        memberRelation: _memberRelation ?? 'Self',
      );

      final dir = await getTemporaryDirectory();
      final file = File(
          '${dir.path}/MediTrack_Report_${_memberName!.replaceAll(' ', '_')}.pdf');
      await file.writeAsBytes(pdfBytes);

      await Share.shareXFiles(
        [XFile(file.path)],
        subject: 'MediTrack Health Report – $_memberName',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to generate report: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }

  Future<void> _previewReport() async {
    if (_memberName == null) return;
    setState(() => _isGenerating = true);

    try {
      final pdfBytes = await PdfService.generateHealthReport(
        memberName: _memberName!,
        memberAge: _memberAge ?? 0,
        memberRelation: _memberRelation ?? 'Self',
      );

      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => Scaffold(
              appBar: AppBar(
                title: const Text('Health Report Preview'),
                actions: [
                  IconButton(
                    icon: const Icon(Icons.share),
                    onPressed: _generateAndShare,
                  ),
                ],
              ),
              body: PdfPreview(
                build: (_) async => pdfBytes,
                canChangePageFormat: false,
                canDebug: false,
              ),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to preview report: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        foregroundColor: Theme.of(context).brightness == Brightness.dark
            ? Colors.white
            : Colors.black,
        title: const Text('Health Report',
            style: TextStyle(fontWeight: FontWeight.w600)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF2E7D32), Color(0xFF43A047)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.description_outlined,
                      color: Colors.white, size: 40),
                  const SizedBox(height: 12),
                  const Text(
                    'MediTrack Health Report',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _memberName != null
                        ? 'For: $_memberName  •  Age: $_memberAge'
                        : 'Loading member info...',
                    style: const TextStyle(
                        color: Colors.white70, fontSize: 13),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            const Text('Report Includes:',
                style: TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 14),

            _featureTile(
                Icons.person_outline, 'Patient Profile', Colors.blue),
            _featureTile(
                Icons.medication, 'All Prescriptions', Colors.green),
            _featureTile(
                Icons.monitor_heart_outlined,
                'Health Conditions',
                Colors.orange),
            _featureTile(Icons.bar_chart, 'Recent Vitals & Blood Records',
                Colors.purple),
            _featureTile(Icons.warning_amber_outlined,
                'Medical Disclaimer', Colors.redAccent),

            const SizedBox(height: 32),

            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(26)),
                ),
                onPressed: _isGenerating ? null : _previewReport,
                icon: _isGenerating
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.preview_outlined,
                        color: Colors.white),
                label: Text(
                  _isGenerating ? 'Generating...' : 'Preview Report',
                  style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white),
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 54,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(26)),
                  side: const BorderSide(color: Colors.green, width: 1.5),
                ),
                onPressed: _isGenerating ? null : _generateAndShare,
                icon: const Icon(Icons.share_outlined, color: Colors.green),
                label: const Text('Share Report',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.green)),
              ),
            ),

            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline,
                      color: Colors.orange, size: 18),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'This report is for personal reference only and does not replace professional medical advice. Always consult your doctor.',
                      style: TextStyle(
                          color: Colors.orange,
                          fontSize: 12,
                          height: 1.5),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _featureTile(IconData icon, String label, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 12),
          Text(label,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
          const SizedBox(width: 8),
          const Icon(Icons.check_circle, color: Colors.green, size: 16),
        ],
      ),
    );
  }
}

