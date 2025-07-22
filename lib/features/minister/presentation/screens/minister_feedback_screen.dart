import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:vip_lounge/core/providers/app_auth_provider.dart';
import 'package:vip_lounge/core/services/vip_notification_service.dart';
import 'package:vip_lounge/core/widgets/Send_My_FCM.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:intl/intl.dart';

class MinisterFeedbackScreen extends StatefulWidget {
  final String appointmentId;
  final String ministerId;
  const MinisterFeedbackScreen({Key? key, required this.appointmentId, required this.ministerId}) : super(key: key);

  @override
  State<MinisterFeedbackScreen> createState() => _MinisterFeedbackScreenState();
}

class _MinisterFeedbackScreenState extends State<MinisterFeedbackScreen> {
  List<Map<String, dynamic>> _questions = [];
  List<Map<String, dynamic>> _options = [];
  final Map<String, int> _responses = {};
  String _comment = '';
  bool _isSubmitting = false;
  bool _loading = true;
  bool _feedbackSubmitted = false;
  final FlutterLocalNotificationsPlugin _localNotificationsPlugin = FlutterLocalNotificationsPlugin();

  @override
  void initState() {
    super.initState();
    _initializeLocalNotifications();
    _fetchQuestions();
  }
  
  Future<void> _initializeLocalNotifications() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    
    const InitializationSettings initializationSettings =
        InitializationSettings(android: initializationSettingsAndroid);
    
