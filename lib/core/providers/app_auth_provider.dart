import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/app_user.dart';

class AppAuthProvider extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  AppUser? _appUser;
  Map<String, dynamic>? _ministerData; // Store minister data

  AppUser? get appUser => _appUser;
  Map<String, dynamic>? get ministerData => _ministerData; // Expose minister data
  List<Map<String, dynamic>> get appointments => []; // Add a getter for appointments (dummy placeholder, replace with real logic as needed)

  AppAuthProvider() {
    _auth.authStateChanges().listen((User? user) async {
      if (user != null) {
        await _fetchUserData(user.uid);
      } else {
        _appUser = null;
        _ministerData = null;
        notifyListeners();
      }
    });
  }

  Future<void> _fetchUserData(String uid) async {
    try {
      print('Fetching user data for uid: $uid'); // Debug print
      final doc = await _firestore.collection('users').doc(uid).get();
      
      if (doc.exists) {
        final data = doc.data() ?? {};
        print('Raw user data from Firestore: $data'); // Debug print

        // Get the user's email from Firebase Auth
        final firebaseUser = _auth.currentUser;
        final email = firebaseUser?.email ?? data['email'] ?? '';
        print('User email: $email'); // Debug print

        // Store minister data if role is minister
        if (data['role'] == 'minister') {
          _ministerData = {
            'uid': uid,
            'firstName': data['firstName'] ?? '',
            'lastName': data['lastName'] ?? '',
            'email': email,
            'phoneNumber': data['phoneNumber'],
            'role': data['role'],
          };
          print('Stored minister data: $_ministerData'); // Debug print
        } else {
          _ministerData = null;
        }

        _appUser = AppUser(
          uid: uid,
          role: data['role'] ?? '',
          firstName: data['firstName'] ?? '',
          lastName: data['lastName'] ?? '',
          email: email,
          phoneNumber: data['phoneNumber'],
        );

        print('⚠️⚠️⚠️ USER ROLE: ${_appUser?.role} ⚠️⚠️⚠️'); // Debug role print
        print('Created AppUser: ${_appUser?.toMap()}'); // Debug print
        notifyListeners();
      } else {
        print('No user document found for uid: $uid'); // Debug print
        _ministerData = null;
        _appUser = null;
        notifyListeners();
      }
    } catch (e) {
      print('Error fetching user data: $e');
      _ministerData = null;
      _appUser = null;
      notifyListeners();
    }
  }

  Future<bool> signInWithEmail(String email, String password) async {
    try {
      print('Attempting to sign in with email: $email'); // Debug print
      final userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      print('Sign in successful, fetching user data...'); // Debug print
      await _fetchUserData(userCredential.user!.uid);
      return true;
    } catch (e) {
      print('Error signing in: $e');
      return false;
    }
  }

  Future<void> signOut() async {
    try {
      await _auth.signOut();
      _appUser = null;
      _ministerData = null;
      notifyListeners();
    } catch (e) {
      print('Error signing out: $e');
    }
  }

  Future<bool> isAuthenticated() async {
    return _auth.currentUser != null;
  }
  
  Future<void> updateFCMToken(String token) async {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        await _firestore.collection('users').doc(user.uid).update({
          'fcmToken': token,
        });
        print('FCM token updated for user: ${user.uid}');
      }
    } catch (e) {
      print('Error updating FCM token: $e');
    }
  }
}
