import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/constants/colors.dart';
import '../../../../core/providers/app_auth_provider.dart';

class AppointmentRatingsScreen extends StatefulWidget {
  const AppointmentRatingsScreen({Key? key}) : super(key: key);

  @override
  _AppointmentRatingsScreenState createState() => _AppointmentRatingsScreenState();
}

class _AppointmentRatingsScreenState extends State<AppointmentRatingsScreen> {
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
  Map<String, Map<String, dynamic>> _ministerRatings = {}; // ministerId -> {name, totalRating, count, average}

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
      setState(() {
        _isLoading = true;
      });

      debugPrint('Fetching all appointments...');
      
      // Get all appointments (limited to 50 for now)
      final snapshot = await FirebaseFirestore.instance
          .collection('appointments')
          .limit(50)
          .get();
      
      debugPrint('Found ${snapshot.docs.length} appointments in total');
      
      // Process all appointments
      List<Map<String, dynamic>> appointments = [];
      double totalMinisterRating = 0;
      int totalRatingsCount = 0;
      
      // Maps to store ratings by staff member
      Map<String, double> consultantRatings = {};
      Map<String, int> consultantCounts = {};
      Map<String, double> conciergeRatings = {};
      Map<String, int> conciergeCounts = {};

      for (var doc in snapshot.docs) {
        try {
          final data = doc.data() as Map<String, dynamic>;
          
          // Log all fields for debugging
          debugPrint('Appointment ${doc.id} fields: ${data.entries.map((e) => '${e.key}:${e.value}').join(', ')}');
          
          // Include all appointments in the list
          appointments.add(data);
          
          // Process ratings if they exist
          final rating = (data['rating'] as num?)?.toDouble() ?? 0.0;
          final feedbackRating = (data['feedbackRating'] as num?)?.toDouble() ?? 0.0;
          final consultantName = data['consultantName'] as String?;
          final conciergeName = data['conciergeName'] as String?;
          
          // Process minister ratings (combining both consultant and concierge ratings)
          if (rating > 0) {
            totalMinisterRating += rating;
            totalRatingsCount++;
            
            if (consultantName != null && consultantName.isNotEmpty) {
              consultantRatings[consultantName] = (consultantRatings[consultantName] ?? 0.0) + rating;
              consultantCounts[consultantName] = (consultantCounts[consultantName] ?? 0) + 1;
            }
          }
          
          // Process concierge ratings (also count as minister ratings)
          if (feedbackRating > 0) {
            totalMinisterRating += feedbackRating;
            totalRatingsCount++;
            
            if (conciergeName != null && conciergeName.isNotEmpty) {
              conciergeRatings[conciergeName] = (conciergeRatings[conciergeName] ?? 0.0) + feedbackRating;
              conciergeCounts[conciergeName] = (conciergeCounts[conciergeName] ?? 0) + 1;
            }
          }
        } catch (e) {
          debugPrint('Error processing appointment ${doc.id}: $e');
        }
      }

      // Calculate staff averages
      final Map<String, double> consultantAverages = {};
      consultantRatings.forEach((name, total) {
        final count = consultantCounts[name] ?? 1;
        consultantAverages[name] = (total / count);
      });

      final Map<String, double> conciergeAverages = {};
      conciergeRatings.forEach((name, total) {
        final count = conciergeCounts[name] ?? 1;
        conciergeAverages[name] = (total / count);
      });

      // Calculate minister-specific ratings
      final Map<String, Map<String, dynamic>> ministerRatings = {};
      
      // Process consultant ratings by minister
      consultantRatings.forEach((name, total) {
        final ministerId = name; // Using name as ID for now
        final count = consultantCounts[name] ?? 1;
        final average = total / count;
        
        ministerRatings[ministerId] = {
          'name': name,
          'totalRating': total,
          'count': count,
          'average': average,
          'role': 'Consultant',
        };
      });
      
      // Process concierge ratings by minister
      conciergeRatings.forEach((name, total) {
        final ministerId = name; // Using name as ID for now
        final count = conciergeCounts[name] ?? 1;
        final average = total / count;
        
        if (ministerRatings.containsKey(ministerId)) {
          // If minister already exists, combine the ratings
          final existing = ministerRatings[ministerId]!;
          ministerRatings[ministerId] = {
            'name': name,
            'totalRating': (existing['totalRating'] as double) + total,
            'count': (existing['count'] as int) + count,
            'average': ((existing['totalRating'] + total) / ((existing['count'] as int) + count)),
            'role': '${existing['role']}/Concierge',
          };
        } else {
          ministerRatings[ministerId] = {
            'name': name,
            'totalRating': total,
            'count': count,
            'average': average,
            'role': 'Concierge',
          };
        }
      });

