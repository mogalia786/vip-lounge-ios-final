import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/app_user.dart';

class AppAuthProvider extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  AppUser? _appUser;

  AppUser? get appUser => _appUser;

  AppAuthProvider() {
    _auth.authStateChanges().listen(_onAuthStateChanged);
  }

  Future<void> _onAuthStateChanged(User? firebaseUser) async {
    if (firebaseUser == null) {
      _appUser = null;
      notifyListeners();
      return;
    }

    // Get additional user data from Firestore
    final userDoc = await _firestore.collection('users').doc(firebaseUser.uid).get();
    if (!userDoc.exists) {
      _appUser = null;
      notifyListeners();
      return;
    }

    final userData = userDoc.data()!;
    _appUser = AppUser(
      uid: firebaseUser.uid,
      firstName: userData['firstName'] ?? '',
      lastName: userData['lastName'] ?? '',
      email: firebaseUser.email ?? '',
      role: userData['role'] ?? '',
      phoneNumber: userData['phoneNumber'],
    );
    notifyListeners();
  }

  Future<void> signInWithEmailAndPassword(String email, String password) async {
    try {
      await _auth.signInWithEmailAndPassword(email: email, password: password);
    } catch (e) {
      rethrow;
    }
  }

  Future<void> signOut() async {
    try {
      await _auth.signOut();
      _appUser = null;
      notifyListeners();
    } catch (e) {
      rethrow;
    }
  }
}
