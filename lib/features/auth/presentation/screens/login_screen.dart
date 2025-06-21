import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/constants/colors.dart';
import 'package:vip_lounge/features/staff/presentation/screens/staff_home_screen_test.dart';
import '../../data/services/auth_service.dart';
import '../../data/services/user_service.dart';
import '../../../shared/utils/app_update_helper.dart';

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

  String _versionInfo = '';

  @override
  void initState() {
    super.initState();
    _initPackageInfo();
    AppUpdateHelper.checkAndPromptUpdate(context, 'https://vip-lounge-f3730.web.app/version.json');
  }

  Future<void> _initPackageInfo() async {
    final info = await PackageInfo.fromPlatform();
    setState(() {
      _versionInfo = '${info.appName} v${info.version}+${info.buildNumber}';
    });
  }

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

        // Navigate based on role
        print('User role: $role'); // Debug log
        if (role == 'minister') {
          Navigator.pushReplacementNamed(context, '/minister/home');
        } else if (role == 'floormanager') {
          print('Logging in as floor manager with role format: $role');
          Navigator.pushReplacementNamed(context, '/floor-manager/home');
        } else if (role == 'marketingagent') {
          Navigator.pushReplacementNamed(context, '/marketing_agent/home');
        } else if (role == 'operationalmanager') {
          Navigator.pushReplacementNamed(context, '/operational-manager/home');
        } else if (role == 'consultant') {
          Navigator.pushReplacementNamed(context, '/consultant/home');
        } else if (role == 'concierge') {
          Navigator.pushReplacementNamed(context, '/concierge/home');
        } else if (role == 'cleaner') {
          Navigator.pushReplacementNamed(context, '/cleaner/home');
        } else {
          // TEST: Route staff to the new StaffHomeScreenTest for safe testing
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => StaffHomeScreenTest()),
          );
        }
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'Incorrect username or password. Please try again.',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
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
      body: Container(
        child: SafeArea(
          child: Stack(
            children: [
              Positioned.fill(
                child: Opacity(
                  opacity: 0.15,
                  child: Image.asset(
                    'assets/cc_logo_original.png',
                    fit: BoxFit.contain,
                  ),
                ),
              ),
              Center(
                child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(height: 64),
                        const SizedBox(height: 20),
                        Text(
                          'PREMIUM LOUNGE',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.montserrat(
                            fontSize: 40,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                            letterSpacing: 2.0,
                          ),
                        ),
                        const SizedBox(height: 48),
                        Form(
                          key: _formKey,
                          child: Column(
                            children: [
                              TextFormField(
                                controller: _emailController,
                                decoration: InputDecoration(
                                  labelText: 'Email',
                                  labelStyle: TextStyle(color: Colors.white),
                                  hintText: 'Enter your email',
                                  hintStyle: TextStyle(color: AppColors.primary),
                                  enabledBorder: OutlineInputBorder(
                                    borderSide: BorderSide(color: Colors.grey.shade400, width: 2.2),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderSide: BorderSide(color: Colors.grey.shade400, width: 2.5),
                                  ),
                                ),
                                style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold),
                                validator: (value) {
                                  if (value == null || value.isEmpty || !value.contains('@')) {
                                    return 'Please enter a valid email';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 16),
                              TextFormField(
                                controller: _passwordController,
                                obscureText: _obscurePassword,
                                decoration: InputDecoration(
                                  labelText: 'Password',
                                  labelStyle: TextStyle(color: Colors.white),
                                  hintText: 'Enter your password',
                                  hintStyle: TextStyle(color: AppColors.primary),
                                  enabledBorder: OutlineInputBorder(
                                    borderSide: BorderSide(color: Colors.grey.shade400, width: 2.2),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderSide: BorderSide(color: Colors.grey.shade400, width: 2.5),
                                  ),
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      _obscurePassword
                                          ? Icons.visibility_off
                                          : Icons.visibility,
                                      color: AppColors.richGold,
                                    ),
                                    onPressed: () {
                                      setState(() {
                                        _obscurePassword = !_obscurePassword;
                                      });
                                    },
                                  ),
                                ),
                                style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold),
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
                                  backgroundColor: AppColors.black,
                                  side: BorderSide(color: AppColors.richGold, width: 2),
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  minimumSize: const Size(double.infinity, 50),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                child: _isLoading
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: AppColors.richGold,
                                        ),
                                      )
                                    : Text(
                                        'Login',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                              ),
                              const SizedBox(height: 16),
                              TextButton(
                                onPressed: () {
                                  Navigator.pushNamed(context, '/signup');
                                },
                                child: RichText(
                                  text: TextSpan(
                                    text: "Don't have an account? ",
                                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
                                    children: [
                                      TextSpan(
                                        text: 'Sign Up',
                                        style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 64),
                        if (_versionInfo.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8.0),
                            child: Text(
                              '$_versionInfo\nPowered by MOGALIA ENTERPRISES',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                              ),
                              textAlign: TextAlign.center,
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
}
