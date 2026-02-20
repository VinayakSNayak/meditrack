import 'package:flutter/material.dart';
import '../backend/services/firestore_service.dart';

class MemberSelector extends StatelessWidget {
  const MemberSelector({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: FirestoreService.getMembers(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SizedBox();
        }

        final members = snapshot.data!.docs;

        return StreamBuilder<String?>(
          stream: FirestoreService.getActiveMemberId(),
          builder: (context, activeSnapshot) {
            final activeId = activeSnapshot.data;

            return DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: activeId,
                icon: const Icon(Icons.keyboard_arrow_down),
                items: members.map((doc) {
                  final data =
                  doc.data() as Map<String, dynamic>;

                  return DropdownMenuItem<String>(
                    value: doc.id,
                    child: Text(data['name']),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    FirestoreService.setActiveMember(
                        value);
                  }
                },
              ),
            );
          },
        );
      },
    );
  }
}
