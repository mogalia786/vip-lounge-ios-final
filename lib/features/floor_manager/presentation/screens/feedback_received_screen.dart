import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../../core/constants/colors.dart';
import '../../../../core/providers/app_auth_provider.dart';

// Function to safely get first element or null
E? firstOrNull<E>(Iterable<E> iterable) => iterable.isEmpty ? null : iterable.first;

// Model to hold feedback data
class FeedbackData {
  final String id;
  final String ministerId;
  final String ministerName;
  final String appointmentId;
  final String? referenceNumber;
  final DateTime date;
  final List<Map<String, dynamic>> questions;
  final String? comment;
  final String? consultantName;
  final String? conciergeName;
  final double? rating;

  FeedbackData({
    required this.id,
    required this.ministerId,
    required this.ministerName,
    required this.appointmentId,
    this.referenceNumber,
    required this.date,
    required this.questions,
    this.comment,
    this.consultantName,
    this.conciergeName,
    this.rating,
  });

  factory FeedbackData.fromMap(Map<String, dynamic> data, String id) {
    return FeedbackData(
      id: id,
      ministerId: data['ministerId'] ?? data['userId'] ?? '',
      ministerName: data['ministerName'] ?? data['userName'] ?? 'Unknown',
      appointmentId: data['appointmentId'] ?? '',
      referenceNumber: data['referenceNumber'],
      date: data['createdAt'] is Timestamp 
          ? (data['createdAt'] as Timestamp).toDate() 
          : DateTime.now(),
      questions: List<Map<String, dynamic>>.from(data['questions'] ?? []),
      comment: data['comment'] ?? data['comments'],
      consultantName: data['consultantName'],
      conciergeName: data['conciergeName'],
      rating: data['rating']?.toDouble(),
    );
  }
}

class FeedbackReceivedScreen extends StatefulWidget {
  const FeedbackReceivedScreen({Key? key}) : super(key: key);

  @override
  _FeedbackReceivedScreenState createState() => _FeedbackReceivedScreenState();
}

class _FeedbackReceivedScreenState extends State<FeedbackReceivedScreen> {
  DateTime _selectedMonth = DateTime.now();
  bool _isLoading = true;
  
  // Group feedback by minister ID, then by date, then by appointment
  final Map<String, Map<String, Map<String, List<FeedbackData>>>> _feedbackByMinister = {};
  
  // Track expanded/collapsed state
  final Map<String, bool> _expandedMinisters = {};
  final Map<String, bool> _expandedDates = {};
  final Map<String, bool> _expandedAppointments = {};

  @override
  void initState() {
    super.initState();
    _fetchFeedback();
  }

  Future<void> _fetchFeedback() async {
    setState(() => _isLoading = true);
    
    try {
      // Get the first and last day of the selected month
      final firstDay = DateTime(_selectedMonth.year, _selectedMonth.month, 1);
      final lastDay = DateTime(_selectedMonth.year, _selectedMonth.month + 1, 0, 23, 59, 59);
      
      debugPrint('Fetching feedback from ${firstDay.toIso8601String()} to ${lastDay.toIso8601String()}');
      
      // Fetch feedback within the selected month from client_feedback collection
      final feedbackSnapshot = await FirebaseFirestore.instance
          .collection('client_feedback')
          .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(firstDay))
          .where('createdAt', isLessThanOrEqualTo: Timestamp.fromDate(lastDay))
          .get();
          
      debugPrint('Found ${feedbackSnapshot.docs.length} feedback items in the selected period');
      
      // Process feedback data
      final feedbacks = feedbackSnapshot.docs.map((doc) {
        return FeedbackData.fromMap(doc.data(), doc.id);
      }).toList();

      // Group feedback by minister, date, and appointment
      _groupFeedback(feedbacks);
      
    } catch (e) {
      debugPrint('Error fetching feedback: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading feedback: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _groupFeedback(List<FeedbackData> feedbacks) {
    _feedbackByMinister.clear();
    _expandedMinisters.clear();
    _expandedDates.clear();
    _expandedAppointments.clear();

    for (final feedback in feedbacks) {
      final ministerId = feedback.ministerId;
      final dateKey = DateFormat('yyyy-MM-dd').format(feedback.date);
      final appointmentId = feedback.appointmentId;

      // Initialize minister if not exists
      if (!_feedbackByMinister.containsKey(ministerId)) {
        _feedbackByMinister[ministerId] = {};
        _expandedMinisters[ministerId] = true;
      }

      // Initialize date if not exists
      if (!_feedbackByMinister[ministerId]!.containsKey(dateKey)) {
        _feedbackByMinister[ministerId]![dateKey] = {};
        _expandedDates['$ministerId-$dateKey'] = false;
      }

      // Initialize appointment if not exists
      if (!_feedbackByMinister[ministerId]![dateKey]!.containsKey(appointmentId)) {
        _feedbackByMinister[ministerId]![dateKey]![appointmentId] = [];
        _expandedAppointments['$ministerId-$dateKey-$appointmentId'] = false;
      }

      // Add feedback to the appropriate group
      _feedbackByMinister[ministerId]![dateKey]![appointmentId]!.add(feedback);
    }

    // Sort dates in descending order (newest first)
    for (final ministerId in _feedbackByMinister.keys) {
      final dates = _feedbackByMinister[ministerId]!;
      final sortedDates = dates.entries.toList()
        ..sort((a, b) => b.key.compareTo(a.key));
      
      _feedbackByMinister[ministerId] = {
        for (var entry in sortedDates) entry.key: entry.value
      };
    }
  }

  Future<void> _selectMonth() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedMonth,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
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
    );

