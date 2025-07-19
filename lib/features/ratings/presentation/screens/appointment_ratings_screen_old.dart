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
  // State variables
  late DateTime _selectedMonth;
  late DateTimeRange _selectedDateRange;
  bool _isLoading = true;
  final List<Map<String, dynamic>> _appointments = [];
  final List<Map<String, dynamic>> _cachedAppointments = [];
  final Map<String, dynamic> _consultantAverages = {'average': 0.0, 'count': 0};
  final Map<String, dynamic> _conciergeAverages = {'average': 0.0, 'count': 0};
  double _feedbackAverage = 0.0;
  int _feedbackCount = 0;
  final Map<String, Map<String, dynamic>> _ministerRatings = {};
  DateTime? _lastFetchTime;
  DateTime? _cachedMonth;
  final List<Map<String, dynamic>> _staticCache = [];
  
  @override
  void initState() {
    super.initState();
    _selectedMonth = DateTime(DateTime.now().year, DateTime.now().month);
    _updateDateRange();
    _fetchAppointments();
  }
  
  // Update date range based on selected month
  void _updateDateRange() {
    final now = DateTime.now();
    final isCurrentMonth = _selectedMonth.year == now.year && 
                         _selectedMonth.month == now.month;
    final isPastMonth = _selectedMonth.isBefore(DateTime(now.year, now.month));
    
    final startDate = DateTime(_selectedMonth.year, _selectedMonth.month, 1);
    final endDate = isCurrentMonth 
        ? now 
        : isPastMonth 
            ? DateTime(_selectedMonth.year, _selectedMonth.month + 1, 0, 23, 59, 59)
            : now; // For future months (shouldn't happen due to validation)
    
    debugPrint('Updating date range: ${startDate.toIso8601String()} to ${endDate.toIso8601String()}');
    
    setState(() {
      _selectedDateRange = DateTimeRange(start: startDate, end: endDate);
    });
  }
  
  // Select month using a dialog
  Future<void> _selectMonth() async {
    final now = DateTime.now();
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedMonth,
      firstDate: DateTime(2020),
      lastDate: DateTime(now.year, now.month), // Only allow up to current month
      initialDatePickerMode: DatePickerMode.year,
      initialEntryMode: DatePickerEntryMode.calendarOnly,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.primary,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
      selectableDayPredicate: (date) {
        // Only allow selecting dates up to current month
        return !(date.year > now.year || 
                (date.year == now.year && date.month > now.month));
      },
    );
    
    if (picked != null && 
        (picked.year != _selectedMonth.year || 
         picked.month != _selectedMonth.month)) {
      setState(() {
        _selectedMonth = DateTime(picked.year, picked.month);
        _updateDateRange();
        _fetchAppointments();
      });
    }
  }

  // Format month for display
  String _formatMonth(DateTime date) {
    final now = DateTime.now();
    if (date.year == now.year && date.month == now.month) {
      return '${DateFormat('MMMM yyyy').format(date)} (Month to Date)';
    }
    return DateFormat('MMMM yyyy').format(date);
  }

  // Calculate average ratings for the selected month
  void _calculateAverages() {
    final consultantRatings = <double>[];
    final conciergeRatings = <double>[];
    final feedbackScores = <double>[];
    
    // Get the start and end of the selected month
    final startDate = _selectedDateRange.start;
    final endDate = _selectedDateRange.end;
    
    for (var appointment in _appointments) {
      // Skip if appointment is outside the selected month
      final appointmentDate = _getAppointmentDate(appointment);
      if (appointmentDate.isBefore(startDate) || appointmentDate.isAfter(endDate)) {
        continue;
      }
      
      // Process consultant ratings
      final ratings = appointment['ratings'] as Map<String, dynamic>? ?? {};
      if (ratings['consultant'] != null) {
        final rating = ratings['consultant'] is Map 
            ? ratings['consultant']['rating'] 
            : ratings['consultant'];
        if (rating != null) {
          consultantRatings.add((rating as num).toDouble());
        }
      }
      
      // Process concierge ratings
      if (ratings['concierge'] != null) {
        final rating = ratings['concierge'] is Map 
            ? ratings['concierge']['rating'] 
            : ratings['concierge'];
        if (rating != null) {
          conciergeRatings.add((rating as num).toDouble());
        }
      }
      
      // Process feedback scores if available
      if (appointment['feedback'] != null) {
        final feedback = appointment['feedback'] is Map 
            ? appointment['feedback'] 
            : null;
        if (feedback != null && feedback['score'] != null) {
          feedbackScores.add((feedback['score'] as num).toDouble());
        }
      }
    }
    
    setState(() {
      // Update consultant averages
      _consultantAverages['average'] = consultantRatings.isNotEmpty 
          ? consultantRatings.reduce((a, b) => a + b) / consultantRatings.length 
          : 0.0;
      _consultantAverages['count'] = consultantRatings.length;
          
      // Update concierge averages
      _conciergeAverages['average'] = conciergeRatings.isNotEmpty
          ? conciergeRatings.reduce((a, b) => a + b) / conciergeRatings.length
          : 0.0;
      _conciergeAverages['count'] = conciergeRatings.length;
      
      // Calculate feedback average if available
      if (feedbackScores.isNotEmpty) {
        _feedbackAverage = feedbackScores.reduce((a, b) => a + b) / feedbackScores.length;
        _feedbackCount = feedbackScores.length;
      } else {
        _feedbackAverage = 0.0;
        _feedbackCount = 0;
      }
    });
  }

  // Helper method to convert DateTime to start of day
  DateTime _startOfDay(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  // Helper method to convert DateTime to end of day
  DateTime _endOfDay(DateTime date) {
    return DateTime(date.year, date.month, date.day, 23, 59, 59);
  }

  // Cache configuration
  static const Duration cacheDuration = Duration(hours: 1);


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Appointment Ratings'),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_today),
            onPressed: _selectMonth,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _appointments.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.event_busy, size: 64, color: Colors.grey),
                      const SizedBox(height: 16),
                      Text(
                        'No appointments found',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Try selecting a different month',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                )
              : Column(
                  children: [
                    _buildAverageRatingsCard(),
                    const SizedBox(height: 16),
                    Expanded(
                      child: _buildAppointmentsList(),
                    ),
                  ],
                ),
    );
  }

  // Build the average ratings card
  Widget _buildAverageRatingsCard() {
    return Card(
      margin: const EdgeInsets.all(8.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Average Ratings',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildAverageRatingItem(
                  'Feedback',
                  _feedbackAverage,
                  Icons.star,
                  _feedbackCount,
                ),
                _buildAverageRatingItem(
                  'Consultant',
                  _consultantAverages['average'] ?? 0.0,
                  Icons.person,
                  _consultantAverages['count'] ?? 0,
                ),
                _buildAverageRatingItem(
                  'Concierge',
                  _conciergeAverages['average'] ?? 0.0,
                  Icons.support_agent,
                  _conciergeAverages['count'] ?? 0,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Build a single average rating item
  Widget _buildAverageRatingItem(String label, double rating, IconData icon, int count) {
    return Column(
      children: [
        Icon(icon, size: 32, color: AppColors.primary),
        const SizedBox(height: 8),
        Text(
          rating.toStringAsFixed(1),
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        Text(
          '$label ($count)',
          style: const TextStyle(fontSize: 12, color: Colors.grey),
        ),
      ],
    );
  }

  // Build the list of appointments
  Widget _buildAppointmentsList() {
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 16),
      itemCount: _appointments.length,
      itemBuilder: (context, index) {
        final appointment = _appointments[index];
        return _buildAppointmentCard(appointment);
      },
    );
  }

  // Build an appointment card
  Widget _buildAppointmentCard(Map<String, dynamic> appointment) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildAppointmentHeader(appointment),
            const Divider(),
            _buildAppointmentDetails(appointment),
            const SizedBox(height: 8),
            _buildRatingSections(appointment),
          ],
        ),
      ),
    );
  }

  // Build the appointment header with date and status
  Widget _buildAppointmentHeader(Map<String, dynamic> appointment) {
    final date = _getAppointmentDate(appointment);
    final clientName = appointment['clientName'] ?? 'Unknown Client';
    
    return Row(
      children: [
        const Icon(Icons.calendar_today, size: 16, color: Colors.grey),
        const SizedBox(width: 8),
        Text(
          DateFormat('MMM d, y • h:mm a').format(date),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: _getStatusColor(appointment['status'] ?? '').withOpacity(0.2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            (appointment['status'] ?? 'unknown').toUpperCase(),
            style: TextStyle(
              color: _getStatusColor(appointment['status'] ?? ''),
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  // Build the appointment details section
  Widget _buildAppointmentDetails(Map<String, dynamic> appointment) {
    final clientName = appointment['clientName'] ?? 'Unknown Client';
    final serviceType = appointment['serviceType'] ?? 'Unknown Service';
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildInfoRow('Client', clientName.toString()),
        _buildInfoRow('Service', serviceType.toString()),
        _buildInfoRow(
          'Consultant',
          appointment['consultantName']?.toString() ?? 'Not assigned',
        ),
        _buildInfoRow(
          'Concierge',
          appointment['conciergeName']?.toString() ?? 'Not assigned',
        ),
        if (appointment['notes']?.toString().isNotEmpty ?? false)
          _buildInfoRow('Notes', appointment['notes'].toString()),
      ],
    );
  }

  // Build a row of information
  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(value.isEmpty ? '-' : value),
          ),
        ],
      ),
    );
  }

  // Build the rating sections for an appointment
  Widget _buildRatingSections(Map<String, dynamic> appointment) {
    final consultantRating = appointment['consultantRating'];
    final conciergeRating = appointment['conciergeRating'];
    final feedback = appointment['feedback'];
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (consultantRating != null)
          _buildRatingSection(
            'Consultant Rating',
            consultantRating['rating']?.toDouble(),
            consultantRating['comment'],
          ),
        if (conciergeRating != null)
          _buildRatingSection(
            'Concierge Rating',
            conciergeRating['rating']?.toDouble(),
            conciergeRating['comment'],
          ),
        if (feedback != null)
          _buildFeedbackSection(appointment),
      ],
    );
  }

  // Build a rating section with stars and optional comment
  Widget _buildRatingSection(String title, double? rating, String? comment) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
        const SizedBox(height: 4),
        if (rating != null && rating > 0) ...[
          _buildRatingStars(rating),
          if (comment?.isNotEmpty ?? false) ...[
            const SizedBox(height: 4),
            Text('"$comment"', style: const TextStyle(fontStyle: FontStyle.italic)),
          ],
        ] else
          const Text('Not rated', style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey)),
      ],
    );
  }

  // Build a row of rating stars
  Widget _buildRatingStars(double rating, {double size = 20}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (index) {
        if (rating - index >= 1) {
          return Icon(Icons.star, color: Colors.amber, size: size);
        } else if (rating - index > 0) {
          return Icon(Icons.star_half, color: Colors.amber, size: size);
        } else {
          return Icon(Icons.star_border, color: Colors.grey[400], size: size);
        }
      }),
    );
  }

  // Build the feedback section
  Widget _buildFeedbackSection(Map<String, dynamic> appointment) {
    final feedback = appointment['feedback'];
    if (feedback == null) return const SizedBox.shrink();
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Client Feedback', style: TextStyle(fontWeight: FontWeight.w500)),
        const SizedBox(height: 4),
        if (feedback['rating'] != null)
          _buildRatingStars(feedback['rating'].toDouble(), size: 16),
        if (feedback['comment']?.isNotEmpty ?? false) ...[
          const SizedBox(height: 4),
          Text(
            '\"${feedback['comment']}\"',
            style: const TextStyle(fontStyle: FontStyle.italic),
          ),
        ],
      ],
    );
  }

  // Get color based on status
  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
        return Colors.green;
      case 'in progress':
      case 'in_progress':
        return Colors.orange;
      case 'scheduled':
      case 'pending':
        return Colors.blue;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  // Helper to get appointment date from various possible fields
  DateTime _getAppointmentDate(Map<String, dynamic> appointment) {
    debugPrint('Getting date for appointment: ${appointment['id']}');
    
    // Try all possible date fields
    final dateFields = ['startTime', 'AppointmentTime', 'date', 'createdAt', 'timestamp'];
    
    for (var field in dateFields) {
      if (appointment[field] != null) {
        debugPrint('- Found date field: $field = ${appointment[field]}');
        
        try {
          if (appointment[field] is Timestamp) {
            return (appointment[field] as Timestamp).toDate();
          } else if (appointment[field] is DateTime) {
            return appointment[field] as DateTime;
          } else if (appointment[field] is String) {
            return DateTime.parse(appointment[field] as String);
          } else if (appointment[field] is int) {
            return DateTime.fromMillisecondsSinceEpoch(appointment[field] as int);
          }
        } catch (e) {
          debugPrint('Error parsing date from $field: $e');
        }
      }
    }
    
    debugPrint('No valid date field found in appointment: ${appointment.keys.join(', ')}');
    // Default to current date if no valid date found
    return DateTime.now();
  }

  // Calculate and update average ratings
  void _calculateAverages() {
    double consultantTotal = 0;
    int consultantCount = 0;
    double conciergeTotal = 0;
    int conciergeCount = 0;
    double feedbackTotal = 0;
    int feedbackCount = 0;
    
    // Reset minister ratings
    _ministerRatings.clear();
    
    for (var appointment in _appointments) {
      // Calculate consultant rating average
      if (appointment['consultantRating'] != null && appointment['consultantRating']['rating'] != null) {
        consultantTotal += (appointment['consultantRating']['rating'] as num).toDouble();
        consultantCount++;
      }
      
      // Calculate concierge rating average
      if (appointment['conciergeRating'] != null && appointment['conciergeRating']['rating'] != null) {
        conciergeTotal += (appointment['conciergeRating']['rating'] as num).toDouble();
        conciergeCount++;
      }
      
      // Calculate feedback average
      if (appointment['feedback'] != null && appointment['feedback']['rating'] != null) {
        feedbackTotal += (appointment['feedback']['rating'] as num).toDouble();
        feedbackCount++;
      }
      
      // Track minister ratings
      final ministerId = appointment['ministerId']?.toString();
      if (ministerId != null && ministerId.isNotEmpty) {
        if (!_ministerRatings.containsKey(ministerId)) {
          _ministerRatings[ministerId] = {
            'name': appointment['ministerName'] ?? 'Unknown Minister',
            'total': 0.0,
            'count': 0,
          };
        }
        
        // Add feedback rating to minister's total if available
        if (appointment['feedback'] != null && appointment['feedback']['rating'] != null) {
          _ministerRatings[ministerId]!['total'] += (appointment['feedback']['rating'] as num).toDouble();
          _ministerRatings[ministerId]!['count']++;
        }
      }
    }
    
    // Update state with calculated averages
    setState(() {
      _consultantAverages['average'] = consultantCount > 0 ? consultantTotal / consultantCount : 0.0;
      _consultantAverages['count'] = consultantCount;
      
      _conciergeAverages['average'] = conciergeCount > 0 ? conciergeTotal / conciergeCount : 0.0;
      _conciergeAverages['count'] = conciergeCount;
      
      _feedbackAverage = feedbackCount > 0 ? feedbackTotal / feedbackCount : 0.0;
      _feedbackCount = feedbackCount;
    });
  }

  // Fetch all appointment data including ratings and feedback with caching
  Future<void> _fetchAppointments() async {
    debugPrint('Starting to fetch appointments with all related data...');
    debugPrint('Selected date range: ${_selectedDateRange.start} to ${_selectedDateRange.end}');
    
    if (!mounted) return;

    // Return cached data if it's fresh enough and for the same month
    if (_lastFetchTime != null && 
        DateTime.now().difference(_lastFetchTime!) < cacheDuration &&
        _staticCache.isNotEmpty &&
        _cachedMonth?.year == _selectedMonth.year &&
        _cachedMonth?.month == _selectedMonth.month) {
      debugPrint('Using cached appointments data');
      setState(() {
        _appointments.clear();
        _appointments.addAll(_staticCache);
        _isLoading = false;
      });
      _calculateAverages();
      return;
    }
    
    setState(() {
      _isLoading = true;
      _appointments.clear();
    });

    try {
      // 1. First, get all appointments (we'll filter by date in memory to ensure we don't miss any)
      final now = DateTime.now();
      final isFutureMonth = _selectedMonth.isAfter(DateTime(now.year, now.month));
      
      debugPrint('Selected month: ${_selectedMonth.year}-${_selectedMonth.month} (Future month: $isFutureMonth)');
      debugPrint('Date range: ${_selectedDateRange.start} to ${_selectedDateRange.end}');
      
      // If it's a future month, show a message instead of querying
      if (isFutureMonth) {
        debugPrint('Cannot show appointments for future months');
        setState(() {
          _isLoading = false;
        });
        return;
      }
      
      // For past/current months, query appointments
      debugPrint('Querying appointments...');
      final appointmentsRef = FirebaseFirestore.instance.collection('appointments');
      final querySnapshot = await appointmentsRef
          .where('startTime', isGreaterThanOrEqualTo: _selectedDateRange.start)
          .where('startTime', isLessThanOrEqualTo: _selectedDateRange.end)
          .get();
      
      debugPrint('Found ${querySnapshot.docs.length} appointments in date range');
      
      final appointments = <Map<String, dynamic>>[];
      
      // Process each appointment
      for (var doc in querySnapshot.docs) {
        final appointment = doc.data() as Map<String, dynamic>;
        appointment['id'] = doc.id; // Add document ID to appointment data
        
        // Get ratings and feedback for this appointment
        try {
          // Get consultant rating
          final consultantRating = await FirebaseFirestore.instance
              .collection('ratings')
              .where('appointmentId', isEqualTo: doc.id)
              .where('type', isEqualTo: 'consultant')
              .limit(1)
              .get();
          
          if (consultantRating.docs.isNotEmpty) {
            appointment['consultantRating'] = consultantRating.docs.first.data();
          }
          
          // Get concierge rating
          final conciergeRating = await FirebaseFirestore.instance
              .collection('ratings')
              .where('appointmentId', isEqualTo: doc.id)
              .where('type', isEqualTo: 'concierge')
              .limit(1)
              .get();
          
          if (conciergeRating.docs.isNotEmpty) {
            appointment['conciergeRating'] = conciergeRating.docs.first.data();
          }
          
          // Get client feedback
          final feedback = await FirebaseFirestore.instance
              .collection('client_feedback')
              .where('appointmentId', isEqualTo: doc.id)
              .limit(1)
              .get();
          
          if (feedback.docs.isNotEmpty) {
            appointment['feedback'] = feedback.docs.first.data();
          }
          
          appointments.add(appointment);
        } catch (e) {
          debugPrint('Error fetching ratings/feedback for appointment ${doc.id}: $e');
        }
      }
      
      // Update state with fetched appointments
      if (mounted) {
        setState(() {
          _appointments.addAll(appointments);
          _isLoading = false;
          _lastFetchTime = DateTime.now();
          _cachedMonth = _selectedMonth;
          _staticCache.clear();
          _staticCache.addAll(appointments);
        });
        
        // Calculate and update averages
        _calculateAverages();
      }
      
    } catch (e) {
      debugPrint('Error fetching appointments: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
      
      // Show error message to user
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to load appointments. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
      


                );
                
            // Get from cache first
            QuerySnapshot<Map<String, dynamic>> questionsSnapshot = 
                await questionsQuery.get(GetOptions(source: Source.cache));
                
            // If no cache, try server
            if (questionsSnapshot.docs.isEmpty) {
              questionsSnapshot = await questionsQuery
                  .get(GetOptions(source: Source.serverAndCache));
            }
                
            for (var questionDoc in questionsSnapshot.docs) {
              final questionData = questionDoc.data();
              final questionId = questionDoc.id;
              
              // Get options for this question with cache-first strategy
              final optionsQuery = FirebaseFirestore.instance
                  .collection('Feedback_options')
                  .where('questionId', isEqualTo: questionId)
                  .orderBy('order')
                  .withConverter<Map<String, dynamic>>(
                    fromFirestore: (snapshot, _) => snapshot.data()!..['id'] = snapshot.id,
                    toFirestore: (value, _) => value,
                  );
                  
              QuerySnapshot<Map<String, dynamic>> optionsSnapshot = 
                  await optionsQuery.get(GetOptions(source: Source.cache));
                  
              // If no cache, try server
              if (optionsSnapshot.docs.isEmpty) {
                optionsSnapshot = await optionsQuery
                    .get(GetOptions(source: Source.serverAndCache));
              }
                  
              // Find selected option if any
              String? selectedOptionId;
              if (feedbackData['selectedOptions'] is Map) {
                selectedOptionId = feedbackData['selectedOptions'][questionId];
              }
              
              feedbackQuestions.add({
                'id': questionId,
                'text': questionData['questionText'] ?? 'No question text',
                'options': optionsSnapshot.docs.map((doc) {
                  final optionData = doc.data();
                  return {
                    'id': doc.id,
                    'text': optionData['optionText'] ?? 'No option text',
                    'score': (optionData['score'] ?? 0).toDouble(),
                    'isSelected': doc.id == selectedOptionId,
                  };
                }).toList(),
                'selectedOptionId': selectedOptionId,
              });
            }
          }
          
          // 7. Process ratings data
          Map<String, dynamic> ratingsData = {};
          for (var ratingDoc in ratingsSnapshot.docs) {
            final ratingData = ratingDoc.data();
            final ratingType = ratingData['type'] ?? 'unknown';
            ratingsData[ratingType] = {
              'rating': (ratingData['rating'] ?? 0).toDouble(),
              'comment': ratingData['comment'] ?? '',
              'createdAt': ratingData['createdAt']?.toDate() ?? DateTime.now(),
            };
          }
          
          // 8. Format appointment data
          final formattedAppointment = {
            'id': appointmentId,
            'clientName': appointmentData['clientName'] ?? 'Not specified',
            'serviceType': appointmentData['serviceType'] ?? 'Not specified',
            'consultantName': appointmentData['consultantName'] ?? 'Not specified',
            'conciergeName': appointmentData['conciergeName'] ?? 'Not specified',
            'startTime': appointmentData['startTime'] is Timestamp 
                ? (appointmentData['startTime'] as Timestamp).toDate() 
                : null,
            'status': appointmentData['status'] ?? 'unknown',
            'notes': appointmentData['notes'] ?? '',
            'ratings': ratingsData,
            'feedback': feedbackSnapshot.docs.isNotEmpty 
                ? feedbackSnapshot.docs.first.data() 
                : null,
            'feedbackQuestions': feedbackQuestions,
            ...appointmentData, // Include all other fields
          };
          
          appointments.add(formattedAppointment);
          
        }
        
        // 8. Format appointment data
        final formattedAppointment = {
          'id': appointmentDoc.id,
          'clientName': appointmentData['clientName'] ?? 'Not specified',
          'serviceType': appointmentData['serviceType'] ?? 'Not specified',
          'consultantName': appointmentData['consultantName'] ?? 'Not specified',
          'conciergeName': appointmentData['conciergeName'] ?? 'Not specified',
          'startTime': appointmentData['startTime'] is Timestamp 
              ? (appointmentData['startTime'] as Timestamp).toDate() 
              : null,
          'status': appointmentData['status'] ?? 'unknown',
          'notes': appointmentData['notes'] ?? '',
          'ratings': ratingsData,
          'feedback': feedbackData,
          'feedbackQuestions': feedbackQuestions,
          ...appointmentData, // Include all other fields
        };
        
        appointments.add(formattedAppointment);
      } catch (e) {
        debugPrint('Error processing appointment ${appointmentDoc.id}: $e');
      }
    }
    
    // 9. Update state with all data
    if (!mounted) return;
    
    setState(() {
      _appointments.clear();
      _appointments.addAll(appointments);
      _isLoading = false;
    });
    
    // 10. Update cache and calculate averages
    _lastFetchTime = DateTime.now();
    _cachedMonth = _selectedMonth;
    _staticCache.clear();
    _staticCache.addAll(appointments);
    _calculateAverages();
  } catch (e) {
    debugPrint('Error in _fetchAppointments: $e');
    rethrow;
  } finally {
    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }
}
          IconButton(
            icon: const Icon(Icons.calendar_today),
            onPressed: _selectMonth,
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  // Build the main content body
  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    
    return Column(
      children: [
        _buildAverageRatingsCard(),
        const SizedBox(height: 16),
        Expanded(
          child: _buildAppointmentsList(),
        ),
      ],
    );
  }

  // Build the average ratings card
  Widget _buildAverageRatingsCard() {
    return Card(
      margin: const EdgeInsets.all(8.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${_formatMonth(_selectedMonth)} Averages',
                  style: const TextStyle(
                    fontSize: 16, 
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
                Text(
                  '${_appointments.length} appointments',
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildAverageRatingItem(
                  'Consultant',
                  _consultantAverages['average'] ?? 0.0,
                  Icons.person,
                  _consultantAverages['count'] ?? 0,
                ),
                const VerticalDivider(width: 1, thickness: 1, indent: 8, endIndent: 8),
                _buildAverageRatingItem(
                  'Concierge',
                  _conciergeAverages['average'] ?? 0.0,
                  Icons.support_agent,
                  _conciergeAverages['count'] ?? 0,
                ),
                const VerticalDivider(width: 1, thickness: 1, indent: 8, endIndent: 8),
                _buildAverageRatingItem(
                  'Feedback',
                  _feedbackAverage,
                  Icons.feedback,
                  _feedbackCount,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Build individual average rating item
  Widget _buildAverageRatingItem(String label, double rating, IconData icon, int count) {
    return Column(
      children: [
        Icon(icon, size: 28, color: AppColors.primary),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 2),
        _buildRatingStars(rating, size: 16),
        Text(
          rating > 0 ? rating.toStringAsFixed(1) : 'N/A',
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          '($count)',
          style: const TextStyle(
            fontSize: 10,
            color: Colors.grey,
          ),
        ),
      ],
    );
  }

  // Build the list of appointments
  Widget _buildAppointmentsList() {
    return ListView.builder(
      itemCount: _appointments.length,
      itemBuilder: (context, index) {
        final appointment = _appointments[index];
        return _buildAppointmentCard(appointment);
      },
    );
  }

  // Build an individual appointment card
  Widget _buildAppointmentCard(Map<String, dynamic> appointment) {
    return Card(
      margin: const EdgeInsets.all(8.0),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildAppointmentHeader(appointment),
            const SizedBox(height: 8),
            _buildAppointmentDetails(appointment),
            const SizedBox(height: 12),
            _buildRatingSections(appointment),
          ],
        ),
      ),
    );
  }

  // Build the appointment header with date and status
  Widget _buildAppointmentHeader(Map<String, dynamic> appointment) {
    // Try different possible date fields
    dynamic dateValue = appointment['startTime'] ?? 
                       appointment['appointmentTime'] ?? 
                       appointment['date'] ??
                       appointment['createdAt'];
    
    DateTime startTime;
    if (dateValue is Timestamp) {
      startTime = dateValue.toDate();
    } else if (dateValue is DateTime) {
      startTime = dateValue;
    } else {
      startTime = DateTime.now();
      debugPrint('Warning: No valid date found for appointment ${appointment['id']}');
    }
    
    // Debug log the appointment data
    debugPrint('Appointment ${appointment['id']} data: ${appointment.toString()}');
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              DateFormat('MMM d, y hh:mm a').format(startTime),
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: _getStatusColor(appointment['status'] ?? '').withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                (appointment['status'] as String?)?.toUpperCase() ?? 'UNKNOWN',
                style: TextStyle(
                  color: _getStatusColor(appointment['status'] ?? ''),
                  fontWeight: FontWeight.w500,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // Build appointment details section
  Widget _buildAppointmentDetails(Map<String, dynamic> appointment) {
    // Try different possible client name fields
    final clientName = appointment['clientName'] ?? 
                      appointment['client_name'] ?? 
                      appointment['client'] ??
                      'Not specified';
    
    // Try different possible service fields
    final serviceType = appointment['serviceType'] ?? 
                       appointment['service_type'] ?? 
                       appointment['service'] ??
                       'Not specified';
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildInfoRow('Client', clientName.toString()),
        _buildInfoRow('Service', serviceType.toString()),
        _buildInfoRow('Consultant', appointment['consultantName']?.toString() ?? 'Not assigned'),
        _buildInfoRow('Concierge', appointment['conciergeName']?.toString() ?? 'Not assigned'),
        if (appointment['notes']?.toString().isNotEmpty ?? false) ...[
          const SizedBox(height: 8),
          _buildInfoRow('Notes', appointment['notes'].toString()),
        ],
      ],
    );
  }

  // Build rating sections for consultant and concierge
  Widget _buildRatingSections(Map<String, dynamic> appointment) {
    final ratings = appointment['ratings'] as Map<String, dynamic>? ?? {};
    final consultantRating = ratings['consultant'];
    final conciergeRating = ratings['concierge'];
    
    // Debug log ratings data
    if (ratings.isNotEmpty) {
      debugPrint('Ratings for appointment ${appointment['id']}: $ratings');
    } else {
      debugPrint('No ratings found for appointment ${appointment['id']}');
    }
    
    // Check for direct rating fields if not found in ratings map
    final hasRatings = consultantRating != null || 
                      conciergeRating != null ||
                      appointment['rating'] != null ||
                      appointment['feedback'] != null;
    
    if (!hasRatings) {
      return const Padding(
        padding: EdgeInsets.only(top: 8.0),
        child: Text('No ratings available', style: TextStyle(fontStyle: FontStyle.italic)),
      );
    }
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (consultantRating != null) ...[
          _buildRatingSection(
            'Consultant Rating',
            (consultantRating['rating'] as num?)?.toDouble() ??
            (consultantRating is num ? consultantRating.toDouble() : null),
            consultantRating['comment']?.toString(),
          ),
          const SizedBox(height: 8),
        ],
        if (conciergeRating != null) ...[
          _buildRatingSection(
            'Concierge Rating',
            (conciergeRating['rating'] as num?)?.toDouble() ??
            (conciergeRating is num ? conciergeRating.toDouble() : null),
            conciergeRating['comment']?.toString(),
          ),
          const SizedBox(height: 8),
        ],
        
        // Check for direct rating fields
        if (appointment['rating'] != null && consultantRating == null && conciergeRating == null) ...[
          _buildRatingSection(
            'Overall Rating',
            (appointment['rating'] as num).toDouble(),
            appointment['feedback']?.toString(),
          ),
          const SizedBox(height: 8),
        ],
      ],
    );
  }

  // Build feedback section for an appointment
  Widget _buildFeedbackSection(Map<String, dynamic> appointment) {
    final feedbackQuestions = appointment['feedbackQuestions'] as List<dynamic>? ?? [];
    final feedback = appointment['feedback'] as Map<String, dynamic>?;
    
    if (feedbackQuestions.isEmpty) {
      return const Padding(
        padding: EdgeInsets.only(top: 8.0),
        child: Text('No feedback received', style: TextStyle(fontStyle: FontStyle.italic)),
      );
    }
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(),
        const Text(
          'Client Feedback',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 8),
        
        // Display each question and selected answer
        ...feedbackQuestions.map<Widget>((question) {
          final options = List<Map<String, dynamic>>.from(question['options'] ?? []);
          final selectedOption = options.firstWhere(
            (opt) => opt['isSelected'] == true,
            orElse: () => <String, dynamic>{},
          );
          
          return Padding(
            padding: const EdgeInsets.only(bottom: 12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  question['text'] ?? 'Question',
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 4),
                if (selectedOption.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(left: 8.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('✓ ${selectedOption['text']}'),
                        Text(
                          'Score: ${selectedOption['score']}/${options.length > 0 ? options.map((o) => o['score'] as num).reduce((a, b) => a > b ? a : b) : 0}',
                          style: const TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),
                  )
                else
                  const Text('No response', style: TextStyle(fontStyle: FontStyle.italic)),
              ],
            ),
          );
        }).toList(),
        
        // Display any additional feedback comments
        if (feedback?['comments']?.toString().isNotEmpty ?? false) ...[
          const SizedBox(height: 8),
          const Text('Additional Comments:', style: TextStyle(fontWeight: FontWeight.w500)),
          Padding(
            padding: const EdgeInsets.only(left: 8.0, top: 4.0),
            child: Text('"${feedback!['comments']}"'),
          ),
        ],
      ],
    );
  }

  // Helper method to build a row of information
  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$label: ',
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: value == 'Not specified' || value == 'Not assigned'
                    ? Colors.grey
                    : null,
                fontStyle: value == 'Not specified' || value == 'Not assigned'
                    ? FontStyle.italic
                    : null,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Build a rating section with stars and optional comment
  Widget _buildRatingSection(String title, double? rating, String? comment) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
        const SizedBox(height: 4),
        if (rating != null && rating > 0) ...[
          _buildRatingStars(rating),
          if (comment?.isNotEmpty ?? false) ...[
            const SizedBox(height: 4),
            Text('"$comment"', style: const TextStyle(fontStyle: FontStyle.italic)),
          ],
        ] else
          const Text('Not rated', style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey)),
      ],
    );
  }

  // Build a row of rating stars
  Widget _buildRatingStars(double rating, {double size = 20}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (index) {
        if (rating - index >= 1) {
          return Icon(Icons.star, color: Colors.amber, size: size);
        } else if (rating - index > 0) {
          return Icon(Icons.star_half, color: Colors.amber, size: size);
        } else {
          return Icon(Icons.star_border, color: Colors.grey[400], size: size);
        }
      }),
    );
  }

  // Get color based on appointment status
  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
        return Colors.green;
      case 'in progress':
      case 'in_progress':
        return Colors.orange;
      case 'scheduled':
      case 'pending':
        return Colors.blue;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
}
