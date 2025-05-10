import 'package:cloud_firestore/cloud_firestore.dart';

class EmployeeRoleService {
  final _db = FirebaseFirestore.instance;
  final _employeeRegistryCollection = FirebaseFirestore.instance.collection('employee_registry');

  Future<void> assignEmployeeNumber({
    required String employeeNumber,
    required String role,
    required String firstName,
    required String lastName,
    required bool isAssigned,
  }) async {
    try {
      await _employeeRegistryCollection.doc(employeeNumber).set({
        'employeeNumber': employeeNumber,
        'role': role,
        'firstName': firstName,
        'lastName': lastName,
        'hasSignedUp': isAssigned,
        'registeredAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error assigning employee number: $e');
      throw e;
    }
  }

  Future<Map<String, dynamic>?> getEmployeeDetails(String employeeNumber) async {
    try {
      // First try to find by direct document ID
      final docRef = _employeeRegistryCollection.doc(employeeNumber);
      final doc = await docRef.get();
      
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        return {
          'employeeNumber': employeeNumber,
          'firstName': data['firstName'] as String? ?? '',
          'lastName': data['lastName'] as String? ?? '',
          'role': data['role'] as String? ?? '',
          'hasSignedUp': data['hasSignedUp'] as bool? ?? false,
        };
      }
      
      // If not found by ID, query by employeeNumber field
      final querySnapshot = await _employeeRegistryCollection
          .where('employeeNumber', isEqualTo: employeeNumber)
          .limit(1)
          .get();
          
      if (querySnapshot.docs.isNotEmpty) {
        final data = querySnapshot.docs.first.data();
        return {
          'employeeNumber': employeeNumber,
          'firstName': data['firstName'] as String? ?? '',
          'lastName': data['lastName'] as String? ?? '',
          'role': data['role'] as String? ?? '',
          'hasSignedUp': data['hasSignedUp'] as bool? ?? false,
        };
      }
      
      print('Employee with number $employeeNumber not found');
      return null;
    } catch (e) {
      print('Error getting employee details: $e');
      return null;
    }
  }

  Future<bool> isEmployeeNumberValid(String employeeNumber, String role) async {
    try {
      final employeeDetails = await getEmployeeDetails(employeeNumber);
      
      if (employeeDetails == null) {
        print('Employee number not found: $employeeNumber');
        return false;
      }
      
      final isValid = employeeDetails['role'] == role && !employeeDetails['hasSignedUp'];
      
      print('Employee validation for $employeeNumber:');
      print('  Role matches: ${employeeDetails['role'] == role}');
      print('  Not signed up: ${!employeeDetails['hasSignedUp']}');
      print('  Is valid: $isValid');
      
      return isValid;
    } catch (e) {
      print('Error validating employee number: $e');
      return false;
    }
  }

  Future<void> markEmployeeAsSignedUp(String employeeNumber) async {
    try {
      // First try to find by direct document ID
      final docRef = _employeeRegistryCollection.doc(employeeNumber);
      final doc = await docRef.get();
      
      if (doc.exists) {
        await docRef.update({
          'hasSignedUp': true,
          'updatedAt': FieldValue.serverTimestamp(),
        });
        print('Marked employee number $employeeNumber as signed up (by ID)');
        return;
      }
      
      // If not found by ID, query by employeeNumber field
      final querySnapshot = await _employeeRegistryCollection
          .where('employeeNumber', isEqualTo: employeeNumber)
          .limit(1)
          .get();
          
      if (querySnapshot.docs.isNotEmpty) {
        await querySnapshot.docs.first.reference.update({
          'hasSignedUp': true,
          'updatedAt': FieldValue.serverTimestamp(),
        });
        print('Marked employee number $employeeNumber as signed up (by query)');
        return;
      }
      
      throw Exception('Employee with number $employeeNumber not found');
    } catch (e) {
      print('Error marking employee as signed up: $e');
      throw e;
    }
  }

  Future<List<Map<String, dynamic>>> getUnassignedEmployees(String role) async {
    try {
      final snapshot = await _employeeRegistryCollection
          .where('role', isEqualTo: role)
          .where('hasSignedUp', isEqualTo: false)
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'employeeNumber': data['employeeNumber'] ?? doc.id,
          'firstName': data['firstName'] ?? '',
          'lastName': data['lastName'] ?? '',
          'role': data['role'] ?? '',
        };
      }).toList();
    } catch (e) {
      print('Error getting unassigned employees: $e');
      return [];
    }
  }

  Future<void> resetEmployeeSignupStatus(String employeeNumber) async {
    try {
      // First try to find by direct document ID
      final docRef = _employeeRegistryCollection.doc(employeeNumber);
      final doc = await docRef.get();
      
      if (doc.exists) {
        await docRef.update({
          'hasSignedUp': false,
          'updatedAt': FieldValue.serverTimestamp(),
        });
        print('Reset employee number $employeeNumber signup status (by ID)');
        return;
      }
      
      // If not found by ID, query by employeeNumber field
      final querySnapshot = await _employeeRegistryCollection
          .where('employeeNumber', isEqualTo: employeeNumber)
          .limit(1)
          .get();
          
      if (querySnapshot.docs.isNotEmpty) {
        await querySnapshot.docs.first.reference.update({
          'hasSignedUp': false,
          'updatedAt': FieldValue.serverTimestamp(),
        });
        print('Reset employee number $employeeNumber signup status (by query)');
        return;
      }
      
      throw Exception('Employee with number $employeeNumber not found');
    } catch (e) {
      print('Error resetting employee signup status: $e');
      throw e;
    }
  }
}