    if (picked != null && picked != _selectedMonth) {
      setState(() {
        _selectedMonth = DateTime(picked.year, picked.month);
      });
      await _fetchFeedback();
    }
  }

  Widget _buildRatingStars(double rating, {double size = 20}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (index) {
        return Icon(
          index < rating.floor()
              ? Icons.star
              : index < rating.ceil()
                  ? Icons.star_half
                  : Icons.star_border,
          color: Colors.amber,
          size: size,
        );
      }),
    );
  }
  


  Widget _buildFeedbackSummary() {
    int totalFeedback = 0;
    double totalRating = 0;
    int ratingCount = 0;

    // Calculate totals
    for (final ministerId in _feedbackByMinister.keys) {
      for (final dateEntry in _feedbackByMinister[ministerId]!.entries) {
        for (final apptEntry in dateEntry.value.entries) {
          totalFeedback += apptEntry.value.length;
          for (final feedback in apptEntry.value) {
            if (feedback.rating != null) {
              totalRating += feedback.rating!;
              ratingCount++;
            }
          }
        }
      }
    }

    final avgRating = ratingCount > 0 ? totalRating / ratingCount : 0.0;

    return Card(
      margin: const EdgeInsets.all(16.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Feedback Summary',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildSummaryItem(
                  'Total Feedback',
                  totalFeedback.toString(),
                  Icons.feedback_outlined,
                ),
                _buildSummaryItem(
                  'Avg. Rating',
                  avgRating > 0 ? '${avgRating.toStringAsFixed(1)}/5' : 'N/A',
                  Icons.star_rate_rounded,
                ),
                _buildSummaryItem(
                  'Ministers',
                  _feedbackByMinister.length.toString(),
                  Icons.people_outline,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryItem(String label, String value, IconData icon) {
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
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildFeedbackList() {
    if (_feedbackByMinister.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.feedback_outlined, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'No feedback available',
              style: TextStyle(color: Colors.grey[600], fontSize: 18),
            ),
            const SizedBox(height: 8),
            Text(
              'for ${DateFormat('MMMM yyyy').format(_selectedMonth)}',
              style: TextStyle(color: Colors.grey[500]),
            ),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: [
        _buildFeedbackSummary(),
        const SizedBox(height: 16),
        ..._buildMinisterFeedbackList(),
      ],
    );
  }

  List<Widget> _buildMinisterFeedbackList() {
    final widgets = <Widget>[];
    
    for (final ministerEntry in _feedbackByMinister.entries) {
      final ministerId = ministerEntry.key;
      final ministerData = ministerEntry.value;
      final ministerName = firstOrNull(ministerData.values.first.values.first)?.ministerName ?? 'Unknown Minister';
      
      widgets.add(
        Card(
          margin: const EdgeInsets.only(bottom: 16.0),
          child: ExpansionTile(
            key: ValueKey('minister-$ministerId'),
            title: Text(
              ministerName,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            subtitle: Text(
              '${ministerData.length} ${ministerData.length == 1 ? 'day' : 'days'} with feedback',
              style: const TextStyle(fontSize: 12),
            ),
            initiallyExpanded: _expandedMinisters[ministerId] ?? false,
            onExpansionChanged: (expanded) {
              setState(() {
                _expandedMinisters[ministerId] = expanded;
              });
            },
            children: _buildDateFeedbackList(ministerId, ministerData),
          ),
        ),
      );
    }
    
    return widgets;
  }

  List<Widget> _buildDateFeedbackList(String ministerId, Map<String, Map<String, List<FeedbackData>>> datesData) {
    final widgets = <Widget>[];
    
    for (final dateEntry in datesData.entries) {
      final dateKey = dateEntry.key;
      final appointments = dateEntry.value;
      final date = DateTime.parse(dateKey);
      final dateCount = appointments.values.fold(0, (sum, feedbacks) => sum + feedbacks.length);
      
      widgets.add(
        Card(
          margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
          child: ExpansionTile(
            key: ValueKey('date-$ministerId-$dateKey'),
            title: Text(
              DateFormat('EEEE, MMMM d, yyyy').format(date),
              style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
            ),
            subtitle: Text(
              '$dateCount feedback item${dateCount == 1 ? '' : 's'}' +
              (date.isAtSameMomentAs(DateTime.now()) ? ' (Today)' : ''),
              style: const TextStyle(fontSize: 12),
            ),
            initiallyExpanded: _expandedDates['$ministerId-$dateKey'] ?? false,
            onExpansionChanged: (expanded) {
              setState(() {
                _expandedDates['$ministerId-$dateKey'] = expanded;
              });
            },
            children: _buildAppointmentFeedbackList(ministerId, dateKey, appointments),
          ),
        ),
      );
    }
    
    return widgets;
  }

  List<Widget> _buildAppointmentFeedbackList(
    String ministerId, 
    String dateKey, 
    Map<String, List<FeedbackData>> appointments
  ) {
    final widgets = <Widget>[];
    
    for (final apptEntry in appointments.entries) {
      final appointmentId = apptEntry.key;
      final feedbacks = apptEntry.value;
      final firstFeedback = feedbacks.first;
      
      widgets.add(
        Card(
          margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 2.0),
          child: ExpansionTile(
            key: ValueKey('appt-$ministerId-$dateKey-$appointmentId'),
            title: Text(
              'Appointment ${firstFeedback.referenceNumber ?? '#' + appointmentId.substring(0, 6)}',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
            ),
            subtitle: Text(
              '${feedbacks.length} feedback item${feedbacks.length == 1 ? '' : 's'}' +
              (firstFeedback.consultantName != null ? ' • ${firstFeedback.consultantName}' : '') +
              (firstFeedback.conciergeName != null ? ' • ${firstFeedback.conciergeName}' : ''),
              style: const TextStyle(fontSize: 11),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            initiallyExpanded: _expandedAppointments['$ministerId-$dateKey-$appointmentId'] ?? false,
            onExpansionChanged: (expanded) {
              setState(() {
                _expandedAppointments['$ministerId-$dateKey-$appointmentId'] = expanded;
              });
            },
            children: feedbacks.map((feedback) => _buildFeedbackItem(feedback)).toList(),
          ),
        ),
      );
    }
    
    return widgets;
  }

  Widget _buildFeedbackItem(FeedbackData feedback) {
    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Feedback questions and answers
          if (feedback.questions.isNotEmpty) ...[
            const Text('Feedback Questions:', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            ...feedback.questions.map((q) => Padding(
              padding: const EdgeInsets.only(left: 8.0, bottom: 4.0),
              child: Text(
                '• ${q['question']}: ${q['answer'] ?? 'No response'}',
                style: const TextStyle(fontSize: 13),
              ),
            )),
            const Divider(),
          ],
          
          // Additional comments
          if (feedback.comment?.isNotEmpty ?? false) ...[
            const Text('Additional Comments:', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(
              feedback.comment!,
              style: const TextStyle(fontStyle: FontStyle.italic, fontSize: 13),
            ),
            const SizedBox(height: 8),
          ],
          
          // Rating if available
          if (feedback.rating != null) ...[
            Row(
              children: [
                const Text('Rating: ', style: TextStyle(fontWeight: FontWeight.bold)),
                _buildRatingStars(feedback.rating!),
                const SizedBox(width: 4),
                Text('(${feedback.rating!.toStringAsFixed(1)})'),
              ],
            ),
            const SizedBox(height: 8),
          ],
          
          // Metadata
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                DateFormat('HH:mm').format(feedback.date),
                style: const TextStyle(fontSize: 11, color: Colors.grey),
              ),
              if (feedback.consultantName != null || feedback.conciergeName != null) ...[
                const Spacer(),
                Text(
                  [
                    if (feedback.consultantName != null) 'Consultant: ${feedback.consultantName}',
                    if (feedback.conciergeName != null) 'Concierge: ${feedback.conciergeName}',
                  ].join(' • '),
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Feedback Received'),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_today),
            onPressed: _selectMonth,
            tooltip: 'Select Month',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _buildFeedbackList(),
    );
  }
}