      // Calculate overall minister rating: (sum of all ratings) / (number of ratings * 5) * 5
      final double maxPossibleScore = totalRatingsCount * 5.0;
      final double averageMinisterRating = totalRatingsCount > 0 
          ? (totalMinisterRating / maxPossibleScore) * 5.0
          : 0.0;

      setState(() {
        _appointments = appointments;
        _averageRating = averageMinisterRating;
        _totalFeedbacks = totalRatingsCount;
        _consultantAverages = consultantAverages;
        _conciergeAverages = conciergeAverages;
        _ministerRatings = ministerRatings;
        _isLoading = false;
      });

    } catch (e) {
      print('Error fetching appointments: $e');
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading appointments: $e')),
      );
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

  Widget _buildAverageRating() {
    return Container(
      margin: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.blue[900]!,
            Colors.blue[800]!,
          ],
        ),
        borderRadius: BorderRadius.circular(12.0),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Average Ratings',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                _buildRatingStars(_averageRating),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${_averageRating.toStringAsFixed(1)}/5.0',
                      style: const TextStyle(
                        color: Colors.amber,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Based on $_totalFeedbacks ${_totalFeedbacks == 1 ? 'rating' : 'ratings'}' ,
                      style: TextStyle(
                        color: Colors.blue[200],
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_consultantAverages.isNotEmpty || _conciergeAverages.isNotEmpty) ...[
              Divider(color: Colors.blue[700]),
              const SizedBox(height: 12),
              const Text(
                'Staff Averages',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              if (_consultantAverages.isNotEmpty) ..._buildStaffAveragesList('Consultants', _consultantAverages),
              if (_conciergeAverages.isNotEmpty) ..._buildStaffAveragesList('Concierge', _conciergeAverages),
            ],
          ],
        ),
      ),
    );
  }
  
  List<Widget> _buildStaffAveragesList(String title, Map<String, double> averages) {
    final items = <Widget>[];
    
    items.add(Text(
      '$title:',
      style: const TextStyle(
        color: Colors.white70,
        fontSize: 14,
        fontWeight: FontWeight.w500,
      ),
    ));
    
    averages.forEach((name, rating) {
      items.addAll([
        const SizedBox(height: 4),
        Row(
          children: [
            Expanded(
              child: Text(
                name,
                style: const TextStyle(color: Colors.white70, fontSize: 13),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            _buildRatingStars(rating, size: 16.0),
            const SizedBox(width: 8),
            Text(
              rating.toStringAsFixed(1),
              style: const TextStyle(
                color: Colors.amber,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ]);
    });
    
    return items;
  }

  Widget _buildStaffAverages() {
    if (_consultantAverages.isEmpty && _conciergeAverages.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Colors.blue[900],
        borderRadius: BorderRadius.circular(12.0),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: Colors.blue[700]!),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Average Ratings by Staff',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Colors.white70,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            if (_consultantAverages.isNotEmpty) ...[
              Text(
                'Consultants',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: Colors.white70,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              ..._consultantAverages.entries.map((entry) => _buildStaffRatingItem(entry.key, entry.value)),
              const SizedBox(height: 8),
            ],
            if (_conciergeAverages.isNotEmpty) ...[
              Text(
                'Concierge',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: Colors.white70,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              ..._conciergeAverages.entries.map((entry) => _buildStaffRatingItem(entry.key, entry.value)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStaffRatingItem(String name, double rating) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          Expanded(
            child: Text(
              name,
              style: const TextStyle(color: Colors.white70),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          _buildRatingStars(rating),
          const SizedBox(width: 8),
          Text(
            rating.toStringAsFixed(1),
            style: const TextStyle(
              color: Colors.white,
                                    fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Appointment Ratings'),
        backgroundColor: AppColors.primary,
        actions: [
          IconButton(
            icon: const Icon(Icons.date_range),
            onPressed: _selectDateRange,
            tooltip: 'Select Date Range',
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.grey[900]!,
              Colors.grey[850]!,
            ],
          ),
        ),
        child: Column(
          children: [
            _buildAverageRating(),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Text(
                '${DateFormat('MMM d, y').format(_selectedDateRange.start)} - ${DateFormat('MMM d, y').format(_selectedDateRange.end)}',
                style: const TextStyle(color: Colors.white70, fontSize: 16),
              ),
            ),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _appointments.isEmpty
                      ? Center(
                          child: Container(
                            padding: const EdgeInsets.all(20),
                            margin: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: Colors.grey[800]?.withOpacity(0.7),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.grey[700]!),
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.search_off_rounded, size: 48, color: Colors.white70),
                                const SizedBox(height: 16),
                                const Text(
                                  'No Appointments Found',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'No appointments were found for the selected date range.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Colors.grey[300],
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                ElevatedButton.icon(
                                  onPressed: _selectDateRange,
                                  icon: const Icon(Icons.date_range, size: 18),
                                  label: const Text('Change Date Range'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.primary,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.only(bottom: 16.0),
                          itemCount: _appointments.length,
                          itemBuilder: (context, index) {
                            final appointment = _appointments[index];
                            return _buildAppointmentCard(appointment);
                          },
                        ),
            ),
            _buildStaffAverages(),
          ],
        ),
      ),
    );
  }

  Widget _buildAppointmentCard(Map<String, dynamic> appointment) {
    // Debug print to see all appointment data
    debugPrint('Appointment data: ${appointment.toString()}');
    
    // Extract all appointment data with null safety and debug logging
    final startTime = appointment['startTime'] is Timestamp 
        ? (appointment['startTime'] as Timestamp).toDate()
        : null;
    final endTime = appointment['endTime'] is Timestamp 
        ? (appointment['endTime'] as Timestamp).toDate()
        : null;
    final status = appointment['status'] as String? ?? 'No status';
    
    // Client information
    final clientName = appointment['clientName'] as String? ?? 
                       appointment['client']?['name'] as String? ?? 
                       'No client name';
    final clientPhone = appointment['clientPhone'] as String? ?? 
                       appointment['client']?['phone'] as String?;
    final clientEmail = appointment['clientEmail'] as String? ?? 
                       appointment['client']?['email'] as String?;
    
    // Staff information
    final ministerName = appointment['ministerName'] as String? ?? 
                        appointment['minister']?['name'] as String?;
    final consultantName = appointment['consultantName'] as String? ?? 
                          appointment['consultant'] as String?;
    final conciergeName = appointment['conciergeName'] as String? ?? 
                         appointment['concierge'] as String?;
    
    // Ratings and feedback
    final rating = (appointment['rating'] as num?)?.toDouble() ?? 0.0;
    final feedbackRating = (appointment['feedbackRating'] as num?)?.toDouble() ?? 0.0;
    final comment = appointment['comment'] as String?;
    final feedbackComment = appointment['feedbackComment'] as String?;
    final ministerFeedback = appointment['ministerFeedback'] as String?;
    final notes = appointment['notes'] as String?;
    final experience = appointment['experience'] as String?;
    
    // Debug log the extracted values
    debugPrint('Client: $clientName, Phone: $clientPhone, Email: $clientEmail');
    debugPrint('Minister: $ministerName, Consultant: $consultantName, Concierge: $conciergeName');
    debugPrint('Ratings: $rating, Feedback: $feedbackRating');
    
    // Calculate the normalized rating (out of 5)
    final normalizedRating = rating > 0 ? (rating / 5) * 5 : 0.0;
    final normalizedFeedbackRating = feedbackRating > 0 ? (feedbackRating / 5) * 5 : 0.0;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
      decoration: BoxDecoration(
        color: Colors.blue[900],
        borderRadius: BorderRadius.circular(12.0),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(color: Colors.blue[700]!),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with date and status
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  startTime != null 
                      ? DateFormat('MMM d, y • hh:mm a').format(startTime)
                      : 'No time',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _getStatusColor(status),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    status,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            
            // Client information
            const SizedBox(height: 12),
            const Text('Client Information', style: TextStyle(fontWeight: FontWeight.bold)),
            _buildInfoRow('Name', clientName),
            if (clientPhone != null && clientPhone.isNotEmpty)
              _buildClickableInfo('Phone', clientPhone, 'tel:$clientPhone'),
            if (clientEmail != null && clientEmail.isNotEmpty)
              _buildClickableInfo('Email', clientEmail, 'mailto:$clientEmail'),
            
            // Staff information
            const SizedBox(height: 12),
            const Text('Staff', style: TextStyle(fontWeight: FontWeight.bold)),
            _buildInfoRow('Minister', ministerName ?? 'Not assigned'),
            _buildInfoRow('Consultant', consultantName ?? 'Not assigned'),
            _buildInfoRow('Concierge', conciergeName ?? 'Not assigned'),
            
            // Time information
            if (startTime != null && endTime != null) ...[
              const SizedBox(height: 12),
              const Divider(),
              Row(
                children: [
                  const Icon(Icons.access_time, size: 16, color: Colors.grey),
                  const SizedBox(width: 8),
                  Text(
                    '${DateFormat('h:mm a').format(startTime)} - ${DateFormat('h:mm a').format(endTime)}',
                    style: const TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                ],
              ),
            ],
            
            // Ratings and Feedback
            const SizedBox(height: 12),
            const Divider(),
            const Text('Ratings & Feedback', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white)),
            const SizedBox(height: 12),
            
            // Minister's Feedback Experience
            if (ministerFeedback?.isNotEmpty ?? false) ...[
              _buildFeedbackSection('Minister\'s Feedback', ministerFeedback!),
              const SizedBox(height: 12),
            ],
            
            // Experience Rating
            if (experience?.isNotEmpty ?? false) ...[
              _buildExperienceSection(experience!),
              const SizedBox(height: 12),
            ],
            
            // Consultant Rating
            _buildRatingSection('Consultant Rating', rating, comment),
            const SizedBox(height: 12),
            
            // Concierge Rating
            _buildRatingSection('Concierge Rating', feedbackRating, feedbackComment),
            
            // Additional Notes
            if (notes?.isNotEmpty ?? false) ...[
              const SizedBox(height: 12),
              const Divider(),
              const Text('Appointment Notes', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.white)),
              const SizedBox(height: 6),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12.0),
                decoration: BoxDecoration(
                  color: Colors.blue[800]!,
                  borderRadius: BorderRadius.circular(8.0),
                  border: Border.all(color: Colors.blue[600]!),
                ),
                child: Text(
                  notes!,
                  style: const TextStyle(fontSize: 14, color: Colors.white70, height: 1.4),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$label: ',
            style: TextStyle(
              fontWeight: FontWeight.w500, 
              color: Colors.blue[200],
              fontSize: 14,
            ),
          ),
          Expanded(
            child: Text(
              value.isNotEmpty ? value : 'Not provided',
              style: TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontStyle: value.isNotEmpty ? FontStyle.normal : FontStyle.italic,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildClickableInfo(String label, String value, String url) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$label: ',
            style: TextStyle(
              fontWeight: FontWeight.w500, 
              color: Colors.blue[200],
              fontSize: 14,
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () async {
                if (await canLaunch(url)) {
                  await launch(url);
                }
              },
              child: Text(
                value,
                style: TextStyle(
                  color: Colors.blue[100],
                  decoration: TextDecoration.underline,
                  fontSize: 14,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeedbackSection(String title, String feedback) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12.0),
      decoration: BoxDecoration(
        color: Colors.blue[800]!,
        borderRadius: BorderRadius.circular(8.0),
        border: Border.all(color: Colors.blue[600]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              color: Colors.amber,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            feedback,
            style: const TextStyle(
              fontSize: 14,
              color: Colors.white70,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildExperienceSection(String experience) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12.0),
      decoration: BoxDecoration(
        color: Colors.blue[800]!,
        borderRadius: BorderRadius.circular(8.0),
        border: Border.all(color: Colors.blue[600]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Experience',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              color: Colors.amber,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            experience,
            style: const TextStyle(
              fontSize: 14,
              color: Colors.white70,
              fontStyle: FontStyle.italic,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRatingSection(String title, double rating, String? comment) {
    // Handle null or zero rating
    final hasRating = (rating ?? 0) > 0;
    final hasComment = comment != null && comment.trim().isNotEmpty;
    
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12.0),
      decoration: BoxDecoration(
        color: Colors.blue[900]!.withOpacity(0.7),
        borderRadius: BorderRadius.circular(8.0),
        border: Border.all(color: Colors.blue[700]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '$title: ',
                style: const TextStyle(
                  fontWeight: FontWeight.w500, 
                  fontSize: 14,
                  color: Colors.white,
                ),
              ),
              Text(
                hasRating ? '${rating.toStringAsFixed(1)}/5.0' : 'Not rated',
                style: TextStyle(
                  color: hasRating ? Colors.amber : Colors.grey[400],
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          if (hasRating) ...[
            const SizedBox(height: 6),
            _buildRatingStars(rating),
          ],
          if (hasComment) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10.0),
              decoration: BoxDecoration(
                color: Colors.blue[800],
                borderRadius: BorderRadius.circular(6.0),
                border: Border.all(color: Colors.blue[700]!),
              ),
              child: Text(
                comment,
                style: const TextStyle(
                  fontSize: 13, 
                  color: Colors.white70,
                  fontStyle: FontStyle.italic,
                ),
              ),
            )
          ]
        ],
      ),
    );
  }

  String _formatTime(DateTime? time) {
    if (time == null) return 'N/A';
    return DateFormat.jm().format(time);
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
        return Colors.green;
      case 'confirmed':
        return Colors.blue;
      case 'pending':
        return Colors.orange;
      case 'cancelled':
        return Colors.red;
      case 'no show':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }
}
