import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../backend/services/firestore_service.dart';

/// Global provider that holds the currently selected family member.
/// All screens that show per-member data must listen to this provider.
/// When activeMemberId changes, notifyListeners() causes full rebuild.
class MemberProvider extends ChangeNotifier {
  String? _activeMemberId;
  StreamSubscription? _subscription;

  String? get activeMemberId => _activeMemberId;

  MemberProvider() {
    _listenToActiveMember();
  }

  void _listenToActiveMember() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    _subscription?.cancel();
    _subscription = FirestoreService.getActiveMemberId().listen((id) {
      if (id != _activeMemberId) {
        _activeMemberId = id;
        notifyListeners(); // triggers rebuild in all Consumer<MemberProvider>
      }
    });
  }

  /// Call this after login to start listening
  void init() => _listenToActiveMember();

  /// Call this after logout to stop listening
  void reset() {
    _subscription?.cancel();
    _activeMemberId = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}


