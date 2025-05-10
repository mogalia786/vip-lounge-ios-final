import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'firebase_options.dart';
import 'core/providers/app_auth_provider.dart';
import 'core/services/initialization_service.dart';
import 'core/services/fcm_service.dart';
import 'app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Configure Firebase Auth to handle reCAPTCHA
  await FirebaseAuth.instance.setSettings(
    appVerificationDisabledForTesting: true, // Enable this for testing
  );

  final user = FirebaseAuth.instance.currentUser;

  // Initialize the app (create supervisor user)
  final initService = InitializationService();
  await initService.initializeApp();

  // Initialize FCM service
  await FCMService().init();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AppAuthProvider()),
      ],
      child: App(isLoggedIn: user != null),
    ),
  );
}
