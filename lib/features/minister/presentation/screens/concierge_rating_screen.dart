import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:vip_lounge/core/widgets/Send_My_FCM.dart';
import 'package:vip_lounge/core/services/vip_notification_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../../../../core/constants/colors.dart';
import '../../../../core/providers/app_auth_provider.dart';
import '../../../../core/services/vip_notification_service.dart';

class ConciergeRatingScreen extends StatefulWidget {
  final Map<String, dynamic> appointmentData;
  
  const ConciergeRatingScreen({
    Key? key,
    required this.appointmentData,
  }) : super(key: key);

  @override
  State<ConciergeRatingScreen> createState() => _ConciergeRatingScreenState();
}

class _ConciergeRatingScreenState extends State<ConciergeRatingScreen> {
  int _rating = 0;
  String _feedback = '';
  bool _isSubmitting = false;
  bool _hasRated = false;
  final _feedbackController = TextEditingController();
  final FlutterLocalNotificationsPlugin _localNotificationsPlugin = FlutterLocalNotificationsPlugin();

  @override
  void initState() {
    super.initState();
    _initializeLocalNotifications();
    // Check if already rated
    _checkIfRated();
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
      'concierge_rating_channel',
      'Concierge Rating Notifications',
      channelDescription: 'Notifications for concierge ratings',
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

  Future<void> _checkIfRated() async {
    try {
      final appointmentId = widget.appointmentData['appointmentId']?.toString() ?? 
                         widget.appointmentData['id']?.toString();
      
      if (appointmentId == null) return;
      
      final ratingDoc = await FirebaseFirestore.instance
          .collection('ratings')
          .where('appointmentId', isEqualTo: appointmentId)
          .where('type', isEqualTo: 'concierge')
          .limit(1)
          .get();
      
      if (mounted && ratingDoc.docs.isNotEmpty) {
        setState(() {
          _hasRated = true;
          final data = ratingDoc.docs.first.data();
          _rating = data['rating'] ?? 0;
          _feedback = data['comment'] ?? '';
          _feedbackController.text = _feedback;
        });
      }
    } catch (e) {
      debugPrint('Error checking rating status: $e');
    }
  }

  @override
  void dispose() {
    _feedbackController.dispose();
    super.dispose();
  }

  Future<void> _submitRating() async {
    if (_rating == 0) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select a rating')),
        );
      }
      return;
    }
    
    setState(() {
      _isSubmitting = true;
    });
    
    try {
      final user = Provider.of<AppAuthProvider>(context, listen: false).appUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }
      
      debugPrint('[RATING_DEBUG] Appointment Data: ${widget.appointmentData}');
      
      // Get appointment ID from all possible fields
      final appointmentId = widget.appointmentData['appointmentId']?.toString() ?? 
                          widget.appointmentData['id']?.toString() ?? 
                          widget.appointmentData['appointmentID']?.toString();
      
      debugPrint('[RATING_DEBUG] Extracted appointmentId: $appointmentId');
      
      if (appointmentId == null || appointmentId.isEmpty) {
        throw Exception('appointmentId is missing or empty in appointmentData');
      }
      
      // Get reference number from appointment data
      final referenceNumber = widget.appointmentData['referenceNumber']?.toString() ?? 
                           widget.appointmentData['appointmentId']?.toString() ??
                           widget.appointmentData['id']?.toString() ??
                           'N/A';
      
      // Prepare common data
      final appointmentDate = widget.appointmentData['appointmentTime'] != null 
          ? (widget.appointmentData['appointmentTime'] is Timestamp 
              ? (widget.appointmentData['appointmentTime'] as Timestamp).toDate() 
              : DateTime.parse(widget.appointmentData['appointmentTime'].toString()))
          : DateTime.now();
      final formattedDate = DateFormat('yyyy-MM-dd HH:mm').format(appointmentDate);
      final serviceId = widget.appointmentData['serviceId'] ?? widget.appointmentData['service'] ?? 'N/A';
      final conciergeName = widget.appointmentData['conciergeName'] ?? 'Concierge';
      final conciergeId = widget.appointmentData['conciergeId'];

      // Create rating document in ratings collection with consistent field names
      await FirebaseFirestore.instance.collection('ratings').add({
        'appointmentId': appointmentId,
        'referenceNumber': referenceNumber,
        'staffId': conciergeId,
        'staffName': conciergeName,
        'role': 'concierge',
        'ministerId': user.uid,
        'ministerName': user.name,
        'rating': _rating,
        'notes': _feedback.isNotEmpty ? _feedback : null,
        'timestamp': FieldValue.serverTimestamp(),
        'type': 'Appointment Rating',
        'appointmentDate': widget.appointmentData['appointmentTime'],
      });
      
      debugPrint('[RATING] Submitted concierge rating with reference number: $referenceNumber');
      
      // Update the appointment using referenceNumber to find the correct document
      debugPrint('Updating appointment with referenceNumber: $referenceNumber');
      final appointmentQuery = await FirebaseFirestore.instance
          .collection('appointments')
          .where('referenceNumber', isEqualTo: referenceNumber)
          .limit(1)
          .get();
      
      if (appointmentQuery.docs.isNotEmpty) {
        final appointmentDoc = appointmentQuery.docs.first;
        await appointmentDoc.reference.update({
          'hasConciergeRating': true,
          'conciergeRating': _rating,
          'conciergeComment': _feedback.isNotEmpty ? _feedback : null,
          'conciergeRatedAt': FieldValue.serverTimestamp(),
          'ratingSubmittedAt': FieldValue.serverTimestamp(),
          'conciergeId': conciergeId,
          'conciergeName': conciergeName,
          'concierge_rated': true,
          'concierge_score': _rating,
        });
        debugPrint('✅ Successfully updated appointment with concierge rating');
      } else {
        debugPrint('❌ ERROR: No appointment found with referenceNumber: $referenceNumber');
        throw Exception('Appointment not found with reference number: $referenceNumber');
      }
          
      debugPrint('[RATING_DEBUG] Successfully updated appointment with concierge rating');
      
      // Notifications
      try {
        final notificationService = VipNotificationService();
        final sendMyFCM = SendMyFCM();
        
        // Original notification to concierge (unchanged)
        if (conciergeId.isNotEmpty) {
          await notificationService.createNotification(
            title: 'New Rating Received',
            body: 'You received $_rating stars from ${user.name}',
            data: {
              'type': 'concierge_rating_received',
              'appointmentId': appointmentId,
              'rating': _rating,
              'feedback': _feedback,
              'ministerName': user.name,
              'timestamp': FieldValue.serverTimestamp(),
            },
            role: 'concierge',
            assignedToId: conciergeId,
            notificationType: 'concierge_rating',
          );
        }
        
        // Notify floor managers using Send_My_FCM
        debugPrint('=== CONCIERGE RATING FLOOR MANAGER NOTIFICATION DEBUG START ===');
        debugPrint('Appointment ID: $appointmentId');
        debugPrint('Concierge ID: $conciergeId');
        debugPrint('Minister: ${user.name}');
        debugPrint('Rating: $_rating stars');
        debugPrint('Feedback: ${_feedback.isEmpty ? 'No feedback' : _feedback}');
        debugPrint('Reference Number: $referenceNumber');
        
        debugPrint('Querying floor managers from Firestore...');
        final floorManagers = await FirebaseFirestore.instance
            .collection('users')
            .where('role', isEqualTo: 'floorManager')
            .get();
            
        debugPrint('Floor managers found: ${floorManagers.docs.length}');
        
        if (floorManagers.docs.isEmpty) {
          debugPrint('WARNING: No active floor managers found in database!');
          debugPrint('Checking all users with floorManager role (including inactive)...');
          final allFloorManagers = await FirebaseFirestore.instance
              .collection('users')
              .where('role', isEqualTo: 'floorManager')
              .get();
          debugPrint('Total floor managers (active + inactive): ${allFloorManagers.docs.length}');
          for (var doc in allFloorManagers.docs) {
            final data = doc.data();
            debugPrint('Floor Manager ${doc.id}: active=${data['isActive']}, name=${data['firstName']} ${data['lastName']}');
          }
        } else {
          for (var doc in floorManagers.docs) {
            final data = doc.data();
            debugPrint('Active Floor Manager: ${doc.id} - Name: ${data['firstName']} ${data['lastName']}, Email: ${data['email']}');
          }
          // Test local notification first
          debugPrint('Testing local notification for concierge rating...');
          try {
            await _showLocalNotification(
              title: 'Test Concierge Rating Notification',
              body: 'This is a test to verify local notifications work for concierge ratings',
              payload: {'test': 'concierge_rating'},
            );
            debugPrint('✅ Local notification test successful');
          } catch (e) {
            debugPrint('❌ Local notification test failed: $e');
          }
          
          debugPrint('Starting notification loop for ${floorManagers.docs.length} floor managers...');
          for (var manager in floorManagers.docs) {
            debugPrint('Processing floor manager: ${manager.id}');
            try {
              final notificationTitle = 'New Concierge Rating';
              final notificationBody = '${user.name} rated ${widget.appointmentData['conciergeName'] ?? 'the concierge'} $_rating stars\n\nFeedback: ${_feedback.isEmpty ? 'No additional comments' : _feedback}\n\nAppointment: ${widget.appointmentData['serviceName'] ?? 'Service'} on $formattedDate\nReference: $referenceNumber';
              
              debugPrint('Notification Title: $notificationTitle');
              debugPrint('Notification Body Length: ${notificationBody.length} characters');
              debugPrint('SendMyFCM Parameters:');
              debugPrint('  - recipientId: ${manager.id}');
              debugPrint('  - appointmentId: $appointmentId');
              debugPrint('  - role: floorManager');
              debugPrint('  - rating: $_rating stars');
              
              // Send FCM notification
              debugPrint('Sending FCM notification to floor manager...');
              await sendMyFCM.sendNotification(
                recipientId: manager.id,
                title: notificationTitle,
                body: notificationBody,
                appointmentId: appointmentId,
                role: 'floorManager',
                additionalData: {
                  'type': 'concierge_rating',
                  'conciergeId': conciergeId,
                  'conciergeName': widget.appointmentData['conciergeName'] ?? 'Concierge',
                  'rating': _rating.toString(),
                  'feedback': _feedback,
                  'ministerName': user.name,
                  'referenceNumber': referenceNumber,
                  'timestamp': FieldValue.serverTimestamp().toString(),
                },
                showRating: true,
                notificationType: 'concierge_rating',
              );
              debugPrint('✅ FCM notification sent successfully');
              
              // Show local notification
              debugPrint('Sending local notification to floor manager...');
              await _showLocalNotification(
                title: notificationTitle,
                body: notificationBody,
                payload: {
                  'appointmentId': appointmentId,
                  'type': 'concierge_rating',
                  'rating': _rating.toString(),
                },
              );
              debugPrint('✅ Local notification sent successfully');
              
              debugPrint('✅ All notifications sent to floor manager: ${manager.id}');
            } catch (e) {
              debugPrint('❌ Error notifying floor manager ${manager.id}: $e');
              debugPrint('Error details: ${e.toString()}');
              if (e is Exception) {
                debugPrint('Exception type: ${e.runtimeType}');
              }
            }
          }
          
          debugPrint('=== CONCIERGE RATING FLOOR MANAGER NOTIFICATION DEBUG END ===');
        }
      } catch (e) {
        debugPrint('Error in floor manager notification process: $e');
        // Don't fail the whole operation if notification fails
      }
      
      if (mounted) {
        setState(() {
          _hasRated = true;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Thank you for your rating!')),
        );
      }
    } catch (e) {
      debugPrint('Error submitting concierge rating: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  Widget _buildInfoRow(IconData icon, String label, String value, 
      {double iconSize = 20, double horizontalPadding = 12}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.primary, size: iconSize),
          SizedBox(width: horizontalPadding),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appointment = widget.appointmentData;
    final conciergeName = appointment['conciergeName'] ?? 'Concierge';
    final service = appointment['service'] ?? 'Service';
    final appointmentTime = appointment['appointmentDate'] != null 
        ? (appointment['appointmentDate'] as Timestamp).toDate()
        : DateTime.now();

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text(
          'Rate Concierge Service',
          style: TextStyle(color: AppColors.primary),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.primary),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: _isSubmitting
          ? const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
              ),
            )
          : SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    Center(
                      child: Column(
                        children: [
                          const CircleAvatar(
                            backgroundColor: AppColors.primary,
                            radius: 40,
                            child: Icon(
                              Icons.rate_review,
                              color: Colors.black,
                              size: 40,
                            ),
                          ),
                          const SizedBox(height: 24),
                          Text(
                            'How was your experience with our concierge?',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Your feedback helps us improve our service',
                            style: TextStyle(
                              color: Colors.grey[400],
                              fontSize: 14,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 32),
                    
                    // Appointment Details
                    Card(
                      color: Colors.grey[900],
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: Colors.grey[800]!),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Appointment Details',
                              style: TextStyle(
                                color: AppColors.primary,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 12),
                            _buildInfoRow(
                              Icons.person_outline,
                              'Concierge',
                              conciergeName,
                            ),
                            _buildInfoRow(
                              Icons.calendar_today,
                              'Date',
                              DateFormat('EEEE, MMM d, y').format(appointmentTime),
                            ),
                            _buildInfoRow(
                              Icons.access_time,
                              'Time',
                              DateFormat('h:mm a').format(appointmentTime),
                            ),
                            if (service.isNotEmpty)
                              _buildInfoRow(
                                Icons.spa,
                                'Service',
                                service,
                              ),
                          ],
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 32),
                    
                    // Rating Section
                    const Text(
                      'Rate your experience with the concierge',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // Star Rating
                    Center(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(5, (index) {
                          return IconButton(
                            onPressed: _hasRated
                                ? null
                                : () {
                                    setState(() {
                                      _rating = index + 1;
                                    });
                                  },
                            icon: Icon(
                              index < _rating ? Icons.star : Icons.star_border,
                              color: _hasRated ? Colors.grey : AppColors.primary,
                              size: 40,
                            ),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          );
                        }),
                      ),
                    ),
                    
                    const SizedBox(height: 8),
                    
                    Center(
                      child: Text(
                        _hasRated ? 'Thank you for your rating!' : 'Tap a star to rate',
                        style: TextStyle(
                          color: _hasRated ? Colors.green : Colors.grey[400],
                          fontSize: 14,
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 32),
                    
                    // Feedback Section
                    const Text(
                      'Additional Feedback (Optional)',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    
                    const SizedBox(height: 12),
                    
                    TextField(
                      controller: _feedbackController,
                      enabled: !_hasRated,
                      maxLines: 4,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'Tell us about your experience...',
                        hintStyle: TextStyle(color: Colors.grey[600]),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: Colors.grey[700]!),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: Colors.grey[700]!),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: AppColors.primary),
                        ),
                        filled: true,
                        fillColor: Colors.grey[900],
                        contentPadding: const EdgeInsets.all(16),
                      ),
                      onChanged: (value) {
                        setState(() {
                          _feedback = value;
                        });
                      },
                    ),
                    
                    const SizedBox(height: 40),
                    
                    // Submit Button
                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: ElevatedButton(
                        onPressed: _hasRated || _isSubmitting ? null : _submitRating,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _hasRated ? Colors.green : AppColors.primary,
                          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: _isSubmitting
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (_hasRated) 
                                    const Icon(Icons.check_circle, color: Colors.white, size: 20),
                                  const SizedBox(width: 8),
                                  Text(
                                    _hasRated ? 'Concierge Rated' : 'Submit Rating',
                                    style: TextStyle(
                                      color: _hasRated ? Colors.white : Colors.black,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ),
                    
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
    );
  }
}
