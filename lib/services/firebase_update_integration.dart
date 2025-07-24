import 'package:flutter/material.dart';
import 'firebase_update_service.dart';

// Example integration in your main app widget
class AppWithFirebaseUpdates extends StatefulWidget {
  const AppWithFirebaseUpdates({Key? key}) : super(key: key);

  @override
  State<AppWithFirebaseUpdates> createState() => _AppWithFirebaseUpdatesState();
}

class _AppWithFirebaseUpdatesState extends State<AppWithFirebaseUpdates> 
    with WidgetsBindingObserver {
  
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    
    // Initialize Firebase update checking after app loads
    WidgetsBinding.instance.addPostFrameCallback((_) {
      FirebaseUpdateService.initialize(context);
    });
  }
  
  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
  
  // Check for updates when app comes to foreground
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      // Check for updates when user returns to app
      Future.delayed(const Duration(seconds: 2), () {
        FirebaseUpdateService.checkForUpdates(context);
      });
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('VIP Lounge'),
        actions: [
          // Optional: Manual update check button
          IconButton(
            icon: const Icon(Icons.system_update),
            onPressed: () async {
              await FirebaseUpdateService.checkForUpdates(context);
            },
            tooltip: 'Check for Updates',
          ),
        ],
      ),
      body: const Center(
        child: Text('Your VIP Lounge App Content'),
      ),
    );
  }
}

// How to integrate in your existing main.dart or app.dart:
/*

import 'services/firebase_update_service.dart';

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'VIP Lounge',
      home: YourMainScreen(),
    );
  }
}

class YourMainScreen extends StatefulWidget {
  @override
  _YourMainScreenState createState() => _YourMainScreenState();
}

class _YourMainScreenState extends State<YourMainScreen> 
    with WidgetsBindingObserver {
  
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    
    // Check for updates when app starts
    WidgetsBinding.instance.addPostFrameCallback((_) {
      FirebaseUpdateService.initialize(context);
    });
  }
  
  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
  
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Check for updates when app comes back to foreground
      Future.delayed(const Duration(seconds: 1), () {
        FirebaseUpdateService.checkForUpdates(context);
      });
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Your existing UI
    );
  }
}

*/
