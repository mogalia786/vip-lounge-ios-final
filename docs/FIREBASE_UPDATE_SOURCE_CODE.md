# 🔥 Firebase Auto-Update System - Complete Source Code

## 📄 All Required Source Files

### 1. `lib/services/firebase_update_service.dart`

```dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';

class FirebaseUpdateService {
  static const String _versionCollection = 'app_versions';
  static const String _versionDocument = 'current';
  static const String _storageFolder = 'app_updates';

  /// Check for updates and show dialog if available
  static Future<void> checkForUpdates(BuildContext context) async {
    try {
      print('🔍 Checking for app updates...');
      
      // Get current app version
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;
      final currentBuildNumber = int.parse(packageInfo.buildNumber);
      
      print('📱 Current app version: $currentVersion+$currentBuildNumber');
      
      // Get latest version from Firestore
      final versionDoc = await FirebaseFirestore.instance
          .collection(_versionCollection)
          .doc(_versionDocument)
          .get();
      
      if (!versionDoc.exists) {
        print('❌ No version document found in Firestore');
        return;
      }
      
      final versionData = versionDoc.data() as Map<String, dynamic>;
      final latestVersion = versionData['version'] as String;
      final latestBuildNumber = versionData['buildNumber'] as int;
      final forceUpdate = versionData['forceUpdate'] as bool? ?? false;
      final updateMessage = versionData['message'] as String? ?? 'New version available';
      final releaseNotes = List<String>.from(versionData['releaseNotes'] ?? []);
      final apkFileName = versionData['apkFileName'] as String;
      
      print('🆕 Latest version: $latestVersion+$latestBuildNumber');
      
      // Check if update is needed
      if (latestBuildNumber > currentBuildNumber) {
        print('✅ Update available! Showing dialog...');
        
        if (context.mounted) {
          _showUpdateDialog(
            context,
            latestVersion,
            latestBuildNumber,
            updateMessage,
            releaseNotes,
            apkFileName,
            forceUpdate,
          );
        }
      } else {
        print('✅ App is up to date');
      }
    } catch (e) {
      print('❌ Error checking for updates: $e');
    }
  }

  /// Show update dialog to user
  static void _showUpdateDialog(
    BuildContext context,
    String version,
    int buildNumber,
    String message,
    List<String> releaseNotes,
    String apkFileName,
    bool forceUpdate,
  ) {
    showDialog(
      context: context,
      barrierDismissible: !forceUpdate,
      builder: (context) => WillPopScope(
        onWillPop: () async => !forceUpdate,
        child: AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.system_update, color: Colors.blue),
              const SizedBox(width: 8),
              const Text('Update Available'),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Version $version+$buildNumber is now available!'),
                const SizedBox(height: 8),
                Text(message),
                if (releaseNotes.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  const Text(
                    "What's New:",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  ...releaseNotes.map((note) => Padding(
                    padding: const EdgeInsets.only(left: 8, bottom: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('• '),
                        Expanded(child: Text(note)),
                      ],
                    ),
                  )),
                ],
                if (forceUpdate) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red.withOpacity(0.3)),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.warning, color: Colors.red, size: 20),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'This is a required update. You must update to continue using the app.',
                            style: TextStyle(color: Colors.red),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            if (!forceUpdate)
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Later'),
              ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _downloadAndInstallUpdate(context, apkFileName);
              },
              child: const Text('Update Now'),
            ),
          ],
        ),
      ),
    );
  }

  /// Download and install APK update
  static Future<void> _downloadAndInstallUpdate(
    BuildContext context,
    String apkFileName,
  ) async {
    try {
      // Request storage permission
      final permission = await Permission.storage.request();
      if (!permission.isGranted) {
        _showErrorDialog(context, 'Storage permission is required to download the update.');
        return;
      }

      // Show progress dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const AlertDialog(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Downloading update...'),
            ],
          ),
        ),
      );

      // Get download URL from Firebase Storage
      final storageRef = FirebaseStorage.instance
          .ref()
          .child('$_storageFolder/$apkFileName');
      
      final downloadUrl = await storageRef.getDownloadURL();
      print('📥 Download URL: $downloadUrl');

      // Download APK
      final response = await http.get(Uri.parse(downloadUrl));
      if (response.statusCode != 200) {
        throw 'Failed to download APK: ${response.statusCode}';
      }

      // Save APK to device
      final directory = await getExternalStorageDirectory();
      final apkPath = '${directory!.path}/$apkFileName';
      final file = File(apkPath);
      await file.writeAsBytes(response.bodyBytes);

      print('💾 APK saved to: $apkPath');

      // Close progress dialog
      if (context.mounted) {
        Navigator.of(context).pop();
      }

      // Open APK for installation
      final result = await OpenFile.open(apkPath);
      print('📦 Install result: ${result.message}');

      if (result.type != ResultType.done) {
        _showErrorDialog(context, 'Failed to open APK installer: ${result.message}');
      }

    } catch (e) {
      print('❌ Error downloading/installing update: $e');
      
      // Close progress dialog if still open
      if (context.mounted) {
        Navigator.of(context).pop();
        _showErrorDialog(context, 'Failed to download update: $e');
      }
    }
  }

  /// Show error dialog
  static void _showErrorDialog(BuildContext context, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.error, color: Colors.red),
            SizedBox(width: 8),
            Text('Update Error'),
          ],
        ),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  /// Admin method to upload new APK and update version info
  static Future<bool> uploadNewVersion({
    required String version,
    required int buildNumber,
    required String message,
    required List<String> releaseNotes,
    required bool forceUpdate,
    required File apkFile,
  }) async {
    try {
      print('📤 Uploading new version: $version+$buildNumber');
      
      // Generate APK filename
      final apkFileName = 'app-v$version+$buildNumber.apk';
      
      // Upload APK to Firebase Storage
      final storageRef = FirebaseStorage.instance
          .ref()
          .child('$_storageFolder/$apkFileName');
      
      final uploadTask = storageRef.putFile(apkFile);
      final snapshot = await uploadTask;
      
      if (snapshot.state == TaskState.success) {
        print('✅ APK uploaded successfully');
        
        // Update version document in Firestore
        await FirebaseFirestore.instance
            .collection(_versionCollection)
            .doc(_versionDocument)
            .set({
          'version': version,
          'buildNumber': buildNumber,
          'message': message,
          'releaseNotes': releaseNotes,
          'forceUpdate': forceUpdate,
          'apkFileName': apkFileName,
          'uploadedAt': FieldValue.serverTimestamp(),
        });
        
        print('✅ Version document updated in Firestore');
        return true;
      } else {
        print('❌ APK upload failed');
        return false;
      }
    } catch (e) {
      print('❌ Error uploading new version: $e');
      return false;
    }
  }
}
```

