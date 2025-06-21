import 'package:flutter/material.dart';
import 'package:vip_lounge/features/shared/utils/app_update_helper.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/constants/colors.dart';
import '../../../auth/presentation/screens/login_screen.dart';
import '../../../auth/data/services/employee_role_service.dart';

class OperationalManagerHomeScreen extends StatefulWidget {
  const OperationalManagerHomeScreen({super.key});

  @override
  State<OperationalManagerHomeScreen> createState() => _OperationalManagerHomeScreenState();
}

class _OperationalManagerHomeScreenState extends State<OperationalManagerHomeScreen> {
  final _employeeRoleService = EmployeeRoleService();
  final _employeeNumberController = TextEditingController();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  String? _selectedRole;
  bool _isAssigning = false;

  Future<void> _handleLogout(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    
    if (context.mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const LoginScreen()),
        (route) => false,
      );
    }
  }

  Future<void> _assignEmployeeNumber() async {
    if (_selectedRole == null || 
        _employeeNumberController.text.isEmpty ||
        _firstNameController.text.isEmpty ||
        _lastNameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill in all fields'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() => _isAssigning = true);

    try {
      await _employeeRoleService.assignEmployeeNumber(
        employeeNumber: _employeeNumberController.text,
        role: _selectedRole!,
        firstName: _firstNameController.text,
        lastName: _lastNameController.text,
        isAssigned: false,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Employee number assigned successfully'),
          backgroundColor: Colors.green,
        ),
      );

      // Clear form
      _employeeNumberController.clear();
      _firstNameController.clear();
      _lastNameController.clear();
      setState(() {
        _selectedRole = null;
        _isAssigning = false;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error assigning employee number: $e'),
          backgroundColor: AppColors.error,
        ),
      );
      setState(() => _isAssigning = false);
    }
  }

  @override
  void initState() {
    super.initState();
    // Silwela in-app update check
  }

  @override
  void dispose() {
    _employeeNumberController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Operational Manager',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: AppColors.black,
        foregroundColor: AppColors.richGold,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: AppColors.richGold),
            onPressed: () => _handleLogout(context),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Assign Employee Numbers',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppColors.richGold,
                ),
              ),
              const SizedBox(height: 24),
              DropdownButtonFormField<String>(
                value: _selectedRole,
                decoration: InputDecoration(
                  labelText: 'Select Role',
                  border: OutlineInputBorder(
                    borderSide: BorderSide(color: AppColors.richGold),
                  ),
                ),
                items: const [
                  DropdownMenuItem(value: 'floorManager', child: Text('Floor Manager')),
                  DropdownMenuItem(value: 'staff', child: Text('Staff')),
                  DropdownMenuItem(value: 'consultant', child: Text('Consultant')),
                  DropdownMenuItem(value: 'concierge', child: Text('Concierge')),
                  DropdownMenuItem(value: 'cleaner', child: Text('Cleaner')),
                  DropdownMenuItem(value: 'marketingAgent', child: Text('Marketing Agent')),
                ],
                onChanged: (value) => setState(() => _selectedRole = value),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _employeeNumberController,
                decoration: InputDecoration(
                  labelText: 'Employee Number',
                  border: OutlineInputBorder(
                    borderSide: BorderSide(color: AppColors.richGold),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _firstNameController,
                decoration: InputDecoration(
                  labelText: 'First Name',
                  border: OutlineInputBorder(
                    borderSide: BorderSide(color: AppColors.richGold),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _lastNameController,
                decoration: InputDecoration(
                  labelText: 'Last Name',
                  border: OutlineInputBorder(
                    borderSide: BorderSide(color: AppColors.richGold),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isAssigning ? null : _assignEmployeeNumber,
                  child: _isAssigning
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(AppColors.black),
                          ),
                        )
                      : const Text('Assign Employee Number'),
                ),
              ),
              const SizedBox(height: 32),
              Text(
                'Quick Actions',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppColors.richGold,
                ),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 16,
                runSpacing: 16,
                children: [
                  _buildActionCard(
                    context,
                    'View\nAssignments',
                    Icons.assignment,
                    () {
                      // TODO: Navigate to view assignments screen
                    },
                  ),
                  _buildActionCard(
                    context,
                    'Schedule\nShifts',
                    Icons.calendar_today,
                    () {
                      // TODO: Navigate to schedule shifts screen
                    },
                  ),
                  _buildActionCard(
                    context,
                    'View\nReports',
                    Icons.bar_chart,
                    () {
                      // TODO: Navigate to reports screen
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionCard(
    BuildContext context,
    String title,
    IconData icon,
    VoidCallback onTap,
  ) {
    return Card(
      color: AppColors.black,
      child: InkWell(
        onTap: onTap,
        child: Container(
          width: 150,
          height: 150,
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 48, color: AppColors.richGold),
              const SizedBox(height: 8),
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.richGold,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
