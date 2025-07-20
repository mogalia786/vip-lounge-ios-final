import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:syncfusion_flutter_datepicker/datepicker.dart';

import '../../../../core/constants/colors.dart';
import '../../../../core/providers/app_auth_provider.dart';

class RatingsReceivedScreen extends StatefulWidget {
  const RatingsReceivedScreen({Key? key}) : super(key: key);

  @override
  _RatingsReceivedScreenState createState() => _RatingsReceivedScreenState();
}

class _RatingsReceivedScreenState extends State<RatingsReceivedScreen> {
  DateTime _selectedMonth = DateTime.now();
  bool _isLoading = true;
  List<Map<String, dynamic>> _ratings = [];
  Map<String, Map<String, dynamic>> _ministerRatings = {};
  Map<String, double> _consultantAverages = {};
  Map<String, double> _conciergeAverages = {};
  double _overallAverage = 0.0;
  int _totalRatings = 0;

  @override
  void initState() {
    super.initState();
    _fetchRatings();
  }

  Future<void> _fetchRatings() async {
    setState(() => _isLoading = true);
    
    try {
      // Get the first and last day of the selected month
      final firstDay = DateTime(_selectedMonth.year, _selectedMonth.month, 1);
      final lastDay = DateTime(_selectedMonth.year, _selectedMonth.month + 1, 0, 23, 59, 59);
      
      debugPrint('Fetching ratings from ${firstDay.toIso8601String()} to ${lastDay.toIso8601String()}');
      
      // Fetch ratings within the selected month
      final ratingsSnapshot = await FirebaseFirestore.instance
          .collection('ratings')
          .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(firstDay))
          .where('createdAt', isLessThanOrEqualTo: Timestamp.fromDate(lastDay))
          .get();

      debugPrint('Found ${ratingsSnapshot.docs.length} ratings in the selected period');
      
      _ratings = ratingsSnapshot.docs.map((doc) {
        final data = doc.data();
        debugPrint('Rating data: ${data.toString()}');
        return {
          'id': doc.id,
          ...data,
        };
      }).toList();

      _processRatings();
    } catch (e) {
      print('Error fetching ratings: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading ratings: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _processRatings() {
    _consultantAverages.clear();
    _conciergeAverages.clear();
    _ministerRatings.clear();
    
    double totalRating = 0;
    int ratingCount = 0;
    Map<String, int> consultantRatingCounts = {};
    Map<String, int> conciergeRatingCounts = {};

    for (var rating in _ratings) {
      final ratingValue = rating['rating']?.toDouble() ?? 0.0;
      final ratingType = rating['type']?.toString().toLowerCase() ?? '';
      final createdAt = rating['createdAt'] is Timestamp 
          ? (rating['createdAt'] as Timestamp).toDate() 
          : DateTime.now();

      // Process consultant ratings
      if (ratingType == 'consultant' && rating['consultantId'] != null) {
        final consultantId = rating['consultantId'];
        final consultantName = rating['consultantName'] ?? 'Unknown Consultant';
        
        _consultantAverages[consultantId] = (_consultantAverages[consultantId] ?? 0.0) + ratingValue;
        consultantRatingCounts[consultantId] = (consultantRatingCounts[consultantId] ?? 0) + 1;
        
        // Store minister's rating
        final ministerName = rating['userName'] ?? 'Anonymous Minister';
        if (!_ministerRatings.containsKey(consultantId)) {
          _ministerRatings[consultantId] = {
            'name': consultantName,
            'ratings': [],
          };
        }
        _ministerRatings[consultantId]!['ratings'].add({
          'from': ministerName,
          'value': ratingValue,
          'comment': rating['comment'],
          'date': createdAt,
        });
      }
      // Process concierge ratings
      else if (ratingType == 'concierge' && rating['conciergeId'] != null) {
        final conciergeId = rating['conciergeId'];
        final conciergeName = rating['conciergeName'] ?? 'Unknown Concierge';
        
        _conciergeAverages[conciergeId] = (_conciergeAverages[conciergeId] ?? 0.0) + ratingValue;
        conciergeRatingCounts[conciergeId] = (conciergeRatingCounts[conciergeId] ?? 0) + 1;
        
        // Store minister's rating
        final ministerName = rating['userName'] ?? 'Anonymous Minister';
        if (!_ministerRatings.containsKey(conciergeId)) {
          _ministerRatings[conciergeId] = {
            'name': conciergeName,
            'ratings': [],
          };
        }
        _ministerRatings[conciergeId]!['ratings'].add({
          'from': ministerName,
          'value': ratingValue,
          'comment': rating['comment'],
          'date': createdAt,
        });
      }

      totalRating += ratingValue;
      ratingCount++;
    }

    // Calculate overall average
    _overallAverage = ratingCount > 0 ? totalRating / ratingCount : 0.0;
    _totalRatings = ratingCount;

    // Calculate consultant and concierge averages
    _consultantAverages.forEach((key, value) {
      final count = consultantRatingCounts[key] ?? 1;
      _consultantAverages[key] = value / count;
    });

    _conciergeAverages.forEach((key, value) {
      final count = conciergeRatingCounts[key] ?? 1;
      _conciergeAverages[key] = value / count;
    });
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
              primary: Colors.white,
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
      await _fetchRatings();
    }
  }

