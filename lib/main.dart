import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'app.dart';
import 'core/providers/app_auth_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    print('🔥 Firebase: initializing...');
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    print('🔥 Firebase: initialized');
  } catch (e, st) {
    print('🔥 Firebase init error: $e');
    print(st);
  }

  runApp(
    ChangeNotifierProvider<AppAuthProvider>(
      create: (_) => AppAuthProvider(),
      child: const App(),
    ),
  );
}
