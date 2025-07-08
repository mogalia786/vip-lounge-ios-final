import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mocktail/mocktail.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vip_lounge/features/help/data/services/phone_data_updater.dart';

// Mock classes using mocktail
class MockClient extends Mock implements http.Client {}
class MockResponse extends Mock implements http.Response {}
class MockDirectory extends Mock implements Directory {
  @override
  Future<Directory> create({bool recursive = false}) async => this;
  
  @override
  String get path => 'test_path';
  
  @override
  bool existsSync() => true;
}

class MockFile extends Mock implements File {
  @override
  Future<File> writeAsString(String contents, {FileMode mode = FileMode.write, Encoding encoding = utf8, bool flush = false}) async => this;
  
  @override
  Future<String> readAsString({Encoding encoding = utf8}) async => '{}';
  
  @override
  bool existsSync() => true;
  
  @override
  String get path => 'test_file_path';
}

class MockSharedPreferences extends Mock implements SharedPreferences {
  final Map<String, dynamic> _storage = {};
  
  @override
  Future<bool> setInt(String key, int value) async {
    _storage[key] = value;
    return true;
  }
  
  @override
  int? getInt(String key) => _storage[key] as int?;
  
  @override
  Future<bool> setString(String key, String value) async {
    _storage[key] = value;
    return true;
  }
  
  @override
  String? getString(String key) => _storage[key] as String?;
  
  @override
  Future<bool> clear() async {
    _storage.clear();
    return true;
  }
  
  @override
  bool containsKey(String key) => _storage.containsKey(key);
  
  @override
  Object? get(String key) => _storage[key];
  
  @override
  bool? getBool(String key) => _storage[key] as bool?;
  
  @override
  double? getDouble(String key) => _storage[key] as double?;
  
  @override
  Set<String> getKeys() => _storage.keys.toSet();
  
  @override
  List<String>? getStringList(String key) => _storage[key] as List<String>?;
  
  @override
  Future<void> reload() async {}
  
  @override
  Future<bool> remove(String key) async {
    _storage.remove(key);
    return true;
  }
  
  @override
  Future<bool> setBool(String key, bool value) async {
    _storage[key] = value;
    return true;
  }
  
  @override
  Future<bool> setDouble(String key, double value) async {
    _storage[key] = value;
    return true;
  }
  
  @override
  Future<bool> setStringList(String key, List<String> value) async {
    _storage[key] = value;
    return true;
  }
}

// Mock path provider handler
class MockPathProvider {
  static const MethodChannel channel = MethodChannel('plugins.flutter.io/path_provider');
  
  static void setUpMockPathProvider() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
      if (methodCall.method == 'getApplicationDocumentsDirectory') {
        return 'test_app_documents_path';
      }
      return null;
    });
  }
}

