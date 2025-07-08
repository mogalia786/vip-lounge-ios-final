import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:vip_lounge/features/help/services/gemini_service.dart';

Future<void> main() async {
  print('Loading environment variables...');
  await dotenv.load(fileName: ".env");
  
  print('Initializing Gemini service...');
  final geminiService = GeminiService();
  
  // Wait for initialization
  await Future.delayed(const Duration(seconds: 2));
  
  if (!geminiService.isInitialized()) {
    print('Error: Failed to initialize Gemini service');
    print('Error details: ${geminiService.errorMessage}');
    return;
  }
  
  print('Gemini service initialized successfully!');
  print('Sending test request...');
  
  try {
    final response = await geminiService.getPhoneSetupHelp(
      phoneBrand: 'Samsung',
      phoneModel: 'Galaxy S23',
      feature: 'Bluetooth',
      additionalDetails: 'I need help pairing my headphones',
    );
    
    print('\n=== GEMINI RESPONSE ===');
    print(response);
    print('=====================');
  } catch (e) {
    print('Error: $e');
  }
}
