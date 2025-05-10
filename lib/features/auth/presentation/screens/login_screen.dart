import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/constants/colors.dart';
import '../../data/services/auth_service.dart';
import '../../data/services/user_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _authService = AuthService();
  final _userService = UserService();
  final _messaging = FirebaseMessaging.instance;
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _testMode = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);

      try {
        // Sign in with Firebase Auth
        final userCredential = await _authService.signInWithEmailAndPassword(
          _emailController.text,
          _passwordController.text,
        );

        // Save test mode to SharedPreferences so all screens recognize it
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('test_mode', _testMode);

        // Get user data from users collection
        final userData = await _userService.getUserById(userCredential.user!.uid);
        if (userData == null) {
          throw 'User data not found';
        }
        final role = (userData['role'] ?? '').toString().toLowerCase();
        // Get FCM token and update user
        final fcmToken = await _messaging.getToken();
        await _userService.updateFcmToken(userCredential.user!.uid, fcmToken);

        if (!mounted) return;

        // Pass test mode state via arguments
        final routeArgs = {'isTestMode': _testMode};

        // Navigate based on role
        print('User role: $role'); // Debug log
        if (role == 'minister') {
          Navigator.pushReplacementNamed(context, '/minister/home', arguments: routeArgs);
        } else if (role == 'floormanager') {
          print('Logging in as floor manager with role format: $role');
          Navigator.pushReplacementNamed(context, '/floor-manager/home', arguments: routeArgs);
        } else if (role == 'marketingagent') {
          Navigator.pushReplacementNamed(context, '/marketing_agent/home', arguments: routeArgs);
        } else if (role == 'operationalmanager') {
          Navigator.pushReplacementNamed(context, '/operational-manager/home', arguments: routeArgs);
        } else if (role == 'consultant') {
          Navigator.pushReplacementNamed(context, '/consultant/home', arguments: routeArgs);
        } else if (role == 'concierge') {
          Navigator.pushReplacementNamed(context, '/concierge/home', arguments: routeArgs);
        } else if (role == 'cleaner') {
          Navigator.pushReplacementNamed(context, '/cleaner/home', arguments: routeArgs);
        } else {
          Navigator.pushReplacementNamed(context, '/staff/home', arguments: routeArgs);
        }
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: AppColors.error,
            duration: const Duration(seconds: 5),
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
    final Color ministerNameColor = Colors.amber;
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.amber.shade700, width: 3.5),
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: Colors.amber.withOpacity(0.25),
                blurRadius: 14,
                spreadRadius: 2,
                offset: Offset(0, 4),
              ),
            ],
            gradient: LinearGradient(
              colors: [
                Colors.black,
                Colors.amber.shade900.withOpacity(0.12),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          constraints: const BoxConstraints(minWidth: 380, maxWidth: 500),
          padding: const EdgeInsets.symmetric(vertical: 34, horizontal: 28),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 100),
                // Logo with border
                Center(
                  child: Container(
                    width: 110,
                    height: 110,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.gold, width: 4),
                    ),
                    child: ClipOval(
                      child: Image.asset(
                        'assets/logo.png',
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) => Icon(Icons.error, color: AppColors.gold, size: 60),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'VIP LOUNGE',
                  style: TextStyle(
                    color: ministerNameColor,
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 48),
                Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextFormField(
                        controller: _emailController,
                        decoration: InputDecoration(
                          labelText: 'Email',
                          labelStyle: TextStyle(color: ministerNameColor),
                          enabledBorder: OutlineInputBorder(
                            borderSide: BorderSide(color: AppColors.gold),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderSide: BorderSide(color: AppColors.gold),
                          ),
                        ),
                        style: TextStyle(color: AppColors.gold),
                        keyboardType: TextInputType.emailAddress,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter your email';
                          }
                          if (!value.contains('@')) {
                            return 'Please enter a valid email';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _passwordController,
                        decoration: InputDecoration(
                          labelText: 'Password',
                          labelStyle: TextStyle(color: ministerNameColor),
                          enabledBorder: OutlineInputBorder(
                            borderSide: BorderSide(color: AppColors.gold),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderSide: BorderSide(color: AppColors.gold),
                          ),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility_off
                                  : Icons.visibility,
                              color: AppColors.gold,
                            ),
                            onPressed: () {
                              setState(() {
                                _obscurePassword = !_obscurePassword;
                              });
                            },
                          ),
                        ),
                        style: TextStyle(color: AppColors.gold),
                        obscureText: _obscurePassword,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter your password';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: _isLoading ? null : _handleLogin,
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
                                'Login',
                                style: TextStyle(
                                  color: AppColors.black,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                      const SizedBox(height: 16),
                      TextButton(
                        onPressed: () {
                          Navigator.pushNamed(context, '/signup');
                        },
                        child: Text(
                          'Don\'t have an account? Sign Up',
                          style: TextStyle(color: ministerNameColor),
                        ),
                      ),
                    ],
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
