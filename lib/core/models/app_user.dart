import 'package:firebase_auth/firebase_auth.dart';

class AppUser {
  final String uid;
  final String role;
  final String firstName;
  final String lastName;
  final String email;
  final String? phoneNumber;

  AppUser({
    required this.uid,
    required this.role,
    required this.firstName,
    required this.lastName,
    required this.email,
    this.phoneNumber,
  });

  String get name => '$firstName $lastName';

  // Add fullName getter for compatibility
  String get fullName => '$firstName $lastName';

  // Add id getter to maintain compatibility with code that expects id
  String get id => uid;

  factory AppUser.fromMap(Map<String, dynamic> map) {
    return AppUser(
      uid: map['uid'] ?? '',
      role: map['role'] ?? '',
      firstName: map['firstName'] ?? '',
      lastName: map['lastName'] ?? '',
      email: map['email'] ?? '',
      phoneNumber: map['phoneNumber'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'role': role,
      'firstName': firstName,
      'lastName': lastName,
      'email': email,
      'phoneNumber': phoneNumber,
    };
  }
}
