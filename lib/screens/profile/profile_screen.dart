import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'dart:typed_data';
import '../../backend/services/firestore_service.dart';
import '../../backend/services/pdf_service.dart';
import '../family/add_family_screen.dart';
import 'edit_profile_screen.dart';
import 'settings_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  // ──────────────────────────────────────────────
  // REPORT GENERATION HELPERS
  // ──────────────────────────────────────────────

  Future<Map<String, dynamic>?> _getActiveMemberData() async {
    final snap = await FirestoreService.getActiveMember().first;
    if (!snap.exists) return null;
    final data = snap.data() as Map<String, dynamic>;
    final memberId = await FirestoreService.getActiveMemberIdOnce();
    return {
      'name': data['name'] as String? ?? 'User',
      'age': (data['age'] as num?)?.toInt() ?? 0,
      'relation': data['relation'] as String? ?? 'Self',
      'memberId': memberId ?? '',
    };
  }

  Future<void> _generateReport(String type) async {
    final info = await _getActiveMemberData();
    if (info == null || !mounted) return;

    final memberName = info['name'] as String;
    final memberAge = info['age'] as int;
    final memberRelation = info['relation'] as String;
    final memberId = info['memberId'] as String;

    if (!mounted) return;
    Navigator.pop(context); // close dialog

    // Show loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const AlertDialog(
        content: Row(children: [
          CircularProgressIndicator(color: Colors.green),
          SizedBox(width: 16),
          Text('Generating report…'),
        ]),
      ),
    );

    try {
      late final Uint8List pdfBytes;

      if (type == 'prescription') {
        pdfBytes = await PdfService.generatePrescriptionReport(
          memberId: memberId,
          memberName: memberName,
          memberAge: memberAge,
          memberRelation: memberRelation,
        );
      } else if (type == 'health') {
        pdfBytes = await PdfService.generateHealthRecordsReport(
          memberId: memberId,
          memberName: memberName,
          memberAge: memberAge,
          memberRelation: memberRelation,
        );
      } else {
        pdfBytes = await PdfService.generateHealthReport(
          memberName: memberName,
          memberAge: memberAge,
          memberRelation: memberRelation,
          memberId: memberId,
        );
      }

      if (!mounted) return;
      Navigator.pop(context); // close loading

      // Preview PDF
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => Scaffold(
            appBar: AppBar(
              title: Text('$memberName – Report'),
              actions: [
                IconButton(
                  icon: const Icon(Icons.share),
                  onPressed: () async {
                    final dir = await getTemporaryDirectory();
                    final file = File(
                        '${dir.path}/MediTrack_${type}_${memberName.replaceAll(' ', '_')}.pdf');
                    await file.writeAsBytes(pdfBytes);
                    await Share.shareXFiles([XFile(file.path)],
                        subject: 'MediTrack Report – $memberName');
                  },
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
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // close loading
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Failed to generate report: $e'),
              backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  void _showReportDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(children: [
          const Icon(Icons.description_outlined, color: Colors.green),
          const SizedBox(width: 10),
          Text(tr('generate_report')),
        ]),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _reportOption(
              icon: Icons.medication_outlined,
              color: Colors.blue,
              title: tr('report_prescription'),
              subtitle: tr('report_prescription_subtitle'),
              type: 'prescription',
            ),
            const SizedBox(height: 10),
            _reportOption(
              icon: Icons.monitor_heart_outlined,
              color: Colors.orange,
              title: tr('report_health'),
              subtitle: tr('report_health_subtitle'),
              type: 'health',
            ),
            const SizedBox(height: 10),
            _reportOption(
              icon: Icons.summarize_outlined,
              color: Colors.green,
              title: tr('report_combined'),
              subtitle: tr('report_combined_subtitle'),
              type: 'combined',
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(tr('cancel')),
          ),
        ],
      ),
    );
  }

  Widget _reportOption({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required String type,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => _generateReport(type),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 13)),
                  Text(subtitle,
                      style:
                          TextStyle(fontSize: 11, color: Colors.grey[600])),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios, size: 14, color: color),
          ],
        ),
      ),
    );
  }

  // ──────────────────────────────────────────────
  // DELETE MEMBER HELPERS
  // ──────────────────────────────────────────────

  void _showDeleteConfirmation(
      BuildContext ctx, String memberId, String memberName) {
    showDialog(
      context: ctx,
      builder: (dlgCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(tr('remove_member')),
        content: Text(tr('remove_member_confirm', namedArgs: {'name': memberName})),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dlgCtx),
            child: Text(tr('cancel')),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(dlgCtx);
              try {
                await FirestoreService.deleteMember(memberId);
                if (ctx.mounted) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    SnackBar(
                        content: Text(
                            '"$memberName" ${tr('removed_successfully')}'),
                        backgroundColor: Colors.green),
                  );
                }
              } catch (e) {
                if (ctx.mounted) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    SnackBar(
                        content: Text('${tr('failed_remove_member')} $e'),
                        backgroundColor: Colors.redAccent),
                  );
                }
              }
            },
            child: Text(tr('delete'),
                style: const TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
  }

  // ──────────────────────────────────────────────
  // BUILD
  // ──────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: Text(tr('profile')),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(
                    builder: (_) => const EditProfileScreen())),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            _profileCard(user),
            const SizedBox(height: 20),
            _familySection(context),
            const SizedBox(height: 20),
            _quickActionsCard(context),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  // ── Account info card ──
  Widget _profileCard(User? user) {
    return StreamBuilder(
      stream: FirestoreService.getActiveMember(),
      builder: (context, snapshot) {
        String name = 'User';
        String age = '';
        String relation = '';

        if (snapshot.hasData && snapshot.data!.exists) {
          final data = snapshot.data!.data() as Map<String, dynamic>;
          name = data['name'] as String? ?? 'User';
          age = data['age']?.toString() ?? '';
          relation = data['relation'] as String? ?? '';
        }

        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 14,
                  offset: const Offset(0, 6))
            ],
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 36,
                backgroundColor: Colors.green.withValues(alpha: 0.15),
                child: Text(
                  name.isNotEmpty ? name[0].toUpperCase() : '?',
                  style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      color: Colors.green),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name,
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.w600)),
                    if (user?.email != null)
                      Text(user!.email!,
                          style: const TextStyle(
                              color: Colors.grey, fontSize: 12)),
                    if (relation.isNotEmpty)
                      Text('Relation: $relation',
                          style: const TextStyle(
                              color: Colors.grey, fontSize: 12)),
                    if (age.isNotEmpty)
                      Text('Age: $age',
                          style: const TextStyle(
                              color: Colors.grey, fontSize: 12)),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ── Family members card ──
  Widget _familySection(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 14,
              offset: const Offset(0, 6))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(tr('family_members'),
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w600)),
              TextButton.icon(
                onPressed: () => Navigator.push(context,
                    MaterialPageRoute(
                        builder: (_) => const AddFamilyScreen())),
                icon: const Icon(Icons.add, size: 16),
                label: Text(tr('add_family_member')),
              ),
            ],
          ),
          const SizedBox(height: 8),
          StreamBuilder(
            stream: FirestoreService.getMembers(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const SizedBox(
                    height: 40,
                    child: Center(
                        child:
                            CircularProgressIndicator(strokeWidth: 2)));
              }
              final members = snapshot.data!.docs;
              return StreamBuilder<String?>(
                stream: FirestoreService.getActiveMemberId(),
                builder: (ctx, activeSnap) {
                  final activeId = activeSnap.data;
                  return Column(
                    children: members.map((m) {
                      final data = m.data();
                      final isActive = m.id == activeId;
                      final memberName =
                          data['name'] as String? ?? 'Unknown';
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: CircleAvatar(
                          backgroundColor: isActive
                              ? Colors.green.withValues(alpha: 0.15)
                              : Colors.grey.withValues(alpha: 0.1),
                          child: Icon(Icons.person,
                              color: isActive
                                  ? Colors.green
                                  : Colors.grey),
                        ),
                        title: Text(memberName,
                            style: TextStyle(
                                fontWeight: isActive
                                    ? FontWeight.w600
                                    : FontWeight.normal)),
                        subtitle:
                            Text(data['relation'] as String? ?? ''),
                        trailing: isActive
                            ? const Chip(
                                label: Text('Active',
                                    style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.white)),
                                backgroundColor: Colors.green,
                                padding: EdgeInsets.zero,
                              )
                            : PopupMenuButton<String>(
                                icon: const Icon(Icons.more_vert,
                                    size: 20, color: Colors.grey),
                                onSelected: (value) {
                                  if (value == 'activate') {
                                    FirestoreService.setActiveMember(
                                        m.id);
                                  } else if (value == 'delete') {
                                    _showDeleteConfirmation(
                                        context, m.id, memberName);
                                  }
                                },
                                itemBuilder: (_) => const [
                                  PopupMenuItem(
                                    value: 'activate',
                                    child: Row(children: [
                                      Icon(
                                          Icons.check_circle_outline,
                                          size: 18,
                                          color: Colors.green),
                                      SizedBox(width: 8),
                                      Text('Set Active'),
                                    ]),
                                  ),
                                  PopupMenuItem(
                                    value: 'delete',
                                    child: Row(children: [
                                      Icon(Icons.delete_outline,
                                          size: 18,
                                          color: Colors.redAccent),
                                      SizedBox(width: 8),
                                      Text('Delete Member',
                                          style: TextStyle(
                                              color:
                                                  Colors.redAccent)),
                                    ]),
                                  ),
                                ],
                              ),
                        onTap: () =>
                            FirestoreService.setActiveMember(m.id),
                      );
                    }).toList(),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }

  // ── Quick actions card: Generate Report + Settings ──
  Widget _quickActionsCard(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 14,
              offset: const Offset(0, 6))
        ],
      ),
      child: Column(
        children: [
          // Generate Health Report
          ListTile(
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.description_outlined,
                  color: Colors.green, size: 20),
            ),
            title: Text(tr('generate_report'),
                style: const TextStyle(fontWeight: FontWeight.w500)),
            subtitle: Text(tr('generate_report_subtitle'),
                style: const TextStyle(fontSize: 12)),
            trailing: const Icon(Icons.arrow_forward_ios,
                size: 14, color: Colors.grey),
            onTap: _showReportDialog,
          ),
          const Divider(height: 1, indent: 56),
          // Settings
          ListTile(
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.blueGrey.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.settings_outlined,
                  color: Colors.blueGrey, size: 20),
            ),
            title: Text(tr('settings'),
                style: const TextStyle(fontWeight: FontWeight.w500)),
            subtitle: Text(tr('settings_subtitle'),
                style: const TextStyle(fontSize: 12)),
            trailing: const Icon(Icons.arrow_forward_ios,
                size: 14, color: Colors.grey),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => const SettingsScreen()),
            ),
          ),
        ],
      ),
    );
  }
}

