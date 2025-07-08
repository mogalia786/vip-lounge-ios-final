import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:vip_lounge/features/help/services/gemini_service.dart';

Future<void> main() async {
  print('Testing Gemini Service...');
  
  // Load environment variables
  await dotenv.load(fileName: ".env");
  
  // Initialize the service
  final geminiService = GeminiService();
  
  // Wait for initialization
  await Future.delayed(const Duration(seconds: 2));
  
  if (!geminiService.isInitialized()) {
    print('Failed to initialize Gemini service');
    print('Error: ${geminiService.errorMessage}');
    return;
  }
  
  print('Gemini service initialized successfully!');
  
  // Test the service
  try {
    print('\nSending test request to Gemini...');
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
