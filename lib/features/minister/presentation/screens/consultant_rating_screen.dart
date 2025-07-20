import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:vip_lounge/core/widgets/Send_My_FCM.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../../../../core/constants/colors.dart';
import '../../../../core/providers/app_auth_provider.dart';
import '../../../../core/services/vip_notification_service.dart';
import '../../../../core/services/notification_service.dart';

class ConsultantRatingScreen extends StatefulWidget {
  final Map<String, dynamic> appointmentData;
  
  const ConsultantRatingScreen({
    Key? key,
    required this.appointmentData,
  }) : super(key: key);

  @override
  State<ConsultantRatingScreen> createState() => _ConsultantRatingScreenState();
}

class _ConsultantRatingScreenState extends State<ConsultantRatingScreen> {
  int _rating = 0;
  String _feedback = '';
  bool _isSubmitting = false;
  final _feedbackController = TextEditingController();
  final FlutterLocalNotificationsPlugin _localNotificationsPlugin = FlutterLocalNotificationsPlugin();

  @override
  void initState() {
    super.initState();
    _initializeLocalNotifications();
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
      'consultant_rating_channel',
      'Consultant Rating Notifications',
      channelDescription: 'Notifications for consultant ratings',
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

  @override
  void dispose() {
    _feedbackController.dispose();
    super.dispose();
  }

  Future<void> _submitRating() async {
    if (_rating == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please select a rating')),
      );
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
      
      final appointmentId = widget.appointmentData['appointmentId'];
      final consultantId = widget.appointmentData['consultantId'];
      
      // Prepare common data
      final appointmentDate = widget.appointmentData['appointmentTime'] != null 
          ? (widget.appointmentData['appointmentTime'] is Timestamp 
              ? (widget.appointmentData['appointmentTime'] as Timestamp).toDate() 
              : DateTime.parse(widget.appointmentData['appointmentTime'].toString()))
          : DateTime.now();
      final formattedDate = DateFormat('yyyy-MM-dd HH:mm').format(appointmentDate);
      final serviceId = widget.appointmentData['serviceId'] ?? widget.appointmentData['service'] ?? 'N/A';
      final referenceNumber = widget.appointmentData['referenceNumber']?.toString() ?? '';
      final consultantName = widget.appointmentData['consultantName'] ?? 'Consultant';

      // Save the rating to Firestore
      await FirebaseFirestore.instance.collection('ratings').add({
        'appointmentId': appointmentId,
        'consultantId': consultantId,
        'ministerId': user.id,
        'ministerName': user.name,
        'rating': _rating,
        'notes': _feedback,
        'timestamp': FieldValue.serverTimestamp(),
        'type': 'Appointment Rating',
        'appointmentDate': widget.appointmentData['appointmentTime'],
      });
      
      print('[RATING] Submitted rating with reference number: ${widget.appointmentData['referenceNumber']}');
      
      // Update the appointment using referenceNumber to find the correct document
      print('Updating appointment with referenceNumber: $referenceNumber');
      final appointmentQuery = await FirebaseFirestore.instance
          .collection('appointments')
          .where('referenceNumber', isEqualTo: referenceNumber)
          .limit(1)
          .get();
      
      if (appointmentQuery.docs.isNotEmpty) {
        final appointmentDoc = appointmentQuery.docs.first;
        await appointmentDoc.reference.update({
          'isRated': true,
          'rating': _rating,
          'ratingSubmittedAt': FieldValue.serverTimestamp(),
          'consultantId': consultantId,
          'consultantName': consultantName,
          'consultant_rated': true,
          'consultant_score': _rating,
          'consultant_comments': _feedback.isNotEmpty ? _feedback : null,
        });
        print('✅ Successfully updated appointment with consultant rating');
      } else {
        print('❌ ERROR: No appointment found with referenceNumber: $referenceNumber');
        throw Exception('Appointment not found with reference number: $referenceNumber');
      }
      
      // Notify floor manager about the rating using Send_My_FCM
      try {
        final notificationService = VipNotificationService();
        final sendMyFCM = SendMyFCM();
        
        // Original notification to consultant (unchanged)
        await notificationService.createNotification(
          title: 'New Rating Received',
          body: 'You received $_rating stars from ${user.name}',
          data: {
            'type': 'consultant_rating_received',
            'appointmentId': appointmentId,
            'rating': _rating,
            'feedback': _feedback,
            'ministerName': user.name,
            'timestamp': FieldValue.serverTimestamp(),
          },
          role: 'consultant',
          assignedToId: consultantId,
          notificationType: 'consultant_rating',
        );
        
        // New notification to floor managers using Send_My_FCM
        print('=== CONSULTANT RATING FLOOR MANAGER NOTIFICATION DEBUG START ===');
        print('Appointment ID: $appointmentId');
        print('Consultant ID: $consultantId');
        print('Minister: ${user.name}');
        print('Rating: $_rating stars');
        print('Feedback: ${_feedback.isEmpty ? 'No feedback' : _feedback}');
        print('Reference Number: $referenceNumber');
        
        print('Querying floor managers from Firestore...');
        final floorManagers = await FirebaseFirestore.instance
            .collection('users')
            .where('role', isEqualTo: 'floorManager')
            .get();
            
        print('Floor managers found: ${floorManagers.docs.length}');
        
        if (floorManagers.docs.isEmpty) {
          print('WARNING: No active floor managers found in database!');
          print('Checking all users with floorManager role (including inactive)...');
          final allFloorManagers = await FirebaseFirestore.instance
              .collection('users')
              .where('role', isEqualTo: 'floorManager')
              .get();
          print('Total floor managers (active + inactive): ${allFloorManagers.docs.length}');
          for (var doc in allFloorManagers.docs) {
            final data = doc.data();
            print('Floor Manager ${doc.id}: active=${data['isActive']}, name=${data['firstName']} ${data['lastName']}');
          }
        } else {
          for (var doc in floorManagers.docs) {
            final data = doc.data();
            print('Active Floor Manager: ${doc.id} - Name: ${data['firstName']} ${data['lastName']}, Email: ${data['email']}');
          }
          // Test local notification first
          print('Testing local notification for consultant rating...');
          try {
            await _showLocalNotification(
              title: 'Test Consultant Rating Notification',
              body: 'This is a test to verify local notifications work for consultant ratings',
              payload: {'test': 'consultant_rating'},
            );
            print('✅ Local notification test successful');
          } catch (e) {
            print('❌ Local notification test failed: $e');
          }
          
          print('Starting notification loop for ${floorManagers.docs.length} floor managers...');
          for (var manager in floorManagers.docs) {
            print('Processing floor manager: ${manager.id}');
            try {
              final notificationTitle = 'New Consultant Rating';
              final notificationBody = '${user.name} rated ${widget.appointmentData['consultantName'] ?? 'a consultant'} $_rating stars\n\nFeedback: ${_feedback.isEmpty ? 'No additional comments' : _feedback}\n\nAppointment: ${widget.appointmentData['serviceName'] ?? 'Service'} on $formattedDate\nReference: $referenceNumber';
              
              print('Notification Title: $notificationTitle');
              print('Notification Body Length: ${notificationBody.length} characters');
              print('SendMyFCM Parameters:');
              print('  - recipientId: ${manager.id}');
              print('  - appointmentId: $appointmentId');
              print('  - role: floorManager');
              print('  - rating: $_rating stars');
              
              // Send FCM notification
              print('Sending FCM notification to floor manager...');
              await sendMyFCM.sendNotification(
                recipientId: manager.id,
                title: notificationTitle,
                body: notificationBody,
                appointmentId: appointmentId,
                role: 'floorManager',
                additionalData: {
                  'type': 'consultant_rating',
                  'consultantId': consultantId,
                  'consultantName': widget.appointmentData['consultantName'] ?? 'Consultant',
                  'rating': _rating.toString(),
                  'feedback': _feedback,
                  'ministerName': user.name,
                  'referenceNumber': referenceNumber,
                  'timestamp': FieldValue.serverTimestamp().toString(),
                },
                showRating: true,
                notificationType: 'consultant_rating',
              );
              print('✅ FCM notification sent successfully');
              
              // Show local notification
              print('Sending local notification to floor manager...');
              await _showLocalNotification(
                title: notificationTitle,
                body: notificationBody,
                payload: {
                  'appointmentId': appointmentId,
                  'type': 'consultant_rating',
                  'rating': _rating.toString(),
                },
              );
              print('✅ Local notification sent successfully');
              
              print('✅ All notifications sent to floor manager: ${manager.id}');
            } catch (e) {
              print('❌ Error notifying floor manager ${manager.id}: $e');
              print('Error details: ${e.toString()}');
              if (e is Exception) {
                print('Exception type: ${e.runtimeType}');
              }
            }
          }
          
          print('=== CONSULTANT RATING FLOOR MANAGER NOTIFICATION DEBUG END ===');
        }
      } catch (e) {
        print('Error in notification process: $e');
        // Don't fail the whole operation if notification fails
      }
      
      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Rating submitted successfully')),
        );
        
        // Navigate back
        Navigator.of(context).pop(true);
      }
      
    } catch (e) {
      print('Error submitting rating: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error submitting rating: $e')),
      );
    } finally {
      setState(() {
        _isSubmitting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Get appointment details
    final String consultantName = widget.appointmentData['consultantName'] ?? 'Consultant';
    final String service = widget.appointmentData['service'] ?? widget.appointmentData['serviceName'] ?? 'Consultation';
    DateTime appointmentTime;
    
    if (widget.appointmentData['appointmentTime'] is Timestamp) {
      appointmentTime = (widget.appointmentData['appointmentTime'] as Timestamp).toDate();
    } else if (widget.appointmentData['appointmentTimeISO'] != null) {
      appointmentTime = DateTime.parse(widget.appointmentData['appointmentTimeISO']);
    } else {
      appointmentTime = DateTime.now();
    }
    
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: Text(
          'Rate Your Experience',
          style: TextStyle(color: AppColors.primary),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: AppColors.primary),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: _isSubmitting
          ? Center(child: CircularProgressIndicator(color: AppColors.primary))
          : SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: CircleAvatar(
                        backgroundColor: AppColors.primary,
                        radius: 40,
                        child: Icon(
                          Icons.rate_review,
                          color: Colors.black,
                          size: 40,
                        ),
                      ),
                    ),
                    SizedBox(height: 24),
                    Center(
                      child: Text(
                        'How was your experience?',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    SizedBox(height: 8),
                    Center(
                      child: Text(
                        'Please rate the service provided by $consultantName',
                        style: TextStyle(
                          color: Colors.grey,
                          fontSize: 16,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    SizedBox(height: 32),
                    
                    // Appointment details
                    Card(
                      color: Colors.black,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(color: AppColors.primary.withOpacity(0.3)),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Appointment Details',
                              style: TextStyle(
                                color: AppColors.primary,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(height: 16),
                            _buildInfoRow(
                              Icons.person,
                              'Consultant',
                              consultantName,
                            ),
                            SizedBox(height: 8),
                            _buildInfoRow(
                              Icons.spa,
                              'Service',
                              service,
                            ),
                            SizedBox(height: 8),
                            _buildInfoRow(
                              Icons.calendar_today,
                              'Date',
                              DateFormat('EEEE, MMMM d, y').format(appointmentTime),
                            ),
                          ],
                        ),
                      ),
                    ),
                    
                    SizedBox(height: 32),
                    
                    // Rating Stars
                    Text(
                      'Your Rating',
                      style: TextStyle(
                        color: AppColors.primary,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 16),
                    Center(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(5, (index) {
                          final starValue = index + 1;
                          return IconButton(
                            icon: Icon(
                              starValue <= _rating ? Icons.star : Icons.star_border,
                              color: starValue <= _rating ? AppColors.primary : Colors.grey,
                              size: 40,
                            ),
                            onPressed: () {
                              setState(() {
                                _rating = starValue;
                              });
                            },
                          );
                        }),
                      ),
                    ),
                    
                    SizedBox(height: 32),
                    
                    // Feedback field
                    Text(
                      'Additional Feedback (Optional)',
                      style: TextStyle(
                        color: AppColors.primary,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 16),
                    TextField(
                      controller: _feedbackController,
                      style: TextStyle(color: Colors.white),
                      maxLines: 5,
                      decoration: InputDecoration(
                        hintText: 'Please share your thoughts about the service...',
                        hintStyle: TextStyle(color: Colors.grey),
                        filled: true,
                        fillColor: Colors.grey[900],
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: AppColors.primary),
                        ),
                      ),
                      onChanged: (value) {
                        setState(() {
                          _feedback = value;
                        });
                      },
                    ),
                    
                    SizedBox(height: 40),
                    
                    // Submit button
                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: ElevatedButton(
                        onPressed: _submitRating,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: Text(
                          'SUBMIT RATING',
                          style: TextStyle(
                            color: Colors.black,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                    
                    SizedBox(height: 24),
                  ],
                ),
              ),
            ),
    );
  }
  
  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: AppColors.primary, size: 18),
        SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
              Text(
                value,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