void main() {
  late PhoneDataUpdater phoneDataUpdater;
  late MockClient mockHttpClient;
  late MockSharedPreferences mockPrefs;
  late MockDirectory mockDirectory;
  late MockFile mockFile;
  
  setUpAll(() {
    // Register fallback values for mocks
    registerFallbackValue(Uri.parse('http://example.com'));
    registerFallbackValue(http.Request('GET', Uri.parse('http://example.com')));
    
    // Setup mock path provider
    TestWidgetsFlutterBinding.ensureInitialized();
    MockPathProvider.setUpMockPathProvider();
  });
  
  setUp(() {
    mockHttpClient = MockClient();
    mockPrefs = MockSharedPreferences();
    mockDirectory = MockDirectory();
    mockFile = MockFile();
    
    // Setup default mock behaviors
    when(() => mockDirectory.create(recursive: true)).thenAnswer((_) async => mockDirectory);
    when(() => mockFile.writeAsString(any(), mode: any(named: 'mode'))).thenAnswer((_) async => mockFile);
    when(() => mockFile.readAsString()).thenAnswer((_) async => '{}');
    
    // Setup default HTTP responses
    when(() => mockHttpClient.get(any())).thenAnswer((_) async => http.Response('{}', 200));
  });
  
  tearDown(() {
    // Reset all mocks
    reset(mockHttpClient);
    reset(mockPrefs);
    reset(mockDirectory);
    reset(mockFile);
  });
  
  const testApiKey = 'test_api_key';
  const testBrand = 'Apple';
  const testModelId = 'iphone-13';
  
  final testBrandsData = {
    'last_updated': DateTime.now().toIso8601String(),
    'brands': [
      {'id': 'apple', 'name': 'Apple', 'device_count': 10},
      {'id': 'samsung', 'name': 'Samsung', 'device_count': 8},
    ]
  };
  
  final testModelsData = [
    {
      'device_name': 'iPhone 13',
      'detail': '/iphone-13',
      'image': 'https://example.com/iphone13.jpg'
    }
  ];
  
  final testPhoneDetails = {
    'name': 'iPhone 13',
    'brand': 'Apple',
    'specifications': {
      'display': '6.1-inch Super Retina XDR',
      'processor': 'A15 Bionic',
      'storage': '128GB',
      'ram': '4GB',
      'battery': '3240 mAh'
    }
  };
  
  // Helper function to create a test PhoneDataUpdater instance
  PhoneDataUpdater createPhoneDataUpdater() {
    return PhoneDataUpdater(apiKey: testApiKey)..setHttpClient(mockHttpClient);
  }

  test('should update phone data successfully', () async {
    // Arrange
    when(() => mockHttpClient.get(any())).thenAnswer((invocation) async {
      final uri = invocation.positionalArguments[0] as Uri;
      if (uri.path.endsWith('get-models-by-brandname/$testBrand')) {
        return http.Response(jsonEncode(testModelsData), 200);
      } else if (uri.path.endsWith('get-specifications/$testModelId')) {
        return http.Response(jsonEncode(testPhoneDetails), 200);
      }
      return http.Response('Not Found', 404);
    });
    
    final phoneDataUpdater = createPhoneDataUpdater();
    
    // Act
    await phoneDataUpdater.updateAllPhoneData();
    
    // Verify HTTP requests were made
    verify(() => mockHttpClient.get(any())).called(any);
    
    // Verify files were written
    verify(() => mockFile.writeAsString(any(), mode: any(named: 'mode'))).called(any);
    
    // Verify preferences were updated
    verify(() => mockPrefs.setInt(any(), any())).called(1);
  });

  test('should handle update failure gracefully', () async {
    // Arrange
    when(() => mockHttpClient.get(any())).thenAnswer((_) async => http.Response('Error', 500));
    
    final phoneDataUpdater = createPhoneDataUpdater();
    
    // Act & Assert
    expect(
      () => phoneDataUpdater.updateAllPhoneData(),
      throwsA(isA<Exception>()),
    );
  });

  test('should check if update is needed', () async {
    // Arrange
    final phoneDataUpdater = createPhoneDataUpdater();
    
    // Test when no last update time is set
    bool shouldUpdate = await phoneDataUpdater.shouldUpdate();
    expect(shouldUpdate, isTrue);
    
    // Test when last update was recent
    await mockPrefs.setInt('last_phone_data_update', DateTime.now().millisecondsSinceEpoch);
    shouldUpdate = await phoneDataUpdater.shouldUpdate();
    expect(shouldUpdate, isFalse);
    
    // Test when last update was a long time ago
    final oldTime = DateTime.now().subtract(const Duration(days: 60)).millisecondsSinceEpoch;
    await mockPrefs.setInt('last_phone_data_update', oldTime);
    shouldUpdate = await phoneDataUpdater.shouldUpdate();
    expect(shouldUpdate, isTrue);
  });
  
  test('should load phone data from local storage', () async {
    // Arrange
    when(() => mockFile.readAsString()).thenAnswer((_) async => jsonEncode(testBrandsData));
    
    final phoneDataUpdater = createPhoneDataUpdater();
    
    // Act
    final brands = await phoneDataUpdater.getPhoneBrands();
    
    // Assert
    expect(brands, isNotNull);
    expect(brands.length, 2);
    expect(brands[0].name, 'Apple');
    expect(brands[1].name, 'Samsung');
  });
  
  test('should handle missing local data gracefully', () async {
    // Arrange
    when(() => mockFile.readAsString()).thenThrow(FileSystemException('File not found'));
    
    final phoneDataUpdater = createPhoneDataUpdater();
    
    // Act
    final brands = await phoneDataUpdater.getPhoneBrands();
    
    // Assert
    expect(brands, isEmpty);
  });
}
