import 'dart:io';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';
import 'dart:convert';

class AppUpdateHelper {
  
  static const String _versionCheckUrl = 'https://vip-lounge-f3730.web.app/version.json';

  static Future<void> checkAndPromptUpdate(BuildContext context, String versionInfoUrl) async {
    print('AppUpdateHelper: Checking for update from ' + versionInfoUrl);
    try {
      final response = await http.get(Uri.parse(versionInfoUrl));
      if (response.statusCode != 200) return;
      final data = json.decode(response.body);
      final latestVersion = data['version'] as String?;
      final apkUrl = data['apk_url'] as String?;
      if (latestVersion == null || apkUrl == null) return;

      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;
      print('Current version: ' + currentVersion + ', Latest version: ' + latestVersion);
      
      if (_isNewerVersion(latestVersion, currentVersion)) {
        _showUpdateDialog(context, apkUrl, latestVersion);
      }
    } catch (e) {
      debugPrint('Update check failed: $e');
    }
  }

  static bool _isNewerVersion(String latest, String current) {
    final latestParts = latest.split('.').map(int.parse).toList();
    final currentParts = current.split('.').map(int.parse).toList();
    for (int i = 0; i < latestParts.length; i++) {
      if (i >= currentParts.length || latestParts[i] > currentParts[i]) return true;
      if (latestParts[i] < currentParts[i]) return false;
    }
    return false;
  }

  static void _showUpdateDialog(BuildContext context, String apkUrl, String version) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Text('Update Available'),
        content: Text('A new version ($version) is available. Update now to continue.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Later'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              await _downloadAndInstallApk(context, apkUrl);
            },
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }

  static Future<void> _downloadAndInstallApk(BuildContext context, String apkUrl) async {
    try {
      debugPrint('✔️ AppUpdateHelper: Starting _downloadAndInstallApk for $apkUrl');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Starting APK download...')),
      );
      debugPrint('AppUpdateHelper: Getting external storage directory');
      final tempDir = await getExternalStorageDirectory();
      if (tempDir == null) throw Exception('Storage not available');
      final apkPath = '${tempDir.path}/silwela-latest.apk';
      debugPrint('AppUpdateHelper: Downloading APK from $apkUrl');
      final response = await http.get(Uri.parse(apkUrl));
      if (response.statusCode != 200) {
        throw Exception('Failed to download APK (status ${response.statusCode})');
      }
      debugPrint('AppUpdateHelper: Writing APK to $apkPath');
      final file = File(apkPath);
      await file.writeAsBytes(response.bodyBytes);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('APK downloaded. Opening installer...')),
      );
      debugPrint('AppUpdateHelper: Opening APK');
      final result = await OpenFile.open(apkPath);
      debugPrint('AppUpdateHelper: OpenFile result: \\${result.type}, message: \\${result.message}');
      if (result.type != ResultType.done) {
        String displayMessage = 'Failed to install update. Raw Error: ${result.message} (Type: ${result.type})';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(displayMessage), duration: const Duration(seconds: 10)),
        );
      }
    } catch (e) {
      debugPrint('AppUpdateHelper: Download/install failed: $e');
      String errorMessage = 'Failed to install update. Raw Exception: $e';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errorMessage, maxLines: 5, overflow: TextOverflow.ellipsis)),
      );
    }
  }
}

void showInstallPermissionWarning(BuildContext context) {
  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Manual Action Required'),
      content: const Text(
        'To install updates, please go to your device settings and enable "Install unknown apps" for this app.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('OK'),
        ),
      ],
    ),
  );
}
