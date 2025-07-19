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
  bool _hasRated = false;
  final _feedbackController = TextEditingController();

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
      
      // Prepare rating data to be stored in the appointment document
      final ratingData = {
        'consultantRating': _rating,
        'consultantComment': _feedback.isNotEmpty ? _feedback : null,
        'consultantRatedAt': FieldValue.serverTimestamp(),
        'hasConsultantRating': true,
        'lastUpdated': FieldValue.serverTimestamp(),
      };
      
      // Remove null values from the update map
      ratingData.removeWhere((key, value) => value == null);
      
      debugPrint('[RATING_DEBUG] Updating appointment with rating data: $ratingData');
      
      // Get reference number from appointment data
      final referenceNumber = widget.appointmentData['referenceNumber']?.toString() ?? 
                           widget.appointmentData['appointmentId']?.toString() ??
                           widget.appointmentData['id']?.toString() ??
                           'N/A';
      
      // Create rating document in ratings collection
      await FirebaseFirestore.instance.collection('ratings').add({
        'type': 'consultant',
        'rating': _rating,
        'comment': _feedback.isNotEmpty ? _feedback : null,
        'appointmentId': appointmentId,
        'referenceNumber': referenceNumber,
        'createdAt': FieldValue.serverTimestamp(),
        'userId': user.uid,
        'userName': user.displayName ?? 'Anonymous',
        'consultantId': widget.appointmentData['consultantId'],
        'consultantName': widget.appointmentData['consultantName'],
      });
      
      // Update the appointment document with the rating
      await FirebaseFirestore.instance
          .collection('appointments')
          .doc(appointmentId)
          .update(ratingData);
          
      debugPrint('[RATING_DEBUG] Successfully updated appointment with rating and saved to ratings collection');
      
      setState(() {
        _hasRated = true;
      });
  
      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Rating submitted successfully')),
        );
        
        // Navigate back
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      debugPrint('Error submitting rating: $e');
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

  // Helper method to build info rows
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
    final consultantName = appointment['consultantName'] ?? 'Consultant';
    final service = appointment['service'] ?? 'Service not specified';
    final appointmentTime = appointment['appointmentDate'] != null 
        ? (appointment['appointmentDate'] as Timestamp).toDate()
        : DateTime.now();

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text(
          'Rate Your Experience',
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
                          const Text(
                            'How was your experience?',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Please rate the service provided by $consultantName',
                            style: const TextStyle(
                              color: Colors.grey,
                              fontSize: 16,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 32),
                    
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
                            const Text(
                              'Appointment Details',
                              style: TextStyle(
                                color: AppColors.primary,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 16),
                            _buildInfoRow(
                              Icons.person,
                              'Consultant',
                              consultantName,
                            ),
                            const SizedBox(height: 8),
                            _buildInfoRow(
                              Icons.spa,
                              'Service',
                              service,
                            ),
                            const SizedBox(height: 8),
                            _buildInfoRow(
                              Icons.calendar_today,
                              'Date',
                              DateFormat('EEEE, MMMM d, y').format(appointmentTime),
                            ),
                          ],
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 32),
                    
                    // Rating Stars
                    const Text(
                      'Your Rating',
                      style: TextStyle(
                        color: AppColors.primary,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
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
                    
                    const SizedBox(height: 32),
                    
                    // Feedback field
                    const Text(
                      'Additional Feedback (Optional)',
                      style: TextStyle(
                        color: AppColors.primary,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _feedbackController,
                      style: const TextStyle(color: Colors.white),
                      maxLines: 5,
                      decoration: InputDecoration(
                        hintText: 'Please share your thoughts about the service...',
                        hintStyle: const TextStyle(color: Colors.grey),
                        filled: true,
                        fillColor: Colors.grey[900],
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: AppColors.primary),
                        ),
                      ),
                      onChanged: (value) {
                        setState(() {
                          _feedback = value;
                        });
                      },
                    ),
                    
                    const SizedBox(height: 40),
                    
                    // Submit button
                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      ElevatedButton(
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
                                    _hasRated ? 'Consultant Rated' : 'Submit Rating',
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
