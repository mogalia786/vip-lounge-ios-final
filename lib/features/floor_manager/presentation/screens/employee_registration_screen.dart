import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import '../../../../core/constants/colors.dart';

class EmployeeRegistrationScreen extends StatefulWidget {
  const EmployeeRegistrationScreen({Key? key}) : super(key: key);

  @override
  _EmployeeRegistrationScreenState createState() => _EmployeeRegistrationScreenState();
}

class _EmployeeRegistrationScreenState extends State<EmployeeRegistrationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _employeeNumberController = TextEditingController();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  String _selectedRole = 'consultant';
  bool _isLoading = false;
  bool _isEditMode = false;
  String? _currentEmployeeId;
  
  // List of roles that can be assigned (excluding minister)
  final List<String> _roles = [
    'floorManager',
    'operationalManager',
    'staff',
    'consultant',
    'concierge',
    'cleaner',
    'marketingAgent'
  ];

  @override
  void dispose() {
    _employeeNumberController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    super.dispose();
  }

  void _resetForm() {
    _employeeNumberController.clear();
    _firstNameController.clear();
    _lastNameController.clear();
    setState(() {
      _selectedRole = 'consultant';
      _isEditMode = false;
      _currentEmployeeId = null;
    });
  }

  Future<void> _saveEmployee() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Check if employee number already exists (except when editing)
      final existingQuery = await FirebaseFirestore.instance
          .collection('employee_registry')
          .where('employeeNumber', isEqualTo: _employeeNumberController.text)
          .get();
      
      if (existingQuery.docs.isNotEmpty && !_isEditMode) {
        // An employee with this number already exists
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Employee number already registered'),
            backgroundColor: Colors.red,
          ),
        );
        setState(() {
          _isLoading = false;
        });
        return;
      }

      final employeeData = {
        'employeeNumber': _employeeNumberController.text,
        'firstName': _firstNameController.text,
        'lastName': _lastNameController.text,
        'role': _selectedRole,
        'registeredAt': FieldValue.serverTimestamp(),
        'hasSignedUp': false,
      };

      if (_isEditMode && _currentEmployeeId != null) {
        // Update existing employee
        await FirebaseFirestore.instance
            .collection('employee_registry')
            .doc(_currentEmployeeId)
            .update(employeeData);
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Employee updated successfully'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        // Add new employee
        await FirebaseFirestore.instance
            .collection('employee_registry')
            .add(employeeData);
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Employee registered successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }

      // Reset form after successful save
      _resetForm();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _editEmployee(Map<String, dynamic> employee, String employeeId) {
    setState(() {
      _employeeNumberController.text = employee['employeeNumber'] ?? '';
      _firstNameController.text = employee['firstName'] ?? '';
      _lastNameController.text = employee['lastName'] ?? '';
      _selectedRole = employee['role'] ?? 'consultant';
      _isEditMode = true;
      _currentEmployeeId = employeeId;
    });

    // Scroll to the top of the screen
    scrollToTop();
  }

  void scrollToTop() {
    // This method would scroll to the top of the screen if we had a scroll controller
    // But for now, we'll just focus on the first field
    FocusScope.of(context).requestFocus(FocusNode());
  }

  Future<void> _deleteEmployee(String employeeId) async {
    try {
      // Check if employee has signed up
      final employeeDoc = await FirebaseFirestore.instance
          .collection('employee_registry')
          .doc(employeeId)
          .get();
      
      if (employeeDoc.exists) {
        final employeeData = employeeDoc.data() as Map<String, dynamic>;
        if (employeeData['hasSignedUp'] == true) {
          // Show confirmation dialog for deleting an active employee
          final shouldDelete = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              backgroundColor: Colors.grey[900],
              title: Text('Warning', style: TextStyle(color: Colors.red)),
              content: Text(
                'This employee has already signed up. Deleting this record will not remove their user account. Are you sure you want to continue?',
                style: TextStyle(color: Colors.white),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: Text('Cancel', style: TextStyle(color: Colors.grey)),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: Text('Delete', style: TextStyle(color: Colors.red)),
                ),
              ],
            ),
          );
          
          if (shouldDelete != true) {
            return;
          }
        }
      }

      await FirebaseFirestore.instance
          .collection('employee_registry')
          .doc(employeeId)
          .delete();
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Employee removed from registry'),
          backgroundColor: Colors.green,
        ),
      );
      
      // If we were editing this employee, reset the form
      if (_isEditMode && _currentEmployeeId == employeeId) {
        _resetForm();
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: Text(
          'Employee Registration',
          style: TextStyle(color: AppColors.gold),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: AppColors.gold),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (_isEditMode)
            IconButton(
              icon: Icon(Icons.cancel, color: Colors.red),
              onPressed: _resetForm,
              tooltip: 'Cancel editing',
            ),
        ],
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Registration Form Card
              Card(
                color: Colors.grey[900],
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: AppColors.gold.withOpacity(0.5), width: 1),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _isEditMode ? 'Edit Employee' : 'Register New Employee',
                          style: TextStyle(
                            color: AppColors.gold,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 24),
                        
                        // Employee Number Field
                        TextFormField(
                          controller: _employeeNumberController,
                          style: TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            labelText: 'Employee Number',
                            labelStyle: TextStyle(color: Colors.grey[400]),
                            prefixIcon: Icon(Icons.badge, color: AppColors.gold),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(color: Colors.grey[700]!),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(color: Colors.grey[700]!),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(color: AppColors.gold),
                            ),
                          ),
                          enabled: !_isEditMode, // Can't change employee number when editing
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter employee number';
                            }
                            return null;
                          },
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9\-]')),
                          ],
                        ),
                        const SizedBox(height: 16),
                        
                        // First Name Field
                        TextFormField(
                          controller: _firstNameController,
                          style: TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            labelText: 'First Name',
                            labelStyle: TextStyle(color: Colors.grey[400]),
                            prefixIcon: Icon(Icons.person, color: AppColors.gold),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(color: Colors.grey[700]!),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(color: Colors.grey[700]!),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(color: AppColors.gold),
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter first name';
                            }
                            return null;
                          },
                          textCapitalization: TextCapitalization.words,
                        ),
                        const SizedBox(height: 16),
                        
                        // Last Name Field
                        TextFormField(
                          controller: _lastNameController,
                          style: TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            labelText: 'Last Name',
                            labelStyle: TextStyle(color: Colors.grey[400]),
                            prefixIcon: Icon(Icons.person, color: AppColors.gold),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(color: Colors.grey[700]!),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(color: Colors.grey[700]!),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(color: AppColors.gold),
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter last name';
                            }
                            return null;
                          },
                          textCapitalization: TextCapitalization.words,
                        ),
                        const SizedBox(height: 16),
                        
                        // Role Dropdown
                        DropdownButtonFormField<String>(
                          value: _selectedRole,
                          dropdownColor: Colors.grey[800],
                          style: TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            labelText: 'Role',
                            labelStyle: TextStyle(color: Colors.grey[400]),
                            prefixIcon: Icon(Icons.work, color: AppColors.gold),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(color: Colors.grey[700]!),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(color: Colors.grey[700]!),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(color: AppColors.gold),
                            ),
                          ),
                          onChanged: (String? newValue) {
                            setState(() {
                              _selectedRole = newValue!;
                            });
                          },
                          items: _roles.map<DropdownMenuItem<String>>((String value) {
                            return DropdownMenuItem<String>(
                              value: value,
                              child: Text(
                                value[0].toUpperCase() + value.substring(1),
                              ),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 24),
                        
                        // Save Button
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _saveEmployee,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.gold,
                              foregroundColor: Colors.black,
                              disabledBackgroundColor: Colors.grey,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: _isLoading
                                ? CircularProgressIndicator(color: Colors.black)
                                : Text(
                                    _isEditMode ? 'Update Employee' : 'Register Employee',
                                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              
              // Employees List Section
              Expanded(
                child: Card(
                  color: Colors.grey[900],
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: Colors.grey[800]!, width: 1),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Registered Employees',
                          style: TextStyle(
                            color: AppColors.gold,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        
                        // Employee List
                        Expanded(
                          child: StreamBuilder<QuerySnapshot>(
                            stream: FirebaseFirestore.instance
                                .collection('employee_registry')
                                .orderBy('registeredAt', descending: true)
                                .snapshots(),
                            builder: (context, snapshot) {
                              if (snapshot.hasError) {
                                return Center(child: Text('Error loading employees', style: TextStyle(color: Colors.red)));
                              }
                              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                                return Center(child: Text('No employees registered', style: TextStyle(color: Colors.white70)));
                              }
                              final employees = snapshot.data!.docs;
                              return ListView.separated(
                                itemCount: employees.length,
                                separatorBuilder: (_, __) => Divider(color: Colors.grey[800]),
                                itemBuilder: (context, index) {
                                  final employee = employees[index].data() as Map<String, dynamic>;
                                  final name = employee['firstName'] + ' ' + employee['lastName'];
                                  final role = employee['role'] ?? '';
                                  return ListTile(
                                    title: Text(name, style: TextStyle(color: Colors.white)),
                                    subtitle: Text(role, style: TextStyle(color: Colors.grey)),
                                  );
                                },
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getColorForRole(String role) {
    switch (role.toLowerCase()) {
      case 'consultant':
        return Colors.blue;
      case 'concierge':
        return Colors.green;
      case 'cleaner':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }
}