### 2. `lib/admin/version_manager.dart`

```dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/firebase_update_service.dart';

class VersionManagerScreen extends StatefulWidget {
  const VersionManagerScreen({Key? key}) : super(key: key);

  @override
  State<VersionManagerScreen> createState() => _VersionManagerScreenState();
}

class _VersionManagerScreenState extends State<VersionManagerScreen> {
  final _formKey = GlobalKey<FormState>();
  final _versionController = TextEditingController();
  final _buildNumberController = TextEditingController();
  final _messageController = TextEditingController();
  final _releaseNotesController = TextEditingController();
  
  bool _forceUpdate = false;
  bool _isUploading = false;
  File? _selectedApk;
  Map<String, dynamic>? _currentVersion;

  @override
  void initState() {
    super.initState();
    _loadCurrentVersion();
  }

  @override
  void dispose() {
    _versionController.dispose();
    _buildNumberController.dispose();
    _messageController.dispose();
    _releaseNotesController.dispose();
    super.dispose();
  }

  Future<void> _loadCurrentVersion() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('app_versions')
          .doc('current')
          .get();
      
      if (doc.exists) {
        setState(() {
          _currentVersion = doc.data();
        });
      }
    } catch (e) {
      print('Error loading current version: $e');
    }
  }

  Future<void> _selectApkFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['apk'],
      );

      if (result != null && result.files.single.path != null) {
        setState(() {
          _selectedApk = File(result.files.single.path!);
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Selected: ${result.files.single.name}'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error selecting APK: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _uploadNewVersion() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedApk == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select an APK file'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isUploading = true);

    try {
      final version = _versionController.text.trim();
      final buildNumber = int.parse(_buildNumberController.text.trim());
      final message = _messageController.text.trim();
      final releaseNotes = _releaseNotesController.text
          .split('\n')
          .where((note) => note.trim().isNotEmpty)
          .map((note) => note.trim())
          .toList();

      final success = await FirebaseUpdateService.uploadNewVersion(
        version: version,
        buildNumber: buildNumber,
        message: message,
        releaseNotes: releaseNotes,
        forceUpdate: _forceUpdate,
        apkFile: _selectedApk!,
      );

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ New version uploaded successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        
        // Clear form
        _versionController.clear();
        _buildNumberController.clear();
        _messageController.clear();
        _releaseNotesController.clear();
        setState(() {
          _selectedApk = null;
          _forceUpdate = false;
        });
        
        // Reload current version
        _loadCurrentVersion();
      } else {
        throw 'Upload failed';
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Error uploading version: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Version Manager'),
        backgroundColor: Colors.blue[800],
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Current Version Card
            if (_currentVersion != null) ...[
              Card(
                color: Colors.blue[50],
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.info, color: Colors.blue[800]),
                          const SizedBox(width: 8),
                          Text(
                            'Current Version',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue[800],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text('Version: ${_currentVersion!['version']}+${_currentVersion!['buildNumber']}'),
                      Text('Message: ${_currentVersion!['message']}'),
                      Text('Force Update: ${_currentVersion!['forceUpdate'] ? 'Yes' : 'No'}'),
                      Text('APK: ${_currentVersion!['apkFileName']}'),
                      if (_currentVersion!['uploadedAt'] != null)
                        Text('Uploaded: ${(_currentVersion!['uploadedAt'] as Timestamp).toDate()}'),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],

            // Upload New Version Form
            Text(
              'Upload New Version',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),

            Form(
              key: _formKey,
              child: Column(
                children: [
                  // Version and Build Number fields
                  TextFormField(
                    controller: _versionController,
                    decoration: const InputDecoration(
                      labelText: 'Version (e.g., 2.1.0)',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.tag),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter a version';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  TextFormField(
                    controller: _buildNumberController,
                    decoration: const InputDecoration(
                      labelText: 'Build Number (e.g., 15)',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.numbers),
                    ),
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter a build number';
                      }
                      if (int.tryParse(value.trim()) == null) {
                        return 'Please enter a valid number';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // Message and Release Notes
                  TextFormField(
                    controller: _messageController,
                    decoration: const InputDecoration(
                      labelText: 'Update Message',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.message),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter an update message';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  TextFormField(
                    controller: _releaseNotesController,
                    decoration: const InputDecoration(
                      labelText: 'Release Notes (one per line)',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.notes),
                      hintText: 'Fixed bug in attendance tracking\nImproved performance\nAdded new features',
                    ),
                    maxLines: 5,
                  ),
                  const SizedBox(height: 16),

                  // Force Update Toggle
                  SwitchListTile(
                    title: const Text('Force Update'),
                    subtitle: const Text('Users must update to continue using the app'),
                    value: _forceUpdate,
                    onChanged: (value) {
                      setState(() => _forceUpdate = value);
                    },
                  ),
                  const SizedBox(height: 16),

                  // APK File Selection
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.android),
                      title: Text(_selectedApk == null 
                          ? 'Select APK File' 
                          : 'APK: ${_selectedApk!.path.split('/').last}'),
                      subtitle: _selectedApk == null 
                          ? const Text('Choose the APK file to upload')
                          : Text('Size: ${(_selectedApk!.lengthSync() / (1024 * 1024)).toStringAsFixed(2)} MB'),
                      trailing: const Icon(Icons.folder_open),
                      onTap: _selectApkFile,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Upload Button
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _isUploading ? null : _uploadNewVersion,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue[800],
                        foregroundColor: Colors.white,
                      ),
                      child: _isUploading
                          ? const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                  ),
                                ),
                                SizedBox(width: 12),
                                Text('Uploading...'),
                              ],
                            )
                          : const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.cloud_upload),
                                SizedBox(width: 8),
                                Text('Upload New Version'),
                              ],
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

### 3. `lib/features/admin/admin_access_helper.dart`

```dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'admin_menu_screen.dart';

