import 'package:flutter/material.dart';
import '../../../../core/constants/colors.dart';
import '../../data/services/auth_service.dart';
import '../../data/services/user_service.dart';
import '../../data/services/employee_role_service.dart';
import '../../../../core/enums/user_role.dart';
import 'package:intl_phone_number_input/intl_phone_number_input.dart';

class SignupScreen extends StatefulWidget {
  SignupScreen({Key? key}) : super(key: key);
  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _employeeNumberController = TextEditingController();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _authService = AuthService();
  final _userService = UserService();
  final _employeeRoleService = EmployeeRoleService();
  PhoneNumber _phoneNumber = PhoneNumber(isoCode: 'ZA');
  bool _isLoading = false;
  bool _isVerified = false;
  bool _isVerifying = false;
  UserRole? _selectedRole;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool get _requiresEmployeeNumber {
    return _selectedRole != null && _selectedRole != UserRole.minister;
  }

  @override
  void dispose() {
    _employeeNumberController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _verifyEmployeeNumber() async {
    if (_selectedRole == null || _employeeNumberController.text.isEmpty) {
      setState(() {
        _isVerified = false;
        _isVerifying = false;
      });
      return;
    }
    setState(() => _isVerifying = true);
    try {
      final details = await _employeeRoleService.getEmployeeDetails(_employeeNumberController.text);
      if (details == null) {
        throw 'Employee number not found';
      }
      final isValid = await _employeeRoleService.isEmployeeNumberValid(
        _employeeNumberController.text,
        _selectedRole!.name,
      );
      if (isValid) {
        setState(() {
          _firstNameController.text = details['firstName'];
          _lastNameController.text = details['lastName'];
          _isVerified = true;
        });
      } else {
        setState(() {
          _isVerified = false;
          _firstNameController.text = '';
          _lastNameController.text = '';
        });
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('This employee number is already assigned or invalid for the selected role'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isVerified = false;
        _firstNameController.text = '';
        _lastNameController.text = '';
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error verifying employee number: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isVerifying = false);
    }
  }

  Future<void> _handleSignup() async {
    if (!_formKey.currentState!.validate()) return;
    if (_requiresEmployeeNumber && !_isVerified) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please verify your employee number first'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    setState(() => _isLoading = true);
    try {
      final userId = await _authService.signUpWithEmailAndPassword(
        _emailController.text,
        _passwordController.text,
      );
      await _userService.createUser(
        userId,
        {
          'firstName': _firstNameController.text,
          'lastName': _lastNameController.text,
          'email': _emailController.text,
          'phoneNumber': _phoneNumber.phoneNumber,
          'role': _selectedRole!.name,
          'employeeNumber': _requiresEmployeeNumber ? _employeeNumberController.text : null,
          'createdAt': DateTime.now(),
        },
      );
      if (_requiresEmployeeNumber) {
        await _employeeRoleService.markEmployeeAsSignedUp(_employeeNumberController.text);
      }
      if (!mounted) return;
      final roleScreens = {
        'minister': '/minister_home',
        'floor_manager': '/floor_manager_home',
        'floorManager': '/floor_manager_home',
        'operational_manager': '/operational_manager_home',
        'operationalManager': '/operational_manager_home',
        'consultant': '/consultant_home',
        'concierge': '/concierge_home',
        'cleaner': '/cleaner/home',
        'marketingAgent': '/marketing_agent_home',
        'marketing_agent': '/marketing_agent_home',
        'staff': '/staff_home',
      };
      Navigator.of(context).pushReplacementNamed('/login');
    } catch (e) {
      setState(() => _isLoading = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error creating account: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _buildEmployeeNumberField() {
    if (_selectedRole == UserRole.minister) {
      return const SizedBox.shrink();
    }
    return Column(
      children: [
        TextFormField(
          controller: _employeeNumberController,
          decoration: InputDecoration(
            labelText: 'Employee Number',
            suffixIcon: _isVerifying
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : _isVerified
                    ? const Icon(Icons.check_circle, color: Colors.green)
                    : IconButton(
                        icon: const Icon(Icons.verified_user),
                        onPressed: _verifyEmployeeNumber,
                      ),
          ),
          enabled: !_isVerified,
          validator: (value) {
            if (_requiresEmployeeNumber) {
              if (value == null || value.isEmpty) {
                return 'Please enter your employee number';
              }
              if (!_isVerified) {
                return 'Please verify your employee number';
              }
            }
            return null;
          },
          onChanged: (value) {
            if (_isVerified) {
              setState(() {
                _isVerified = false;
                _firstNameController.text = '';
                _lastNameController.text = '';
              });
            }
          },
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildNameFields() {
    return Column(
      children: [
        TextFormField(
          controller: _firstNameController,
          enabled: !_isVerified,
          decoration: const InputDecoration(
            labelText: 'First Name',
          ),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please enter your first name';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _lastNameController,
          enabled: !_isVerified,
          decoration: const InputDecoration(
            labelText: 'Last Name',
          ),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please enter your last name';
            }
            return null;
          },
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Account', style: TextStyle(color: const Color(0xFFD7263D), fontWeight: FontWeight.bold, fontSize: 24)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: Colors.white.withOpacity(0.7)),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color(0xFF0A1931),
              Color(0xFF182848),
              Color(0xFF223A5E),
              Color(0xFF0A1931),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                DropdownButtonFormField<UserRole>(
                  value: _selectedRole,
                  dropdownColor: Color(0xFF182848), // Match background
                  iconEnabledColor: Colors.white.withOpacity(0.7),
                  decoration: InputDecoration(
                    labelText: 'Select Role',
                    labelStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
                    hintText: 'Choose your role',
                    hintStyle: TextStyle(color: const Color(0xFFD7263D).withOpacity(0.7)),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.grey.shade400, width: 2.2),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.grey.shade400, width: 2.5),
                    ),
                  ),
                  items: UserRole.values.map((role) {
                    String displayName = role.name;
                    switch (role) {
                      case UserRole.floorManager:
                        displayName = 'Floor Manager';
                        break;
                      case UserRole.operationalManager:
                        displayName = 'Operational Manager';
                        break;
                      case UserRole.marketingAgent:
                        displayName = 'Marketing Agent';
                        break;
                      default:
                        displayName = role.name[0].toUpperCase() + role.name.substring(1);
                    }
                    return DropdownMenuItem(
                      value: role,
                      child: Text(displayName),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedRole = value;
                      _isVerified = false;
                      _employeeNumberController.clear();
                      _firstNameController.clear();
                      _lastNameController.clear();
                    });
                  },
                  validator: (value) {
                    if (value == null) {
                      return 'Please select a role';
                    }
                    return null;
                  },
                ),
                _buildEmployeeNumberField(),
                _buildNameFields(),
                TextFormField(
                  controller: _emailController,
                  decoration: InputDecoration(
                    labelText: 'Email',
                    labelStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
                    hintStyle: TextStyle(color: const Color(0xFFD7263D).withOpacity(0.7)),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.grey.shade400, width: 2.2),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.grey.shade400, width: 2.5),
                    ),
                  ),
                  style: const TextStyle(color: Color(0xFFD7263D), fontWeight: FontWeight.bold),
                  keyboardType: TextInputType.emailAddress,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter email';
                    }
                    if (!value.contains('@')) {
                      return 'Please enter a valid email';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                InternationalPhoneNumberInput(
                  onInputChanged: (PhoneNumber number) {
                    _phoneNumber = number;
                  },
                  selectorConfig: SelectorConfig(
                    selectorType: PhoneInputSelectorType.BOTTOM_SHEET,
                    setSelectorButtonAsPrefixIcon: true,
                    leadingPadding: 12,
                  ),
                  textStyle: const TextStyle(color: Color(0xFFD7263D), fontWeight: FontWeight.bold),
                  inputDecoration: InputDecoration(
                    labelText: 'Phone Number',
                    labelStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
                    hintStyle: TextStyle(color: const Color(0xFFD7263D).withOpacity(0.7)),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.grey.shade400, width: 2.2),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.grey.shade400, width: 2.5),
                    ),
                  ),
                  initialValue: _phoneNumber,
                  formatInput: true,
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _passwordController,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    labelStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
                    hintStyle: TextStyle(color: const Color(0xFFD7263D).withOpacity(0.7)),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.grey.shade400, width: 2.2),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.grey.shade400, width: 2.5),
                    ),
                    suffixIcon: IconButton(
                      icon: Icon(_obscurePassword ? Icons.visibility : Icons.visibility_off, color: Colors.white.withOpacity(0.7)),
                      onPressed: () {
                        setState(() {
                          _obscurePassword = !_obscurePassword;
                        });
                      },
                    ),
                  ),
                  style: const TextStyle(color: Color(0xFFD7263D), fontWeight: FontWeight.bold),
                  obscureText: _obscurePassword,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter password';
                    }
                    if (value.length < 6) {
                      return 'Password must be at least 6 characters';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _confirmPasswordController,
                  decoration: InputDecoration(
                    labelText: 'Confirm Password',
                    labelStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
                    hintStyle: TextStyle(color: const Color(0xFFD7263D).withOpacity(0.7)),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.grey.shade400, width: 2.2),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.grey.shade400, width: 2.5),
                    ),
                    suffixIcon: IconButton(
                      icon: Icon(_obscureConfirmPassword ? Icons.visibility : Icons.visibility_off, color: Colors.white.withOpacity(0.7)),
                      onPressed: () {
                        setState(() {
                          _obscureConfirmPassword = !_obscureConfirmPassword;
                        });
                      },
                    ),
                  ),
                  style: const TextStyle(color: Color(0xFFD7263D), fontWeight: FontWeight.bold),
                  obscureText: _obscureConfirmPassword,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please confirm password';
                    }
                    if (value != _passwordController.text) {
                      return 'Passwords do not match';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _isLoading ? null : _handleSignup,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.indigo[600],
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
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
                          'Sign Up',
                          style: TextStyle(color: const Color(0xFFD7263D), fontWeight: FontWeight.bold),
                        ),
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () {
                    Navigator.pushReplacementNamed(context, '/login');
                  },
                  child: RichText(
                    text: TextSpan(
                      text: 'Already have an account? ',
                      style: TextStyle(color: const Color(0xFFd4af37)),
                      children: [
                        TextSpan(
                          text: 'Login',
                          style: TextStyle(color: const Color(0xFFD7263D), fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ), // Closes SingleChildScrollView
      ), // Closes Container (body of Scaffold)
    );
  }
}
