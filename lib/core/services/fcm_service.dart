import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../providers/app_auth_provider.dart';
import '../../features/minister/presentation/screens/consultant_rating_screen.dart';
import '../../features/minister/presentation/screens/minister_home_screen.dart';

class FCMService {
  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final navigatorKey = GlobalKey<NavigatorState>();
  
  // Singleton pattern
  static final FCMService _instance = FCMService._internal();
  
  factory FCMService() {
    return _instance;
  }
  
  FCMService._internal();

  // Initialize basic FCM services without context
  Future<void> init() async {
    // Request notification permissions
    await _fcm.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );
    
    // Initialize flutter_local_notifications
    final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
    const AndroidInitializationSettings initializationSettingsAndroid = AndroidInitializationSettings('@mipmap/ic_launcher');
    const InitializationSettings initializationSettings = InitializationSettings(android: initializationSettingsAndroid);
    await flutterLocalNotificationsPlugin.initialize(initializationSettings);

    // Handle foreground messages
    FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
      print('Received foreground message: ${message.notification?.title}');
      print('Message data: ${message.data}');
      
      // Only show local notification for staff roles (not ministers)
      // You may want to further filter by notification type if needed
      if (message.notification != null) {
        const AndroidNotificationDetails androidPlatformChannelSpecifics = AndroidNotificationDetails(
          'vip_staff_channel',
          'VIP Staff Notifications',
          channelDescription: 'Notifications for staff session events',
          importance: Importance.max,
          priority: Priority.high,
          ticker: 'ticker',
        );
        const NotificationDetails platformChannelSpecifics = NotificationDetails(android: androidPlatformChannelSpecifics);
        await flutterLocalNotificationsPlugin.show(
          message.notification.hashCode,
          message.notification?.title ?? 'VIP Lounge',
          message.notification?.body ?? '',
          platformChannelSpecifics,
          payload: jsonEncode(message.data),
        );
      }
      // We don't show a local notification, but we need to ensure the bottom bar notification count is updated
      // This will be handled by the notification listener in the appropriate screen
    });

    // Listen for FCM token refresh and update Firestore
    _fcm.onTokenRefresh.listen((newToken) async {
      print('[FCM] Token refreshed: $newToken');
      // Try to update Firestore with the new token
      try {
        // Try getting context via Provider if available (safe fallback)
        // You may want to pass context explicitly in production
        // Here we assume user is logged in and AppAuthProvider is available
        // If not, this will silently fail
        final context = navigatorKey.currentContext;
        if (context != null) {
          final authProvider = Provider.of<AppAuthProvider>(context, listen: false);
          final user = authProvider.appUser;
          if (user != null) {
            await authProvider.updateFCMToken(newToken);
            print('[FCM] Refreshed token updated for user: ${user.id}, role: ${user.role}');
          }
        }
      } catch (e) {
        print('[FCM] Error updating refreshed token: $e');
      }
    });
  }
  
  // Store last notification payload to handle when context becomes available
  RemoteMessage? _lastRemoteMessage;
  
  // Complete initialization with context
  Future<void> completeInitialization(BuildContext context) async {
    // Handle background/terminated messages when app is opened
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      _handleRemoteMessage(context, message);
    });
    
    // Check if app was opened from a notification
    final initialMessage = await FirebaseMessaging.instance.getInitialMessage();
    if (initialMessage != null) {
      _handleRemoteMessage(context, initialMessage);
    }
    
    // Handle any stored remote message
    if (_lastRemoteMessage != null) {
      _handleRemoteMessage(context, _lastRemoteMessage!);
      _lastRemoteMessage = null;
    }
    
    // Get token and update in Firestore
    _updateFCMToken(context);
  }
  
  void _handleRemoteMessage(BuildContext context, RemoteMessage message) {
    final data = message.data;
    print('Handling remote message: ${message.messageType}');
    print('Message data: $data');
    
    // Handle different notification types
    if (data.containsKey('messageType')) {
      final messageType = data['messageType'];
      
      if (messageType == 'rating_request') {
        _openRatingScreen(context, data);
      } else if (messageType == 'chat') {
        _openChatScreen(context, data);
      } else {
        // Default handling for other notification types
        _openDefaultScreen(context, data);
      }
    } else {
      // If no message type, open default screen
      _openDefaultScreen(context, data);
    }
  }
  
  void _openRatingScreen(BuildContext context, Map<String, dynamic> data) {
    // Convert the data to the format expected by the rating screen
    final appointmentData = {
      'appointmentId': data['appointmentId'],
      'consultantId': data['consultantId'],
      'consultantName': data['consultantName'],
      'service': data['service'] ?? data['serviceName'],
      'appointmentTime': data['appointmentTime'],
      'appointmentTimeISO': data['appointmentTimeISO'],
    };
    
    // Navigate to rating screen
    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute(
        builder: (context) => ConsultantRatingScreen(appointmentData: appointmentData),
      ),
    );
  }
  
  void _openChatScreen(BuildContext context, Map<String, dynamic> data) {
    final appointmentId = data['appointmentId'];
    
    if (appointmentId != null) {
      // Navigate to minister home screen with chat open
      Navigator.of(context, rootNavigator: true).pushNamed(
        '/minister/home/chat',
        arguments: {'appointmentId': appointmentId},
      );
    }
  }
  
  void _openDefaultScreen(BuildContext context, Map<String, dynamic> data) {
    // Get user role from provider
    final authProvider = Provider.of<AppAuthProvider>(context, listen: false);
    final userRole = authProvider.appUser?.role;
    
    // Navigate based on user role
    if (userRole == 'minister') {
      Navigator.of(context, rootNavigator: true).pushNamed('/minister/home');
    } else if (userRole == 'floor_manager') {
      Navigator.of(context, rootNavigator: true).pushNamed('/floor_manager/home');
    } else if (userRole == 'consultant') {
      Navigator.of(context, rootNavigator: true).pushNamed('/consultant/home');
    } else {
      // Default route
      Navigator.of(context, rootNavigator: true).pushNamed('/');
    }
  }
  
  Future<void> _updateFCMToken(BuildContext context) async {
    try {
      final apnsToken = await _fcm.getAPNSToken();
      print('[FCM] APNS token: ' + (apnsToken ?? 'null'));
      if (apnsToken == null) {
        // APNS not ready yet; iOS may provide it shortly after permission prompt.
        print('[FCM] APNS token not set yet; will retry later.');
        return;
      }

      final token = await _fcm.getToken();
      print('FCM Token: $token');
      
      if (token != null) {
        final authProvider = Provider.of<AppAuthProvider>(context, listen: false);
        final user = authProvider.appUser;
        
        if (user != null) {
          // Update token in Firestore
          await authProvider.updateFCMToken(token);
          print('FCM token updated for user: ${user.id}, role: ${user.role}');
        }
      }
    } catch (e) {
      print('Error updating FCM token: $e');
    }
  }

  /// Send a custom FCM notification to a specific device token
  Future<void> sendCustomNotification({
    required String fcmToken,
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    try {
      final serverKey = const String.fromEnvironment('FCM_SERVER_KEY', defaultValue: 'YOUR_SERVER_KEY_HERE');
      final url = Uri.parse('https://fcm.googleapis.com/fcm/send');
      final headers = {
        'Content-Type': 'application/json',
        'Authorization': 'key=$serverKey',
      };
      final notification = {
        'title': title,
        'body': body,
      };
      final payload = {
        'to': fcmToken,
        'notification': notification,
        'data': data ?? {},
        'priority': 'high',
      };
      // Uncomment these lines if http is available in your environment:
      // final response = await http.post(url, headers: headers, body: jsonEncode(payload));
      // if (response.statusCode != 200) {
      //   throw Exception('FCM send failed: \\${response.body}');
      // }
      print('[FCM] Notification would be sent to $fcmToken: $title - $body');
    } catch (e) {
      print('[FCM] Error sending notification: $e');
    }
  }
}
