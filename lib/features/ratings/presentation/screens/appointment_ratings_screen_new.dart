import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/foundation.dart';
import '../../../../core/constants/colors.dart';
import '../../../../core/providers/app_auth_provider.dart';

class AppointmentRatingsScreen extends StatefulWidget {
  const AppointmentRatingsScreen({Key? key}) : super(key: key);

  @override
  _AppointmentRatingsScreenState createState() => _AppointmentRatingsScreenState();
}

class _AppointmentRatingsScreenState extends State<AppointmentRatingsScreen> {
  // Define color constants
  static const Color blue200 = Color(0xFF90CAF9);
  static const Color blue800 = Color(0xFF1565C0);
  static const Color blue900 = Color(0xFF0D47A1);
  static const Color blue700 = Color(0xFF1976D2);
  static const Color blue600 = Color(0xFF1E88E5);
  
  // State variables
  DateTimeRange _selectedDateRange = DateTimeRange(
    start: DateTime.now().subtract(const Duration(days: 30)),
    end: DateTime.now(),
  );
  
  bool _isLoading = true;
  List<Map<String, dynamic>> _appointments = [];
  Map<String, double> _consultantAverages = {};
  Map<String, double> _conciergeAverages = {};
  Map<String, Map<String, dynamic>> _ministerRatings = {};
  DateTime _selectedMonth = DateTime.now();

  @override
  void initState() {
    super.initState();
    _fetchAppointments();
  }