class AdminAccessHelper {
  // Check if current user is admin
  static Future<bool> isAdmin(String userId) async {
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();
      
      if (userDoc.exists) {
        final userData = userDoc.data() as Map<String, dynamic>;
        final role = userData['role']?.toString().toLowerCase() ?? '';
        
        // Check for admin roles
        return role == 'admin' || 
               role == 'superadmin' || 
               role == 'floormanager' ||
               role == 'operationalmanager';
      }
      
      return false;
    } catch (e) {
      debugPrint('Error checking admin status: $e');
      return false;
    }
  }
  
  // Show admin access dialog
  static void showAdminAccessDialog(BuildContext context, String userId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.admin_panel_settings, color: Colors.blue),
            SizedBox(width: 8),
            Text('Admin Access'),
          ],
        ),
        content: const Text('Access admin panel to manage app versions and settings.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(context).pop();
              
              // Check if user is admin
              final isAdminUser = await isAdmin(userId);
              
              if (isAdminUser) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const AdminMenuScreen(),
                  ),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Access denied: Admin privileges required'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            child: const Text('Access'),
          ),
        ],
      ),
    );
  }
  
  // Add admin button to any screen (for testing)
  static Widget buildAdminButton(BuildContext context, String userId) {
    return FloatingActionButton(
      onPressed: () => showAdminAccessDialog(context, userId),
      backgroundColor: Colors.blue[800],
      child: const Icon(Icons.admin_panel_settings),
    );
  }
  
  // Hidden gesture detector (tap 5 times on logo/title)
  static Widget buildHiddenAdminAccess({
    required BuildContext context,
    required String userId,
    required Widget child,
  }) {
    int tapCount = 0;
    
    return GestureDetector(
      onTap: () {
        tapCount++;
        if (tapCount >= 5) {
          tapCount = 0;
          showAdminAccessDialog(context, userId);
        }
      },
      child: child,
    );
  }
}
```

### 4. `lib/features/admin/admin_menu_screen.dart`

```dart
import 'package:flutter/material.dart';
import '../../admin/version_manager.dart';

