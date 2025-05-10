import 'package:flutter/material.dart';
import 'package:vip_lounge/core/constants/colors.dart';
import '../../../data/services/staff_registration_service.dart';
import 'add_staff_screen.dart';

class ManageStaffScreen extends StatefulWidget {
  const ManageStaffScreen({super.key});

  @override
  State<ManageStaffScreen> createState() => _ManageStaffScreenState();
}

class _ManageStaffScreenState extends State<ManageStaffScreen> {
  final StaffRegistrationService _staffService = StaffRegistrationService();
  List<Map<String, dynamic>> _staff = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadStaff();
  }

  Future<void> _loadStaff() async {
    setState(() => _isLoading = true);
    try {
      final staff = await _staffService.getAllPreRegisteredStaff();
      setState(() {
        _staff = staff;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      // Handle error
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.black,
      appBar: AppBar(
        title: const Text('Manage Staff'),
        backgroundColor: AppColors.black,
        foregroundColor: AppColors.gold,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.gold))
          : ListView.builder(
              itemCount: _staff.length,
              itemBuilder: (context, index) {
                final staff = _staff[index];
                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  color: AppColors.black,
                  child: ListTile(
                    title: Text(
                      '${staff['firstName']} ${staff['lastName']}',
                      style: const TextStyle(color: AppColors.gold),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Employee #: ${staff['employeeNumber']}',
                          style: const TextStyle(color: AppColors.white),
                        ),
                        Text(
                          'Role: ${staff['assignedRole']}',
                          style: const TextStyle(color: AppColors.white),
                        ),
                      ],
                    ),
                    trailing: Switch(
                      value: staff['isActive'] ?? false,
                      onChanged: (bool value) {
                        // TODO: Implement status toggle
                      },
                      activeColor: AppColors.gold,
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const AddStaffScreen(),
            ),
          );
          if (result == true) {
            _loadStaff(); // Refresh the list if staff was added
          }
        },
        backgroundColor: AppColors.gold,
        child: const Icon(Icons.add, color: AppColors.black),
      ),
    );
  }
}
