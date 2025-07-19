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
  // Define color constants to avoid const constructor issues
  static const Color blue200 = Color(0xFF90CAF9); // Colors.blue[200]
  static const Color blue800 = Color(0xFF1565C0); // Colors.blue[800]
  static const Color blue900 = Color(0xFF0D47A1); // Colors.blue[900]
  static const Color blue700 = Color(0xFF1976D2); // Colors.blue[700]
  static const Color blue600 = Color(0xFF1E88E5); // Colors.blue[600]
  
  DateTimeRange _selectedDateRange = DateTimeRange(
    start: DateTime.now().subtract(const Duration(days: 30)),
    end: DateTime.now(),
  );
  
  double _averageRating = 0.0;
  int _totalFeedbacks = 0;
  bool _isLoading = true;
  List<Map<String, dynamic>> _appointments = [];
  Map<String, double> _consultantAverages = {};
  Map<String, double> _conciergeAverages = {};
  Map<String, Map<String, dynamic>> _ministerRatings = {};

  @override
  void initState() {
    super.initState();
    _fetchAppointments();
  }

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
        _fetchAppointments();
      });
    }
  }

  Future<void> _fetchAppointments() async {
    try {
      setState(() => _isLoading = true);
      
      debugPrint('Fetching all appointments...');
      final snapshot = await FirebaseFirestore.instance
          .collection('appointments')
          .limit(50)
          .get();
      
      debugPrint('Found ${snapshot.docs.length} appointments');
      
      List<Map<String, dynamic>> appointments = [];
      double totalMinisterRating = 0;
      int totalRatingsCount = 0;
      
      // Process appointments
      for (var doc in snapshot.docs) {
        try {
          final data = doc.data() as Map<String, dynamic>;
          appointments.add(data);
          
          // Process ratings
          final rating = (data['rating'] as num?)?.toDouble() ?? 0.0;
          final feedbackRating = (data['feedbackRating'] as num?)?.toDouble() ?? 0.0;
          
          if (rating > 0) {
            totalMinisterRating += rating;
            totalRatingsCount++;
          }
          
          if (feedbackRating > 0) {
            totalMinisterRating += feedbackRating;
            totalRatingsCount++;
          }
          
        } catch (e) {
          debugPrint('Error processing appointment: $e');
        }
      }
      
      // Calculate overall average
      final double maxPossibleScore = totalRatingsCount * 5.0;
      final double averageMinisterRating = totalRatingsCount > 0 
          ? (totalMinisterRating / maxPossibleScore) * 5.0
          : 0.0;

      setState(() {
        _appointments = appointments;
        _averageRating = averageMinisterRating;
        _totalFeedbacks = totalRatingsCount;
        _isLoading = false;
      });
      
    } catch (e) {
      debugPrint('Error fetching appointments: $e');
      setState(() => _isLoading = false);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading appointments: $e')),
        );
      }
    }
  }

  Widget _buildRatingStars(double rating, {double size = 20.0}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (index) {
        return Icon(
          index < rating.floor()
              ? Icons.star_rounded
              : index < rating.ceil()
                  ? Icons.star_half_rounded
                  : Icons.star_border_rounded,
          color: Colors.amber,
          size: size,
        );
      }),
    );
  }

  Widget _buildRatingItem(String title, double rating, String? comment) {
    if (rating <= 0 && (comment == null || comment.isEmpty)) {
      return const SizedBox.shrink();
    }
    
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: blue800,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: blue600),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.amber,
                ),
              ),
              if (rating > 0) _buildRatingStars(rating, size: 16),
            ],
          ),
          if (comment?.isNotEmpty ?? false) ...[
            const SizedBox(height: 8),
            Text(
              comment!,
              style: const TextStyle(color: Colors.white70),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAverageRatingsCard() {
    return Card(
      margin: const EdgeInsets.all(12.0),
      color: blue900,
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Average Ratings',
              style: TextStyle(
                color: Colors.amber,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                _buildRatingStars(_averageRating, size: 24),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${_averageRating.toStringAsFixed(1)}/5.0',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Based on $_totalFeedbacks ${_totalFeedbacks == 1 ? 'rating' : 'ratings'}\n',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppointmentCard(Map<String, dynamic> appointment) {
    // Get minister details
    final ministerFirstname = appointment['ministerFirstname']?.toString() ?? '';
    final ministerLastname = appointment['ministerLastname']?.toString() ?? '';
    final ministerEmail = appointment['ministerEmail']?.toString() ?? '';
    final ministerPhone = appointment['ministerPhoneNumber']?.toString() ?? '';
    final ministerName = '$ministerFirstname $ministerLastname'.trim();
    final referenceNumber = appointment['referenceNumber']?.toString() ?? '';
    
    // Get other appointment details
    final consultantName = appointment['consultantName'] as String?;
    final conciergeName = appointment['conciergeName'] as String?;
    final rating = (appointment['rating'] as num?)?.toDouble() ?? 0.0;
    final feedbackRating = (appointment['feedbackRating'] as num?)?.toDouble() ?? 0.0;
    final consultantComment = appointment['consultantComment'] as String?;
    final conciergeComment = appointment['conciergeComment'] as String?;
    final feedbackComment = appointment['feedbackComment'] as String?;
    final appointmentDate = appointment['appointmentDate'] is Timestamp
        ? (appointment['appointmentDate'] as Timestamp).toDate()
        : null;
    
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      color: blue900,
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12.0),
        side: BorderSide(color: blue700),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with minister name and date
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        ministerName.isNotEmpty ? ministerName : 'Unnamed Minister',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (ministerEmail.isNotEmpty || ministerPhone.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        if (ministerEmail.isNotEmpty)
                          GestureDetector(
                            onTap: () => _launchEmail(ministerEmail),
                            child: Text(
                              ministerEmail,
                              style: const TextStyle(
                                color: Colors.blueAccent,
                                fontSize: 12,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ),
                        if (ministerPhone.isNotEmpty)
                          GestureDetector(
                            onTap: () => _launchPhoneCall(ministerPhone),
                            child: Text(
                              ministerPhone,
                              style: const TextStyle(
                                color: Colors.blueAccent,
                                fontSize: 12,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ),
                      ],
                    ],
                  ),
                ),
                if (appointmentDate != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: blue800,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      DateFormat('MMM d, y').format(appointmentDate),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
              ],
            ),
            
            const SizedBox(height: 12),
            
            // Ratings
            if (rating > 0 || feedbackRating > 0) ...[
              if (rating > 0)
                _buildRatingItem('Consultant Rating', rating, consultantComment),
              
              if (feedbackRating > 0)
                _buildRatingItem('Feedback Rating', feedbackRating, feedbackComment),
              
              const SizedBox(height: 8),
            ],
            
            // Reference number
            if (referenceNumber.isNotEmpty)
              Text(
                'Ref: $referenceNumber',
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
        return Colors.green;
      case 'cancelled':
        return Colors.red;
      case 'no-show':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }
  
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

  Future<void> _launchPhoneCall(String phoneNumber) async {
    final Uri phoneLaunchUri = Uri(
      scheme: 'tel',
      path: phoneNumber,
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
    // Calculate average ratings
    final consultantRatings = _appointments
        .where((a) => ((a['rating'] as num?)?.toDouble() ?? 0) > 0)
        .map((a) => (a['rating'] as num).toDouble())
        .toList();
    
    final feedbackRatings = _appointments
        .where((a) => ((a['feedbackRating'] as num?)?.toDouble() ?? 0) > 0)
        .map((a) => (a['feedbackRating'] as num).toDouble())
        .toList();
    
    final avgConsultantRating = consultantRatings.isNotEmpty
        ? consultantRatings.reduce((a, b) => a + b) / consultantRatings.length
        : 0.0;
        
    final avgFeedbackRating = feedbackRatings.isNotEmpty
        ? feedbackRatings.reduce((a, b) => a + b) / feedbackRatings.length
        : 0.0;
    
    final totalRatings = consultantRatings.length + feedbackRatings.length;
    final overallAvg = totalRatings > 0
        ? (avgConsultantRating * consultantRatings.length + avgFeedbackRating * feedbackRatings.length) / totalRatings
        : 0.0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Appointment Ratings'),
        backgroundColor: blue900,
        actions: [
          IconButton(
            icon: const Icon(Icons.date_range),
            onPressed: _selectDateRange,
            tooltip: 'Select Date Range',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Date range display
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                  color: blue800,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '${DateFormat('MMM d, y').format(_selectedDateRange.start)} - ${DateFormat('MMM d, y').format(_selectedDateRange.end)}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(Icons.calendar_today, size: 16, color: Colors.white),
                    ],
                  ),
                ),
                
                // Average Ratings Card
                if (_appointments.isNotEmpty) _buildAverageRatingsCard(),
                
                // Appointments List
                Expanded(
                  child: _appointments.isEmpty
                      ? const Center(
                          child: Text(
                            'No appointments found for selected date range',
                            style: TextStyle(color: Colors.white),
                          ),
                        )
                      : ListView.builder(
                          itemCount: _appointments.length,
                          itemBuilder: (context, index) {
                            return _buildAppointmentCard(_appointments[index]);
                          },
                        ),
                ),
              ],
            ),
    );
  }
}
