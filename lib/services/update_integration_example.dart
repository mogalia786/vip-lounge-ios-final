import 'package:flutter/material.dart';
import 'custom_update_service.dart';
import 'app_update_service.dart';

// Example integration in your main app widget
class MainAppWithUpdates extends StatefulWidget {
  const MainAppWithUpdates({Key? key}) : super(key: key);

  @override
  State<MainAppWithUpdates> createState() => _MainAppWithUpdatesState();
}

class _MainAppWithUpdatesState extends State<MainAppWithUpdates> with WidgetsBindingObserver {
  
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    
    // Initialize update checking after app loads
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeUpdates();
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
      _checkForUpdatesOnResume();
    }
  }
  
  Future<void> _initializeUpdates() async {
    try {
      // Choose your update method:
      
      // Option 1: Google Play Store updates (if published on Play Store)
      // await AppUpdateService.initializeUpdateCheck(context);
      
      // Option 2: Custom server updates (for private distribution)
      await CustomUpdateService.initialize(context);
      
    } catch (e) {
      debugPrint('Error initializing updates: $e');
    }
  }
  
  Future<void> _checkForUpdatesOnResume() async {
    // Check for updates when app comes back to foreground
    // This ensures users get updates even if they don't restart the app
    await Future.delayed(const Duration(seconds: 1)); // Small delay
    
    try {
      // await AppUpdateService.checkForUpdate(context); // For Play Store
      await CustomUpdateService.checkForUpdates(context); // For custom server
    } catch (e) {
      debugPrint('Error checking for updates on resume: $e');
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
              await CustomUpdateService.checkForUpdates(context);
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

// Settings screen with update options
class UpdateSettingsScreen extends StatelessWidget {
  const UpdateSettingsScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Update Settings'),
      ),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.system_update),
            title: const Text('Check for Updates'),
            subtitle: const Text('Manually check for app updates'),
            onTap: () async {
              await CustomUpdateService.checkForUpdates(context);
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.info),
            title: const Text('App Version'),
            subtitle: FutureBuilder<String>(
              future: _getAppVersion(),
              builder: (context, snapshot) {
                return Text(snapshot.data ?? 'Loading...');
              },
            ),
          ),
          ListTile(
            leading: const Icon(Icons.auto_awesome),
            title: const Text('Auto-Update Settings'),
            subtitle: const Text('Configure automatic updates'),
            trailing: Switch(
              value: true, // You can store this in SharedPreferences
              onChanged: (value) {
                // Save auto-update preference
                // SharedPreferences.getInstance().then((prefs) {
                //   prefs.setBool('auto_update_enabled', value);
                // });
              },
            ),
          ),
        ],
      ),
    );
  }
  
  Future<String> _getAppVersion() async {
    try {
      final packageInfo = await package_info_plus.PackageInfo.fromPlatform();
      return 'Version ${packageInfo.version} (${packageInfo.buildNumber})';
    } catch (e) {
      return 'Unknown';
    }
  }
}
