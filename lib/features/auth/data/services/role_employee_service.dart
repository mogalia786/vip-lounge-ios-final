import 'package:cloud_firestore/cloud_firestore.dart';

class RoleEmployeeService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Add a new role-employee number mapping
  Future<void> addRoleEmployeeNumber({
    required String employeeNumber,
    required String role,
    required String createdBy,
  }) async {
    await _firestore.collection('role_employee_numbers').doc(employeeNumber).set({
      'employeeNumber': employeeNumber,
      'role': role,
      'createdBy': createdBy,
      'createdAt': FieldValue.serverTimestamp(),
      'isAssigned': false,
    });
  }

  // Verify if employee number exists and matches role
  Future<bool> verifyRoleEmployeeNumber({
    required String employeeNumber,
    required String role,
  }) async {
    final doc = await _firestore
        .collection('role_employee_numbers')
        .doc(employeeNumber)
        .get();

    if (!doc.exists) return false;
    
    final data = doc.data() as Map<String, dynamic>;
    return data['role'] == role && data['isAssigned'] == false;
  }

  // Mark employee number as assigned when user signs up
  Future<void> markEmployeeNumberAsAssigned(String employeeNumber) async {
    await _firestore
        .collection('role_employee_numbers')
        .doc(employeeNumber)
        .update({'isAssigned': true});
  }
}