  Widget _buildRatingStars(double rating, {double size = 24.0}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (index) {
        return Icon(
          index < rating.floor() ? Icons.star : Icons.star_border,
          color: Colors.amber,
          size: size,
        );
      }),
    );
  }

  Widget _buildAverageRatingsCard() {
    return Card(
      margin: const EdgeInsets.all(16.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Average Ratings',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildAverageRatingItem(
                  'Overall',
                  _overallAverage,
                  Icons.star,
                  _totalRatings,
                ),
                _buildAverageRatingItem(
                  'Consultant',
                  _consultantAverages.values.isNotEmpty
                      ? _consultantAverages.values.reduce((a, b) => a + b) / _consultantAverages.length
                      : 0.0,
                  Icons.person,
                  _consultantAverages.length,
                ),
                _buildAverageRatingItem(
                  'Concierge',
                  _conciergeAverages.values.isNotEmpty
                      ? _conciergeAverages.values.reduce((a, b) => a + b) / _conciergeAverages.length
                      : 0.0,
                  Icons.support_agent,
                  _conciergeAverages.length,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

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

  Widget _buildMinisterRatingItem(String staffId, Map<String, dynamic> data) {
    final name = data['name'];
    final ratings = List<Map<String, dynamic>>.from(data['ratings'] ?? []);
    
    // Calculate average rating
    double totalRating = 0;
    for (var rating in ratings) {
      totalRating += rating['value']?.toDouble() ?? 0.0;
    }
    final average = ratings.isNotEmpty ? totalRating / ratings.length : 0.0;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
      child: ExpansionTile(
        title: Text(
          name,
          style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Row(
              children: [
                _buildRatingStars(average, size: 16.0),
                const SizedBox(width: 8),
                Text(
                  '${average.toStringAsFixed(1)} (${ratings.length} ${ratings.length == 1 ? 'rating' : 'ratings'})',
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
              ],
            ),
            const SizedBox(height: 4),
          ],
        ),
        children: [
          const Divider(),
          if (ratings.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Text('No ratings received yet', style: TextStyle(fontStyle: FontStyle.italic)),
            )
          else
            ...ratings.map((rating) => _buildRatingDetailItem(
                  rating['from'] ?? 'Anonymous',
                  rating['value']?.toDouble() ?? 0.0,
                  rating['comment']?.toString(),
                  rating['date'] is Timestamp 
                      ? (rating['date'] as Timestamp).toDate() 
                      : (rating['date'] is DateTime ? rating['date'] as DateTime : DateTime.now()),
                )).toList(),
        ],
      ),
    );
  }

  Widget _buildRatingDetailItem(String from, double rating, String? comment, DateTime date) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'From: $from',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
              _buildRatingStars(rating, size: 16.0),
            ],
          ),
          const SizedBox(height: 8),
          if (comment?.isNotEmpty ?? false) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12.0),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8.0),
              ),
              child: Text(
                comment!,
                style: const TextStyle(fontSize: 14, height: 1.4),
              ),
            ),
            const SizedBox(height: 8),
          ],
          Text(
            'Rated on ${DateFormat('MMM d, y • hh:mm a').format(date)}',
            style: const TextStyle(color: Colors.grey, fontSize: 12),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Staff Ratings'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_today, color: Colors.white),
            onPressed: _selectMonth,
            tooltip: 'Select Month',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _ratings.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.star_outline, size: 64, color: Colors.grey),
                      const SizedBox(height: 16),
                      Text(
                        'No ratings found for ${DateFormat('MMMM y').format(_selectedMonth)}',
                        style: const TextStyle(fontSize: 16, color: Colors.grey),
                      ),
                    ],
                  ),
                )
              : SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildAverageRatingsCard(),
                      const SizedBox(height: 8),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: Row(
                          children: [
                            const Icon(Icons.calendar_today, size: 16, color: Colors.grey),
                            const SizedBox(width: 8),
                            Text(
                              'Showing ratings for ${DateFormat('MMMM y').format(_selectedMonth)}',
                              style: const TextStyle(color: Colors.grey, fontSize: 14),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      ..._ministerRatings.entries.map(
                        (entry) => _buildMinisterRatingItem(entry.key, entry.value),
                      ),
                    ],
                  ),
                ),
    );
  }
}