  // Fetch appointments from Firestore
  Future<void> _fetchAppointments() async {
    try {
      setState(() => _isLoading = true);
      
      debugPrint('Fetching appointments...');
      final snapshot = await FirebaseFirestore.instance
          .collection('appointments')
          .orderBy('appointmentDate', descending: true)
          .limit(100)
          .get();
      
      debugPrint('Found ${snapshot.docs.length} appointments');
      
      List<Map<String, dynamic>> appointments = [];
      
      // Process appointments
      for (var doc in snapshot.docs) {
        try {
          final data = doc.data() as Map<String, dynamic>;
          data['id'] = doc.id; // Add document ID
          appointments.add(data);
        } catch (e) {
          debugPrint('Error processing appointment: $e');
        }
      }
      
      // Update state
      setState(() {
        _appointments = appointments;
        _isLoading = false;
      });
      
      // Calculate averages
      _calculateAverages(appointments);
      
    } catch (e) {
      debugPrint('Error in _fetchAppointments: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error loading appointments')),
        );
      }
      setState(() => _isLoading = false);
    }
  }

  // Calculate average ratings
  void _calculateAverages(List<Map<String, dynamic>> appointments) {
    double consultantTotal = 0.0;
    double conciergeTotal = 0.0;
    double feedbackTotal = 0.0;
    
    int consultantCount = 0;
    int conciergeCount = 0;
    int feedbackCount = 0;
    
    // Reset averages
    _consultantAverages.clear();
    _conciergeAverages.clear();
    _ministerRatings.clear();
    
    // Process each appointment
    for (var appt in appointments) {
      // Process consultant rating
      final consultantRating = (appt['consultantRating'] is num) 
          ? (appt['consultantRating'] as num).toDouble() 
          : (appt['consultantRating']?['rating'] as num?)?.toDouble() ?? 0.0;
          
      if (consultantRating > 0) {
        consultantTotal += consultantRating;
        consultantCount++;
      }
      
      // Process concierge rating
      final conciergeRating = (appt['conciergeRating'] is num)
          ? (appt['conciergeRating'] as num).toDouble()
          : (appt['conciergeRating']?['rating'] as num?)?.toDouble() ?? 0.0;
          
      if (conciergeRating > 0) {
        conciergeTotal += conciergeRating;
        conciergeCount++;
      }
      
      // Process feedback
      if (appt['feedback'] != null || appt['feedbackRating'] != null) {
        final rating = (appt['feedbackRating'] as num?)?.toDouble() ?? 0.0;
        feedbackTotal += rating;
        feedbackCount++;
      }
    }
    
    // Update state with calculated averages
    setState(() {
      if (consultantCount > 0) {
        _consultantAverages['average'] = consultantTotal / consultantCount;
      }
      
      if (conciergeCount > 0) {
        _conciergeAverages['average'] = conciergeTotal / conciergeCount;
      }
      
      if (feedbackCount > 0) {
        _ministerRatings['average'] = {
          'rating': feedbackTotal / feedbackCount,
          'count': feedbackCount,
        };
      }
    });
  }

  // Build the main content
  Widget _buildContent() {
    if (_appointments.isEmpty) {
      return const Center(
        child: Text(
          'No appointments found',
          style: TextStyle(color: Colors.white),
        ),
      );
    }

    return SingleChildScrollView(
      child: Column(
        children: [
          _buildAverageRatingsCard(),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _appointments.length,
            itemBuilder: (context, index) {
              return _buildAppointmentCard(_appointments[index]);
            },
          ),
        ],
      ),
    );
  }

  // Build the average ratings card
  Widget _buildAverageRatingsCard() {
    return Card(
      margin: const EdgeInsets.all(16.0),
      color: blue900,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Average Ratings',
              style: TextStyle(
                color: AppColors.primary,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildRatingItem('Consultant', 
                  _consultantAverages['average'] ?? 0.0, 
                  _consultantAverages.length,
                  Icons.medical_services,
                ),
                _buildRatingItem('Concierge', 
                  _conciergeAverages['average'] ?? 0.0, 
                  _conciergeAverages.length,
                  Icons.support_agent,
                ),
                _buildRatingItem('Feedback', 
                  _ministerRatings['average']?['rating'] ?? 0.0, 
                  _ministerRatings['average']?['count'] ?? 0,
                  Icons.feedback,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Build a single rating item
  Widget _buildRatingItem(String title, double rating, int count, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: blue200, size: 32),
        const SizedBox(height: 8),
        Text(
          title,
          style: const TextStyle(color: Colors.white70, fontSize: 12),
        ),
        const SizedBox(height: 4),
        Text(
          rating > 0 ? rating.toStringAsFixed(1) : 'N/A',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          '($count ${count == 1 ? 'rating' : 'ratings'})',
          style: const TextStyle(color: Colors.white54, fontSize: 10),
        ),
      ],
    );
  }

  // Build appointment card
  Widget _buildAppointmentCard(Map<String, dynamic> appointment) {
    final appointmentDate = appointment['appointmentDate'] != null
        ? (appointment['appointmentDate'] as Timestamp).toDate()
        : null;
    
    final ministerName = '${appointment['ministerFirstname'] ?? ''} ${appointment['ministerLastname'] ?? ''}'.trim();
    final consultantName = appointment['consultantName'] ?? 'Not assigned';
    final conciergeName = appointment['conciergeName'] ?? 'Not assigned';
    
    // Get ratings
    final consultantRating = (appointment['consultantRating'] is num)
        ? (appointment['consultantRating'] as num).toDouble()
        : (appointment['consultantRating']?['rating'] as num?)?.toDouble() ?? 0.0;
        
    final conciergeRating = (appointment['conciergeRating'] is num)
        ? (appointment['conciergeRating'] as num).toDouble()
        : (appointment['conciergeRating']?['rating'] as num?)?.toDouble() ?? 0.0;
    
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      color: blue900,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Date header
            if (appointmentDate != null) ...[
              Text(
                DateFormat('EEEE, MMMM d, y').format(appointmentDate),
                style: const TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const Divider(color: Colors.white24, height: 20, thickness: 1),
            ],
            
            // Minister info
            _buildInfoRow(Icons.person, 'Minister', ministerName),
            
            // Consultant info and rating
            _buildInfoRow(Icons.medical_services, 'Consultant', consultantName),
            _buildRatingRow('Consultant Rating', consultantRating),
            
            // Concierge info and rating
            _buildInfoRow(Icons.support_agent, 'Concierge', conciergeName),
            _buildRatingRow('Concierge Rating', conciergeRating),
            
            // Feedback if available
            if (appointment['feedback'] != null) ...[
              const SizedBox(height: 8),
              _buildFeedbackSection(appointment['feedback']),
            ],
          ],
        ),
      ),
    );
  }

  // Build info row with icon, label and value
  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          Icon(icon, color: blue200, size: 20),
          const SizedBox(width: 8),
          Text(
            '$label: ',
            style: const TextStyle(color: Colors.white70),
          ),
          Expanded(
            child: Text(
              value.isNotEmpty ? value : 'Not available',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  // Build rating row with stars
  Widget _buildRatingRow(String label, double rating) {
    return Padding(
      padding: const EdgeInsets.only(left: 28.0, top: 2, bottom: 2),
      child: Row(
        children: [
          Text(
            '$label: ',
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
          _buildStarRating(rating, 16),
          const SizedBox(width: 4),
          Text(
            rating > 0 ? rating.toStringAsFixed(1) : 'Not rated',
            style: TextStyle(
              color: rating > 0 ? Colors.white : Colors.grey,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  // Build star rating widget
  Widget _buildStarRating(double rating, double size) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (index) {
        return Icon(
          index < rating ? Icons.star : Icons.star_border,
          color: index < rating ? Colors.amber : Colors.grey,
          size: size,
        );
      }),
    );
  }

  // Build feedback section
  Widget _buildFeedbackSection(String feedback) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Feedback:',
          style: TextStyle(
            color: AppColors.primary,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          feedback,
          style: const TextStyle(color: Colors.white70),
        ),
      ],
    );
  }

  // Launch email URL
  Future<void> _launchEmail(String email) async {
    final Uri emailLaunchUri = Uri(
      scheme: 'mailto',
      path: email,
    );
    
    if (await canLaunch(emailLaunchUri.toString())) {
      await launch(emailLaunchUri.toString());
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not launch email')),
        );
      }
    }
  }

  // Launch phone URL
  Future<void> _launchPhone(String phone) async {
    final Uri phoneLaunchUri = Uri(
      scheme: 'tel',
      path: phone,
    );
    
    if (await canLaunch(phoneLaunchUri.toString())) {
      await launch(phoneLaunchUri.toString());
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not launch phone')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text(
          'Appointment Ratings',
          style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold),
        ),
        iconTheme: const IconThemeData(color: AppColors.primary),
        actions: [
          IconButton(
            icon: const Icon(Icons.date_range, color: AppColors.primary),
            onPressed: _selectDateRange,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
              ),
            )
          : _buildContent(),
    );
  }

  // Select date range
  Future<void> _selectDateRange() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2023),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDateRange: _selectedDateRange,
    );
    
    if (picked != null && picked != _selectedDateRange) {
      setState(() {
        _selectedDateRange = picked;
        _isLoading = true;
      });
      await _fetchAppointments();
    }
  }
}
