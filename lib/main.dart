import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'firebase_options.dart';
import 'core/providers/app_auth_provider.dart';
import 'core/services/initialization_service.dart';
import 'core/services/fcm_service.dart';
import 'app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize timezone data for calendar integration
  tz.initializeTimeZones();
  
  // Load environment variables
  await dotenv.load(fileName: ".env");
  
  // Initialize Firebase
  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }
  } catch (e) {
    // Ignore duplicate initialization triggered by native AppDelegate
    // ignore: avoid_print
    print('⚠️ Firebase initialize skipped: ' + e.toString());
  }

  // Debug: Log Firebase options and bundle info
  final opts = DefaultFirebaseOptions.currentPlatform;
  final pkg = await PackageInfo.fromPlatform();
  // ignore: avoid_print
  print('📦 Bundle ID: ' + (opts is FirebaseOptions ? (opts is FirebaseOptions && opts.iosBundleId != null ? opts.iosBundleId! : 'n/a') : 'n/a'));
  // ignore: avoid_print
  print('🔥 Firebase project: ' + opts.projectId + ', appId: ' + opts.appId);
  // Quick Firestore connectivity check
  try {
    await FirebaseFirestore.instance.collection('_connectivity').limit(1).get(const GetOptions(source: Source.server));
    // ignore: avoid_print
    print('✅ Firestore reachable');
  } catch (e) {
    // ignore: avoid_print
    print('❌ Firestore reachability failed: ' + e.toString());
  }

  // Configure Firebase Auth
  await FirebaseAuth.instance.setSettings(
    appVerificationDisabledForTesting: true, // Enable this for testing
  );

  // Initialize dependencies
  final user = FirebaseAuth.instance.currentUser;

  // Initialize the app (create supervisor user)
  final initService = InitializationService();
  await initService.initializeApp();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AppAuthProvider()),
      ],
      child: Builder(
        builder: (context) {
          // Initialize FCM service with context
          FCMService().init();
          return App(isLoggedIn: user != null);
        },
      ),
    ),
  );
}
