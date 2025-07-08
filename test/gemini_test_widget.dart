import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:vip_lounge/features/help/services/gemini_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");
  
  runApp(const GeminiTestApp());
}

class GeminiTestApp extends StatelessWidget {
  const GeminiTestApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Gemini Service Test',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const GeminiTestPage(),
    );
  }
}

class GeminiTestPage extends StatefulWidget {
  const GeminiTestPage({super.key});

  @override
  State<GeminiTestPage> createState() => _GeminiTestPageState();
}

class _GeminiTestPageState extends State<GeminiTestPage> {
  final _geminiService = GeminiService();
  String _response = 'Initializing...';
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _testGeminiService();
  }

  Future<void> _testGeminiService() async {
    setState(() {
      _isLoading = true;
      _response = 'Testing Gemini service...';
    });

    try {
      // Wait for service to initialize
      await Future.delayed(const Duration(seconds: 1));

      if (!_geminiService.isInitialized()) {
        setState(() {
          _response = 'Error: Gemini service failed to initialize. Error: ${_geminiService.errorMessage}';
        });
        return;
      }

      // Test a simple query
      final result = await _geminiService.getPhoneSetupHelp(
        phoneBrand: 'Samsung',
        phoneModel: 'Galaxy S23',
        feature: 'Bluetooth',
        additionalDetails: 'I need help pairing my headphones',
      );

      setState(() {
        _response = 'Success! Gemini Service Response:\n\n$result';
      });
    } catch (e) {
      setState(() {
        _response = 'Error testing Gemini service: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gemini Service Test'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Gemini Service Test Results',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              if (_isLoading)
                const Center(child: CircularProgressIndicator())
              else
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: SelectableText(
                    _response,
                    style: const TextStyle(fontFamily: 'monospace'),
                  ),
                ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _isLoading ? null : _testGeminiService,
                child: const Text('Run Test Again'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