    await _localNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        // Handle notification tap
      },
    );
  }
  
  Future<void> _showLocalNotification({
    required String title,
    required String body,
    Map<String, dynamic>? payload,
  }) async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'feedback_channel',
      'Feedback Notifications',
      channelDescription: 'Notifications for minister feedback',
      importance: Importance.max,
      priority: Priority.high,
      showWhen: true,
      enableVibration: true,
    );
    
    const NotificationDetails platformChannelSpecifics = 
        NotificationDetails(android: androidPlatformChannelSpecifics);
    
    await _localNotificationsPlugin.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000, // Unique ID based on timestamp
      title,
      body,
      platformChannelSpecifics,
      payload: payload != null ? payload.toString() : null,
    );
  }

  Future<void> _fetchQuestions() async {
    try {
      setState(() => _loading = true);
      
      final questionsSnap = await FirebaseFirestore.instance
          .collection('Feedback_questions')
          .get();
          
      final optionsSnap = await FirebaseFirestore.instance
          .collection('Feedback_options')
          .orderBy('score')
          .get();
          
      setState(() {
        _questions = questionsSnap.docs.map((doc) {
          final data = doc.data();
          data['docId'] = doc.id;
          return data;
        }).toList();
        
        _options = optionsSnap.docs.map((doc) => doc.data()).toList();
        _loading = false;
      });
      
      print('Fetched ${_questions.length} questions and ${_options.length} options');
    } catch (e) {
      print('Error fetching questions: $e');
      setState(() => _loading = false);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading questions: $e')),
        );
      }
    }
  }

  void _setResponse(String qId, int score) {
    setState(() {
      _responses[qId] = score;
    });
  }

  Future<void> _submit() async {
    if (_isSubmitting) return;
    
    // Validate responses
    if (_responses.length != _questions.length) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please answer all questions')),
        );
      }
      return;
    }
    
    setState(() => _isSubmitting = true);
    
    final notificationService = VipNotificationService();
    
    try {
      // Fetch appointment details
      final appointmentDoc = await FirebaseFirestore.instance
          .collection('appointments')
          .doc(widget.appointmentId)
          .get();
          
      if (!appointmentDoc.exists) {
        throw Exception('Appointment not found');
      }
      
      final appointment = appointmentDoc.data() ?? {};
      
      // Calculate total score (1-based indexing as requested)
      int totalScore = 0;
      List<Map<String, dynamic>> questionResponses = [];
      
      for (final entry in _responses.entries) {
        final qId = entry.key;
        final score = entry.value;
        final question = _questions.firstWhere(
          (q) => (q['docId'] ?? q['id'] ?? '').toString() == qId,
          orElse: () => {'text': 'Question not found'},
        );
        
        final option = _options.firstWhere(
          (opt) => opt['score'] == score,
          orElse: () => {'label': 'Unknown', 'score': score},
        );
        
        // Convert to 1-based indexing (score + 1)
        final selectedOption = score + 1;
        totalScore += selectedOption;
        
        questionResponses.add({
          'questionLabel': question['text'] ?? question['question'] ?? 'Question',
          'text': _comment, // User input as comments
          'selectedOption': selectedOption, // 1-based indexing
        });
      }
      
      // Create single VIP_feedback document with all required fields
      final vipFeedbackData = {
        'referenceNumber': appointment['referenceNumber'] ?? '',
        'ministerName': '${appointment['ministerFirstName'] ?? ''} ${appointment['ministerLastName'] ?? ''}'.trim(),
        'typeOfUser': appointment['typeOfVip'] ?? 'Standard',
        'appointmentDateTime': appointment['appointmentTime'],
        'feedbackCreatedAt': FieldValue.serverTimestamp(),
        'consultantName': appointment['consultantName'] ?? 'Not assigned',
        'conciergeName': appointment['conciergeName'] ?? 'Not assigned',
        'questionResponses': questionResponses,
        'totalScore': totalScore,
        'numberOfQuestions': _questions.length,
      };
      
      // Save to VIP_feedback collection (single write)
      await FirebaseFirestore.instance
          .collection('VIP_feedback')
          .add(vipFeedbackData);

      // Prepare notification data
      final notificationData = {
        'appointmentId': widget.appointmentId,
        'referenceNumber': appointment['referenceNumber'] ?? '',
        'type': 'feedback_submitted',
        'feedbackType': 'minister_experience',
        'ministerId': widget.ministerId,
        'ministerName': '${appointment['ministerFirstName'] ?? ''} ${appointment['ministerLastName'] ?? ''}'.trim(),
        'consultantName': appointment['consultantName'] ?? 'Not assigned',
        'consultantId': appointment['consultantId'] ?? '',
        'venueName': appointment['venueName'] ?? '',
        'serviceName': appointment['serviceName'] ?? '',
        'appointmentTime': appointment['appointmentTime'] is Timestamp 
            ? (appointment['appointmentTime'] as Timestamp).toDate().toIso8601String()
            : FieldValue.serverTimestamp(),
        'responses': _responses,
        'comment': _comment,
        'createdAt': FieldValue.serverTimestamp(),
      };
      
      // Build a formatted string of questions and selected options
      String buildFeedbackDetails() {
        final buffer = StringBuffer();
        buffer.writeln('Feedback Details:');
        buffer.writeln('-----------------');
        
        _questions.asMap().forEach((index, question) {
          final questionId = question['docId'] ?? index.toString();
          final response = _responses[questionId];
          
          if (response != null) {
            final option = _options.firstWhere(
              (opt) => opt['score'] == response,
              orElse: () => {'label': 'Not rated'},
            );
            
            buffer.writeln('${index + 1}. ${question['text'] ?? question['question']}');
            buffer.writeln('   → ${option['label']} (${option['score']})');
            buffer.writeln();
          }
        });
        
        if (_comment.isNotEmpty) {
          buffer.writeln('Additional Comments:');
          buffer.writeln('-------------------');
          buffer.writeln(_comment);
        }
        
        return buffer.toString();
      }
      
      // Send notifications using SendMyFCM
      final sendMyFCM = SendMyFCM();
      
      print('=== FEEDBACK NOTIFICATION DEBUG START ===');
      print('Appointment ID: ${widget.appointmentId}');
      print('Minister ID: ${widget.ministerId}');
      print('Notification Data: $notificationData');
      
      // Query all floor managers and send notification to each
      print('Querying floor managers from Firestore...');
      final floorManagerQuery = await FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'floorManager')
          .get();
          
      print('Floor managers found: ${floorManagerQuery.docs.length}');
      
      if (floorManagerQuery.docs.isEmpty) {
        print('WARNING: No floor managers found in database!');
        print('Checking all users with any role...');
        final allUsersQuery = await FirebaseFirestore.instance
            .collection('users')
            .get();
        print('Total users in database: ${allUsersQuery.docs.length}');
        for (var doc in allUsersQuery.docs) {
          final data = doc.data();
          print('User ${doc.id}: role=${data['role']}, name=${data['firstName']} ${data['lastName']}');
        }
      }
          
      final floorManagerUids = floorManagerQuery.docs
          .map((doc) => doc.id)
          .where((uid) => uid != null && uid.isNotEmpty)
          .cast<String>()
          .toList();
          
      print('Floor Manager UIDs extracted: ${floorManagerUids.join(', ')}');
      
      for (var doc in floorManagerQuery.docs) {
        final data = doc.data();
        print('Floor Manager Details: ${doc.id} - Name: ${data['firstName']} ${data['lastName']}, Email: ${data['email']}, Active: ${data['isActive']}');
      }
      
      // Test local notification first
      print('Testing local notification...');
      try {
        await _showLocalNotification(
          title: 'Test Local Notification',
          body: 'This is a test to verify local notifications work',
          payload: {'test': 'true'},
        );
        print('✅ Local notification test successful');
      } catch (e) {
        print('❌ Local notification test failed: $e');
      }
      
      // Send to floor managers
      print('Starting notification loop for ${floorManagerUids.length} floor managers...');
      for (var floorManagerUid in floorManagerUids) {
        print('Processing floor manager: $floorManagerUid');
        try {
          // Send using SendMyFCM
          final notificationTitle = 'New Feedback Received';
          final notificationBody = '${notificationData['ministerName']} has provided feedback for their appointment.\n\n${buildFeedbackDetails()}';
          
          print('Notification Title: $notificationTitle');
          print('Notification Body Length: ${notificationBody.length} characters');
          print('SendMyFCM Parameters:');
          print('  - recipientId: $floorManagerUid');
          print('  - appointmentId: ${widget.appointmentId}');
          print('  - role: floorManager');
          
          // Send FCM notification
          print('Sending FCM notification...');
          await sendMyFCM.sendNotification(
            recipientId: floorManagerUid,
            title: notificationTitle,
            body: notificationBody,
            appointmentId: widget.appointmentId,
            role: 'floorManager',
            additionalData: {
              ...notificationData,
              'notificationType': 'feedback_submitted',
              'click_action': 'FLUTTER_NOTIFICATION_CLICK',
              'feedbackDetails': buildFeedbackDetails(),
            },
            showRating: false,
            notificationType: 'feedback_submitted',
          );
          print('✅ FCM notification sent successfully');
          
          // Show local notification
          print('Sending local notification...');
          await _showLocalNotification(
            title: notificationTitle,
            body: notificationBody,
            payload: {
              'appointmentId': widget.appointmentId,
              'type': 'feedback_submitted',
            },
          );
          print('✅ Local notification sent successfully');
          
          print('✅ All notifications sent to floor manager: $floorManagerUid');
        } catch (e) {
          print('❌ Error sending notifications to floor manager $floorManagerUid: $e');
          print('Error details: ${e.toString()}');
          if (e is Exception) {
            print('Exception type: ${e.runtimeType}');
          }
        }
      }
      
      print('=== FEEDBACK NOTIFICATION DEBUG END ===');

      // Send to consultant if available
      final consultantId = appointment['consultantId']?.toString();
      if (consultantId != null && consultantId.isNotEmpty) {
        try {
          final consultantTitle = 'New Feedback on Your Service';
          final consultantBody = 'You have received new feedback from ${notificationData['ministerName']}.\n\n${buildFeedbackDetails()}';
          
          await sendMyFCM.sendNotification(
            recipientId: consultantId,
            title: consultantTitle,
            body: consultantBody,
            appointmentId: widget.appointmentId,
            role: 'consultant',
            additionalData: {
              ...notificationData,
              'notificationType': 'consultant_feedback',
              'click_action': 'FLUTTER_NOTIFICATION_CLICK',
              'feedbackDetails': buildFeedbackDetails(),
            },
            showRating: false,
            notificationType: 'consultant_feedback',
          );
          
          // Show local notification for consultant
          await _showLocalNotification(
            title: consultantTitle,
            body: consultantBody,
            payload: {
              'appointmentId': widget.appointmentId,
              'type': 'consultant_feedback',
            },
          );
          print('FCM notification sent to consultant: $consultantId');
        } catch (e) {
          print('Error notifying consultant: $e');
        }
      }

      // Update UI state
      setState(() {
        _isSubmitting = false;
        _feedbackSubmitted = true;
      });

      if (mounted) {
        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Thank you for your feedback!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          )
        );
        
        // Wait for the snackbar to show, then pop back to previous screen
        await Future.delayed(const Duration(seconds: 2));
        
        if (mounted) {
          Navigator.of(context).pop(true);
        }
      }
    } catch (e) {
      print('Error in feedback submission: $e');
      setState(() => _isSubmitting = false);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error submitting feedback. Please try again.'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          )
        );
      }
    }
  }

  // Build a single question with radio options
  Widget _buildQuestion(int index, Map<String, dynamic> question) {
    final questionId = question['docId'] ?? index.toString();
    
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${index + 1}. ${question['text'] ?? question['question'] ?? 'Question ${index + 1}'}',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 12),
            
            // Rating options
            Column(
              children: _options.map((option) {
                return RadioListTile<int>(
                  title: Text(option['label'] ?? 'Option ${option['score']}'),
                  value: option['score'],
                  groupValue: _responses[questionId],
                  onChanged: (value) {
                    if (value != null) {
                      _setResponse(questionId, value);
                    }
                  },
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_feedbackSubmitted) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.check_circle, color: Colors.green, size: 80),
                const SizedBox(height: 24),
                const Text(
                  'Thank You for Your Feedback!',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Your feedback has been submitted successfully.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                ),
                const SizedBox(height: 32),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text('Back to Home'),
                ),
              ],
            ),
          ),
        ),
      );
    }
    
    if (_loading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Rate Your Experience'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Please rate your experience',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            
            // Questions List
            ..._questions.asMap().entries.map((entry) => _buildQuestion(entry.key, entry.value)).toList(),
            
            // Comment field
            const SizedBox(height: 16),
            const Text(
              'Additional Comments (Optional)',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            TextField(
              maxLines: 4,
              decoration: const InputDecoration(
                hintText: 'Enter your comments here...',
                border: OutlineInputBorder(),
              ),
              onChanged: (value) {
                setState(() {
                  _comment = value;
                });
              },
            ),
            
            // Submit button
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).primaryColor,
                  foregroundColor: Colors.white,
                ),
                child: _isSubmitting
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text(
                        'Submit Feedback',
                        style: TextStyle(fontSize: 16),
                      ),
              ),
            ),
            
            if (_isSubmitting) ...[
              const SizedBox(height: 16),
              const Center(
                child: Text(
                  'Submitting your feedback...',
                  style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
