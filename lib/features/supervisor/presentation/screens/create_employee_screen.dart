import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../../core/constants/colors.dart';
import '../../../../core/enums/user_role.dart';
import '../../../auth/data/services/role_employee_service.dart';

class CreateEmployeeScreen extends StatefulWidget {
  const CreateEmployeeScreen({super.key});

  @override
  State<CreateEmployeeScreen> createState() => _CreateEmployeeScreenState();
}

class _CreateEmployeeScreenState extends State<CreateEmployeeScreen> {
  final _formKey = GlobalKey<FormState>();
  final _employeeNumberController = TextEditingController();
  final _roleEmployeeService = RoleEmployeeService();
  UserRole? _selectedRole;
  bool _isLoading = false;

  @override
  void dispose() {
    _employeeNumberController.dispose();
    super.dispose();
  }

  Future<void> _handleCreateEmployee() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);

      try {
        final currentUser = FirebaseAuth.instance.currentUser;
        if (currentUser == null) throw Exception('Not authenticated');

        await _roleEmployeeService.addRoleEmployeeNumber(
          employeeNumber: _employeeNumberController.text,
          role: _selectedRole!.name,
          createdBy: currentUser.uid,
        );

        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Employee number created successfully!'),
            backgroundColor: AppColors.green,
          ),
        );

        // Clear form
        _employeeNumberController.clear();
        setState(() => _selectedRole = null);

      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error creating employee: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      } finally {
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.black,
      appBar: AppBar(
        title: Text(
          'Create Employee',
          style: TextStyle(color: AppColors.gold),
        ),
        backgroundColor: AppColors.black,
        foregroundColor: AppColors.gold,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              DropdownButtonFormField<UserRole>(
                value: _selectedRole,
                dropdownColor: AppColors.black,
                decoration: InputDecoration(
                  labelText: 'Select Role',
                  labelStyle: TextStyle(color: AppColors.gold),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: AppColors.gold),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: AppColors.gold, width: 2),
                  ),
                ),
                style: TextStyle(color: AppColors.white),
                items: UserRole.values
                    .where((role) => role != UserRole.minister)
                    .map((role) {
                  return DropdownMenuItem(
                    value: role,
                    child: Text(
                      role.name.toUpperCase(),
                      style: TextStyle(color: AppColors.white),
                    ),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() => _selectedRole = value);
                },
                validator: (value) {
                  if (value == null) return 'Please select a role';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _employeeNumberController,
                decoration: InputDecoration(
                  labelText: 'Employee Number',
                  labelStyle: TextStyle(color: AppColors.gold),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: AppColors.gold),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: AppColors.gold),
                  ),
                ),
                style: TextStyle(color: AppColors.gold),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter employee number';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _isLoading ? null : _handleCreateEmployee,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.gold,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: _isLoading
                    ? SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.black,
                        ),
                      )
                    : Text(
                        'Create Employee',
                        style: TextStyle(
                          color: AppColors.black,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