class AdminMenuScreen extends StatelessWidget {
  const AdminMenuScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Panel'),
        backgroundColor: Colors.blue[800],
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Version Manager Card
          Card(
            child: ListTile(
              leading: const Icon(
                Icons.system_update,
                color: Colors.blue,
                size: 32,
              ),
              title: const Text(
                'Version Manager',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              subtitle: const Text('Upload and manage app versions'),
              trailing: const Icon(Icons.arrow_forward_ios),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const VersionManagerScreen(),
                  ),
                );
              },
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Other admin functions
          Card(
            child: ListTile(
              leading: const Icon(
                Icons.settings,
                color: Colors.grey,
                size: 32,
              ),
              title: const Text(
                'App Settings',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              subtitle: const Text('Configure app settings'),
              trailing: const Icon(Icons.arrow_forward_ios),
              onTap: () {
                // Navigate to app settings
              },
            ),
          ),
        ],
      ),
    );
  }
}
```

## 🚀 Quick Integration Examples

### Add to Main App Widget:
```dart
@override
void initState() {
  super.initState();
  WidgetsBinding.instance.addPostFrameCallback((_) {
    FirebaseUpdateService.checkForUpdates(context);
  });
}
```

### Add Version Manager to Admin Screen:
```dart
// In your admin/settings screen:
ElevatedButton(
  onPressed: () {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const VersionManagerScreen(),
      ),
    );
  },
  child: const Text('Version Manager'),
)
```

### Add Hidden Admin Access:
```dart
// Tap logo 5 times to access admin
AdminAccessHelper.buildHiddenAdminAccess(
  context: context,
  userId: currentUserId,
  child: Text('Your App Logo'),
)
```

## 🎯 Complete Implementation Checklist

- [ ] Add dependencies to pubspec.yaml
- [ ] Create all 4 source files
- [ ] Set up Firebase project with Firestore and Storage
- [ ] Create Firestore collection: `app_versions/current`
- [ ] Create Firebase Storage folder: `app_updates/`
- [ ] Add integration to main app
- [ ] Add admin access to appropriate screens
- [ ] Test with sample APK upload
- [ ] Verify update flow on device

## 🎉 Ready to Use!

This complete source code provides enterprise-grade auto-update functionality that you can easily integrate into any Flutter project with Firebase backend.
