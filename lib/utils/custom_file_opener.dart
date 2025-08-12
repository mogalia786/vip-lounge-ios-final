import 'dart:io' show Platform;
import 'package:url_launcher/url_launcher_string.dart';

class CustomFileOpener {
  static Future<bool> openFile(String? filePath) async {
    if (filePath == null) return false;
    
    try {
      if (Platform.isIOS || Platform.isAndroid) {
        // Use the platform's default handler for mobile
        final uri = Uri.file(filePath).toString();
        return await launchUrlString(
          uri,
          mode: LaunchMode.externalApplication,
        );
      }
      return false;
    } catch (e) {
      print('Error opening file: $e');
      return false;
    }
  }
}
