import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import '../firebase_options.dart';

Future<void> createUserDoc({
  required String uid,
  required String email,
  required String firstName,
  required String lastName,
  required String role,
  required String employeeNumber,
  String? phoneNumber,
}) async {
  // Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Initialize Firestore
  final db = FirebaseFirestore.instance;

  // Create user document
  await db.collection('users').doc(uid).set({
    'firstName': firstName,
    'lastName': lastName,
    'email': email,
    'phoneNumber': phoneNumber,
    'role': role,
    'employeeNumber': employeeNumber,
    'createdAt': FieldValue.serverTimestamp(),
    'lastLoginAt': FieldValue.serverTimestamp(),
    'isActive': true,
    'isSupervisor': role == 'operationalManager',
    'uid': uid,
    'fcmToken': null,
  });
}

// Example usage:
Future<void> main() async {
  // Replace these values with your actual user data
  await createUserDoc(
    uid: 'EQp9o4CnUuRDklneVcoRHeuev1y2',
    email: 'supervisor@gmail.com',
    firstName: 'Supervisor',
    lastName: 'Admin',
    role: 'operationalManager', 
    employeeNumber: 'S1001',
    phoneNumber: null,
  );
  print('User document created successfully!');
  exit(0);
}
