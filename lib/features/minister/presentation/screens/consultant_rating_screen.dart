import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/colors.dart';
import '../../../../core/providers/app_auth_provider.dart';
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
      
      // Save the rating to Firestore
      await FirebaseFirestore.instance.collection('ratings').add({
        'appointmentId': appointmentId,
        'consultantId': consultantId,
        'ministerId': user.id,
        'ministerName': user.name,
        'rating': _rating,
        'feedback': _feedback,
        'timestamp': FieldValue.serverTimestamp(),
      });
      
      // Update the appointment to show it's been rated
      await FirebaseFirestore.instance.collection('appointments').doc(appointmentId).update({
        'isRated': true,
        'rating': _rating,
      });
      
      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Rating submitted successfully')),
      );
      
      // Navigate back
      Navigator.of(context).pop(true);
      
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
