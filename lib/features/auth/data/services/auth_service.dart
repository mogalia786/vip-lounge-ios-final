import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../../../core/enums/user_role.dart';
import '../../presentation/screens/minister/minister_home_screen.dart';
import '../../../../features/floor_manager/presentation/screens/floor_manager_home_screen_new.dart';
import '../../presentation/screens/operational_manager/operational_manager_home_screen.dart';
import '../../presentation/screens/staff/staff_home_screen.dart';
import '../../presentation/screens/consultant/consultant_home_screen.dart';
import '../../presentation/screens/concierge/concierge_home_screen.dart';
import '../../presentation/screens/cleaner/cleaner_home_screen.dart';
import '../../presentation/screens/marketing_agent/marketing_agent_home_screen.dart';

class AuthService {
  final _auth = FirebaseAuth.instance;

  Future<UserCredential> signInWithEmailAndPassword(
    String email,
    String password,
  ) async {
    try {
      return await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      switch (e.code) {
        case 'user-not-found':
          throw 'No user found with this email';
        case 'wrong-password':
          throw 'Wrong password';
        case 'user-disabled':
          throw 'This account has been disabled';
        case 'invalid-email':
          throw 'Invalid email format';
        default:
          print('Firebase Auth Error: ${e.code} - ${e.message}'); // Debug log
          throw 'Login failed: ${e.message}';
      }
    } catch (e) {
      print('Unexpected Error: $e'); // Debug log
      throw 'An unexpected error occurred';
    }
  }

  Future<UserCredential> createUserWithEmailAndPassword(
    String email,
    String password,
  ) async {
    try {
      return await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      switch (e.code) {
        case 'email-already-in-use':
          throw 'Email already in use';
        case 'invalid-email':
          throw 'Invalid email format';
        case 'weak-password':
          throw 'Password is too weak';
        default:
          print('Firebase Auth Error: ${e.code} - ${e.message}'); // Debug log
          throw 'Failed to create account: ${e.message}';
      }
    } catch (e) {
      print('Unexpected Error: $e'); // Debug log
      throw 'An unexpected error occurred';
    }
  }

  // Method that returns just the user ID after successful signup
  Future<String> signUpWithEmailAndPassword(
    String email,
    String password,
  ) async {
    try {
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      
      if (userCredential.user == null) {
        throw 'Failed to create user account';
      }
      
      return userCredential.user!.uid;
    } on FirebaseAuthException catch (e) {
      switch (e.code) {
        case 'email-already-in-use':
          throw 'Email already in use';
        case 'invalid-email':
          throw 'Invalid email format';
        case 'weak-password':
          throw 'Password is too weak';
        default:
          print('Firebase Auth Error: ${e.code} - ${e.message}'); // Debug log
          throw 'Failed to create account: ${e.message}';
      }
    } catch (e) {
      print('Unexpected Error: $e'); // Debug log
      throw 'An unexpected error occurred';
    }
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }

  User? get currentUser => _auth.currentUser;

  Widget getHomeScreenForRole(String role) {
    final userRole = UserRole.values.firstWhere(
      (r) => r.name == role,
      orElse: () => UserRole.staff,
    );

    switch (userRole) {
      case UserRole.minister:
        return const MinisterHomeScreen();
      case UserRole.floorManager:
        return const FloorManagerHomeScreenNew();
      case UserRole.operationalManager:
        return const OperationalManagerHomeScreen();
      case UserRole.consultant:
        return const ConsultantHomeScreen();
      case UserRole.concierge:
        return const ConciergeHomeScreen();
      case UserRole.cleaner:
        return const CleanerHomeScreen();
      case UserRole.marketingAgent:
        return const MarketingAgentHomeScreen();
      case UserRole.staff:
      default:
        return const StaffHomeScreen();
    }
  }
}
