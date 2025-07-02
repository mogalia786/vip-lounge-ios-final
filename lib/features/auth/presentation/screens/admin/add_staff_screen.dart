import 'package:flutter/material.dart';
import 'package:vip_lounge/core/constants/colors.dart';
import '../../../data/services/staff_registration_service.dart';
import '../../../../../core/enums/user_role.dart';

class AddStaffScreen extends StatefulWidget {
  const AddStaffScreen({super.key});

  @override
  State<AddStaffScreen> createState() => _AddStaffScreenState();
}

class _AddStaffScreenState extends State<AddStaffScreen> {
  final _formKey = GlobalKey<FormState>();
  final _staffService = StaffRegistrationService();
  
  final _employeeNumberController = TextEditingController();
  UserRole _selectedRole = UserRole.floorManager;

  final _roles = [
    UserRole.floorManager,
    UserRole.consultant,
    UserRole.concierge,
    UserRole.operationalManager,
    UserRole.cleaner,
    UserRole.marketingAgent,
  ];

  bool _isLoading = false;

  @override
  void dispose() {
    _employeeNumberController.dispose();
    super.dispose();
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      await _staffService.addPreRegisteredStaff(
        employeeNumber: _employeeNumberController.text,
        assignedRole: _selectedRole.name,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Employee number pre-registered successfully. Employee can now sign up using this number.'),
            duration: Duration(seconds: 4),
          ),
        );
        Navigator.pop(context, true); // Return true to indicate success
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error pre-registering employee: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.black,
      appBar: AppBar(
        title: const Text('Pre-Register Employee'),
        backgroundColor: AppColors.black,
        foregroundColor: AppColors.primary,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Pre-register an employee number and role. The employee will use this number to sign up and complete their profile.',
                  style: TextStyle(color: AppColors.white, fontSize: 16),
                ),
                const SizedBox(height: 24),
                TextFormField(
                  controller: _employeeNumberController,
                  decoration: InputDecoration(
                    labelText: 'Employee Number',
                    labelStyle: TextStyle(color: AppColors.primary),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: AppColors.primary),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: AppColors.primary),
                    ),
                  ),
                  style: TextStyle(color: AppColors.white),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter employee number';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<UserRole>(
                  value: _selectedRole,
                  decoration: InputDecoration(
                    labelText: 'Role',
                    labelStyle: TextStyle(color: AppColors.primary),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: AppColors.primary),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: AppColors.primary),
                    ),
                  ),
                  dropdownColor: AppColors.black,
                  style: TextStyle(color: AppColors.white),
                  items: _roles.map((role) {
                    return DropdownMenuItem(
                      value: role,
                      child: Text(
                        role.name.toUpperCase(),
                        style: TextStyle(color: AppColors.white),
                      ),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _selectedRole = value);
                    }
                  },
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _isLoading ? null : _submitForm,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator()
                      : Text(
                          'Pre-Register Employee',
                          style: TextStyle(
                            color: AppColors.black,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
