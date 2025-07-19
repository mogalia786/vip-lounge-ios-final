import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:vip_lounge/core/providers/app_auth_provider.dart';
import 'package:vip_lounge/core/services/vip_notification_service.dart';
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
  Map<String, int> _responses = {};
  String _comment = '';
  bool _isSubmitting = false;
  bool _loading = true;
  bool _feedbackSubmitted = false;

  @override
  void initState() {
    super.initState();
    _fetchQuestions();
  }

  Future<void> _fetchQuestions() async {
    setState(() => _loading = true);
    final questionsSnap = await FirebaseFirestore.instance.collection('Feedback_questions').get();
final questionDocs = questionsSnap.docs;

    final optionsSnap = await FirebaseFirestore.instance.collection('Feedback_options').orderBy('score').get();
    final options = optionsSnap.docs.map((d) => d.data()).toList();
    setState(() {
      // Store each question as a map with its Firestore doc id as 'docId'
      _questions = questionDocs.map((d) {
        final data = d.data();
        data['docId'] = d.id;
        return data;
      }).toList();
      _options = options;
      _loading = false;
    });
  }

  void _setResponse(String qId, int score) {
    setState(() {
      _responses[qId] = score;
    });
  }

  Future<void> _submit() async {
    print('[FEEDBACK SUBMIT] _submit called');
    setState(() => _isSubmitting = true);
    
    // Initialize notification service
    final notificationService = VipNotificationService();
    print('[DEBUG] Notification service initialized');
    
    try {
      // Fetch appointment details for staff info
      final appointmentDoc = await FirebaseFirestore.instance
          .collection('appointments')
          .doc(widget.appointmentId)
          .get();
          
      if (!appointmentDoc.exists) {
        throw Exception('Appointment not found');
      }
      
      final appointment = appointmentDoc.data() ?? {};
      final floorManagerId = appointment['floorManagerId']?.toString();
      
      // Enhanced responses with question and option details
      final enhancedResponses = _responses.entries.map((entry) {
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
        
        return {
          'questionId': qId,
          'questionText': question['text'] ?? question['question'] ?? 'Question',
          'responseScore': score,
          'responseLabel': option['label'] ?? 'Score: $score',
          'maxScore': _options.isNotEmpty ? _options.last['score'] : 5, // Assuming highest score is last
          // Removed timestamp from array items as it's not supported
        };
      }).toList();
      
      // Calculate average score for quick reference
      final averageScore = _responses.isNotEmpty 
          ? _responses.values.reduce((a, b) => a + b) / _responses.length
          : 0;
      
      // Prepare feedback data with staff/booking details
      final feedbackData = {
        'appointmentId': widget.appointmentId,
        'referenceNumber': appointment['referenceNumber'] ?? '',
        'ministerId': widget.ministerId,
        'responses': _responses, // Keep original for backward compatibility
        'enhancedResponses': enhancedResponses, // New enhanced format
        'averageScore': averageScore,
        'totalQuestions': _questions.length,
        'questionsVersion': '1.0', // Version identifier for future schema changes
        'comment': _comment,
        'createdAt': FieldValue.serverTimestamp(),
        'consultantId': appointment['consultantId'],
        'consultantName': appointment['consultantName'],
        'conciergeId': appointment['conciergeId'],
        'conciergeName': appointment['conciergeName'],
        'cleanerId': appointment['cleanerId'],
        'cleanerName': appointment['cleanerName'],
        'floorManagerId': floorManagerId,
        'floorManagerName': appointment['floorManagerName'],
        'venueId': appointment['venueId'],
        'venueName': appointment['venueName'],
        'serviceId': appointment['serviceId'],
        'serviceName': appointment['serviceName'],
        'appointmentTime': appointment['appointmentTime'],
        'appointmentTimeFormatted': appointment['appointmentTime'] is Timestamp
            ? DateFormat('EEEE, MMMM d, yyyy h:mm a')
                .format((appointment['appointmentTime'] as Timestamp).toDate())
            : '',
        'status': 'feedback_submitted',
      };

      // Save feedback to Firestore
      await FirebaseFirestore.instance.collection('Client_feedback').add(feedbackData);
      
      // Update appointment status to show feedback was submitted
      await FirebaseFirestore.instance.collection('appointments').doc(widget.appointmentId).update({
        'status': 'feedback_submitted',
        'feedbackSubmitted': true,
        'feedbackSubmittedAt': FieldValue.serverTimestamp(),
        'lastUpdated': FieldValue.serverTimestamp(),
      });

      // Send notification to floor manager if available
      if (floorManagerId != null && floorManagerId.isNotEmpty) {
        print('[FEEDBACK] Sending notification to floor manager: $floorManagerId');
        
        final notificationTitle = 'New Feedback Submitted';
        final notificationBody = 'A minister has submitted feedback for a completed booking.';
        
        // Prepare notification data matching the rating notification pattern
        final notificationData = {
          'appointmentId': widget.appointmentId,
          'referenceNumber': appointment['referenceNumber'] ?? '', // Add reference number
          'type': 'feedback_submitted',
          'feedbackType': 'minister_experience',
          'ministerId': widget.ministerId,
          'consultantName': appointment['consultantName'] ?? '',
          'consultantId': appointment['consultantId'] ?? '',
          'venueName': appointment['venueName'] ?? '',
          'serviceName': appointment['serviceName'] ?? '',
          'appointmentTime': appointment['appointmentTime'],
          'appointmentTimeFormatted': feedbackData['appointmentTimeFormatted'],
          'responses': _responses,
          'comment': _comment,
          'showRating': false, // No need to show rating for feedback notifications
        };
        
        print('[FEEDBACK] Sending notification with data: $notificationData');
        
        try {
          // Use VipNotificationService to send notification (same as rating notifications)
          await notificationService.createNotification(
            title: notificationTitle,
            body: notificationBody,
            data: notificationData,
            role: 'floor_manager',
            assignedToId: floorManagerId,
            notificationType: 'feedback_submitted',
          );
          
          print('[FEEDBACK] Notification sent successfully');
          
          // Also send notification to consultant if available
          final consultantId = appointment['consultantId']?.toString();
          if (consultantId != null && consultantId.isNotEmpty) {
            print('[FEEDBACK] Sending notification to consultant: $consultantId');
            await notificationService.createNotification(
              title: 'New Feedback on Your Service',
              body: 'You have received new feedback from a minister.',
              data: notificationData,
              role: 'consultant',
              assignedToId: consultantId,
              notificationType: 'consultant_feedback',
            );
          }
          
          // Log successful notification
          await notificationService.logNotificationDebug(
            trigger: 'feedback_submission',
            eventType: 'feedback_submitted',
            recipient: floorManagerId,
            body: notificationBody,
            localSuccess: true,
            fcmSuccess: true,
          );
        } catch (e) {
          // Log notification error but don't fail the whole operation
          print('[FEEDBACK ERROR] Failed to send notification: $e');
          await notificationService.logNotificationDebug(
            trigger: 'feedback_submission',
            eventType: 'notification_error',
            recipient: floorManagerId,
            body: 'Failed to send notification: $e',
            localSuccess: false,
            fcmSuccess: false,
            error: e.toString(),
          );
          // Don't rethrow - we still want to complete the feedback submission
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
      // Log the error
      if (mounted) {
        await notificationService.logNotificationDebug(
          trigger: 'feedback_submission',
          eventType: 'error',
          recipient: 'system',
          body: 'Failed to submit feedback: $e',
          localSuccess: false,
          fcmSuccess: false,
          error: e.toString(),
        );
      }
      
      setState(() => _isSubmitting = false);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error submitting feedback: ${e.toString()}'),
            duration: const Duration(seconds: 5),
          )
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Rate My Experience')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    // DEBUG: Print loaded questions and options
    print('Questions loaded: [32m[1m${_questions.length}[0m');
    print('First question: [36m${_questions.isNotEmpty ? _questions[0] : "None"}[0m');
    print('Options loaded: [32m${_options.length}[0m');
    print('First option: [36m${_options.isNotEmpty ? _options[0] : "None"}[0m');
    return Scaffold(
      appBar: AppBar(
        title: const Text('Rate My Experience', style: TextStyle(color: Colors.black)),
        iconTheme: const IconThemeData(color: Colors.black),
        backgroundColor: Colors.red,
        elevation: 1,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ..._questions.asMap().entries.map((entry) {
              final idx = entry.key + 1;
              final q = entry.value;
              final qId = (q['docId'] ?? q['id'] ?? q['questionId'] ?? q['order'] ?? q['text'] ?? q['question'] ?? entry.key).toString();
              print('DEBUG: Rendering question $idx with qId=$qId, current response=${_responses[qId]}');
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('$idx. ${q['text'] ?? q['question']}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 8),
                  Container(
                    color: Colors.red,
                    child: Column(
                      children: _options.map((opt) {
                        final score = opt['score'] ?? 0;
                        final label = opt['label'] ?? score.toString();
                        return RadioListTile<int>(
                          value: score,
                          groupValue: _responses[qId],
                          onChanged: (val) => _setResponse(qId, val!),
                          title: Text('$score. $label', style: TextStyle(color: Colors.white)),
                          activeColor: Colors.white,
                          selectedTileColor: Colors.red,
                          tileColor: Colors.red,
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              );
            }),
            const Text('Comments', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 8),
            TextFormField(
              minLines: 4,
              maxLines: 8,
              decoration: InputDecoration(
                hintText: 'Add additional comments...',
                border: OutlineInputBorder(),
              ),
              onChanged: (v) => _comment = v,
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _submit,
                child: _isSubmitting
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('Submit Feedback'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
