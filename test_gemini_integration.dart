import 'package:flutter_test/flutter_test.dart';
import 'package:vip_lounge/features/help/services/gemini_service.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

void main() {
  test('GeminiService initialization test', () async {
    // Load environment variables
    await dotenv.load(fileName: ".env");
    
    // Initialize the service
    final geminiService = GeminiService();
    
    // Wait a bit for initialization to complete
    await Future.delayed(const Duration(seconds: 2));
    
    // Check if service is initialized
    expect(geminiService.isInitialized(), true);
    
    // Test getting help with a simple query
    final response = await geminiService.getPhoneSetupHelp(
      phoneBrand: 'Samsung',
      phoneModel: 'Galaxy S23',
      feature: 'Bluetooth',
      additionalDetails: 'I need help pairing my headphones',
    );
    
    // Verify we got a response
    expect(response, isNotNull);
    expect(response.isNotEmpty, true);
    
    print('Test passed! Response: $response');
  });
}
