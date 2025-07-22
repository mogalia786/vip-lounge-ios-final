import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/colors.dart';

class RatingsReceivedScreen extends StatefulWidget {
  const RatingsReceivedScreen({Key? key}) : super(key: key);

  @override
  _RatingsReceivedScreenState createState() => _RatingsReceivedScreenState();
}

// Simple data model for ratings
class StaffRating {
  final String id;
  final String referenceNumber;
  final String ministerName;
  final String staffName;
  final String staffType; // 'consultant' or 'concierge'
  final int rating;
  final String comment;
  final DateTime createdAt;
  final DateTime appointmentTime;

  StaffRating({
    required this.id,
    required this.referenceNumber,
    required this.ministerName,
    required this.staffName,
    required this.staffType,
    required this.rating,
    required this.comment,
    required this.createdAt,
    required this.appointmentTime,
  });

  double get normalizedRating => rating / 5.0; // Normalize to 5-point scale
}

class _RatingsReceivedScreenState extends State<RatingsReceivedScreen> {
  DateTime _selectedMonth = DateTime.now();
  bool _isLoading = true;
  Map<String, List<StaffRating>> _staffRatings = {};

  @override
  void initState() {
    super.initState();
    _fetchAllRatings();
  }

  Future<void> _fetchAllRatings() async {
    setState(() => _isLoading = true);
    try {
      debugPrint('🔍 Fetching ratings data...');
      
      // Calculate date range
      final startOfMonth = DateTime(_selectedMonth.year, _selectedMonth.month, 1);
      final endOfMonth = DateTime(_selectedMonth.year, _selectedMonth.month + 1, 0, 23, 59, 59);
      
      debugPrint('📅 Date range: ${startOfMonth.toIso8601String()} to ${endOfMonth.toIso8601String()}');
      
      // Fetch all ratings first (remove date filtering temporarily to see all data)
      final ratingsQuery = await FirebaseFirestore.instance
          .collection('ratings')
          .orderBy('timestamp', descending: true)
          .get();
          
      debugPrint('📊 Raw query returned ${ratingsQuery.docs.length} documents');
      
      debugPrint('📊 Found ${ratingsQuery.docs.length} ratings documents');
      
      _staffRatings.clear();
      
      for (final doc in ratingsQuery.docs) {
        final data = doc.data() as Map<String, dynamic>;
        
        debugPrint('🔍 Processing document ${doc.id}: $data');
        
        final referenceNumber = data['referenceNumber']?.toString() ?? '';
        final ministerName = data['ministerName']?.toString() ?? 'Unknown Minister';
        final rating = data['rating'] ?? data['score'] ?? 0;
        final comment = data['comment']?.toString() ?? data['notes']?.toString() ?? '';
        final createdAt = (data['timestamp'] as Timestamp?)?.toDate() ?? 
                         (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();
        final appointmentTime = (data['appointmentDate'] as Timestamp?)?.toDate() ?? 
                               (data['appointmentTime'] as Timestamp?)?.toDate() ?? DateTime.now();
        
        // Determine staff name and type from the data
        String staffName = '';
        String staffType = '';
        
        // From your Firestore data, I can see staffName and role fields
        if (data['staffName'] != null) {
          staffName = data['staffName']?.toString() ?? 'Unknown Staff';
          staffType = data['role']?.toString().toLowerCase() ?? 'staff';
        } else if (data['type'] == 'consultant' || data['consultantName'] != null) {
          staffName = data['consultantName']?.toString() ?? 'Unknown Consultant';
          staffType = 'consultant';
        } else if (data['type'] == 'concierge' || data['conciergeName'] != null) {
          staffName = data['conciergeName']?.toString() ?? 'Unknown Concierge';
          staffType = 'concierge';
        } else {
          // Fallback
          staffName = 'Unknown Staff';
          staffType = 'staff';
        }
        
        debugPrint('🔍 Processing rating: Staff="$staffName", Type="$staffType", Rating=$rating');
        
        // Create rating object
        final staffRating = StaffRating(
          id: doc.id,
          referenceNumber: referenceNumber,
          ministerName: ministerName,
          staffName: staffName,
          staffType: staffType,
          rating: rating,
          comment: comment,
          createdAt: createdAt,
          appointmentTime: appointmentTime,
        );
        
        // Group by staff name
        if (!_staffRatings.containsKey(staffName)) {
          _staffRatings[staffName] = [];
        }
        _staffRatings[staffName]!.add(staffRating);
        
        debugPrint('✅ Added rating for staff "$staffName" with rating $rating');
      }
      
      setState(() => _isLoading = false);
      debugPrint('✅ Data fetch complete: ${_staffRatings.length} staff members, ${ratingsQuery.docs.length} total ratings');
      
    } catch (e) {
      debugPrint('❌ Error fetching ratings: $e');
      setState(() => _isLoading = false);
    }
  }

  double _calculateAverageScore() {
    if (_staffRatings.isEmpty) return 0.0;
    
    double totalScore = 0.0;
    int totalRatings = 0;
    
    _staffRatings.values.forEach((ratings) {
      for (final rating in ratings) {
        totalScore += rating.normalizedRating * 5; // Convert back to 5-point scale
        totalRatings++;
      }
    });
    
    return totalRatings > 0 ? totalScore / totalRatings : 0.0;
  }
  
  int get _totalRatingsCount {
    return _staffRatings.values.fold(0, (sum, ratings) => sum + ratings.length);
  }

  // Get alternating colors for staff members (same pattern as feedback screen)
  Color _getStaffColor(int index) {
    final colors = [
      Colors.blue.shade600,
      Colors.green.shade600,
      Colors.orange.shade600,
      Colors.purple.shade600,
      Colors.teal.shade600,
      Colors.red.shade600,
    ];
    return colors[index % colors.length];
  }

  Widget _buildStaffRatingCard(String staffName, List<StaffRating> ratings, int index) {
    // Calculate average rating for this staff member
    double averageRating = ratings.isEmpty ? 0.0 : 
        ratings.map((r) => r.rating).reduce((a, b) => a + b) / ratings.length;
    
    // Get staff type (consultant/concierge) from first rating
    String staffType = ratings.isNotEmpty ? ratings.first.staffType : 'staff';
    
    // Get alternating color for this staff member
    final staffColor = _getStaffColor(index);
    
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: staffColor,
          child: Text(
            staffName.split(' ').map((n) => n.isNotEmpty ? n[0] : '').join().toUpperCase(),
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ),
        title: Text(
          staffName,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${staffType.toUpperCase()} • ${ratings.length} rating${ratings.length != 1 ? 's' : ''} • Avg: ${averageRating.toStringAsFixed(1)}/5.0',
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 8),
            // 5 Golden stars with average rating
            Row(
              children: [
                ...List.generate(5, (index) {
                  return Icon(
                    index < averageRating ? Icons.star : Icons.star_border,
                    color: Colors.amber,
                    size: 20,
                  );
                }),
                const SizedBox(width: 8),
                Text(
                  averageRating.toStringAsFixed(1),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  '/5.0',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 14,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
          ],
        ),
        children: ratings.map((rating) => _buildRatingDetailItem(rating)).toList(),
      ),
    );
  }
  
  Widget _buildRatingDetailItem(StaffRating rating) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with minister name and rating
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      rating.ministerName,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      'Ref: ${rating.referenceNumber}',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ...List.generate(5, (index) {
                        return Icon(
                          index < rating.rating ? Icons.star : Icons.star_border,
                          color: Colors.amber,
                          size: 16,
                        );
                      }),
                      const SizedBox(width: 4),
                      Text(
                        '${rating.rating}/5',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    DateFormat('MMM dd, HH:mm').format(rating.createdAt),
                    style: TextStyle(
                      color: Colors.grey[500],
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ],
          ),
          
          // Comment section
          if (rating.comment.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.blue[100]!),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.comment,
                    size: 16,
                    color: Colors.blue[600],
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      rating.comment,
                      style: TextStyle(
                        color: Colors.blue[800],
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
  
  Widget _buildAverageScoreCard() {
    final averageScore = _calculateAverageScore();
    final totalRatings = _totalRatingsCount;
    final monthName = DateFormat('MMMM yyyy').format(_selectedMonth);
    
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.primary, AppColors.primary.withOpacity(0.8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            'Staff Ratings - $monthName',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              Column(
                children: [
                  const Text(
                    'Average Rating',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    averageScore.toStringAsFixed(1),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: List.generate(5, (index) {
                      return Icon(
                        index < averageScore ? Icons.star : Icons.star_border,
                        color: Colors.amber,
                        size: 16,
                      );
                    }),
                  ),
                ],
              ),
              Container(
                height: 60,
                width: 1,
                color: Colors.white30,
              ),
              Column(
                children: [
                  const Text(
                    'Total Ratings',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    totalRatings.toString(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    '${_staffRatings.length} Staff',
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
    );
  }
  
  Future<void> _selectMonth() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedMonth,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDatePickerMode: DatePickerMode.year,
    );
    
    if (picked != null && picked != _selectedMonth) {
      setState(() {
        _selectedMonth = DateTime(picked.year, picked.month, 1);
      });
      _fetchAllRatings();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Staff Ratings Received',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: AppColors.primary,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_today),
            onPressed: _selectMonth,
            tooltip: 'Select Month',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            )
          : Column(
              children: [
                // Average score card at top
                _buildAverageScoreCard(),
                
                // Staff ratings list
                Expanded(
                  child: _staffRatings.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.star_border,
                                size: 64,
                                color: Colors.grey[400],
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'No ratings found',
                                style: TextStyle(
                                  fontSize: 18,
                                  color: Colors.grey[600],
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'for ${DateFormat('MMMM yyyy').format(_selectedMonth)}',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[500],
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _staffRatings.keys.length,
                          itemBuilder: (context, index) {
                            final staffName = _staffRatings.keys.elementAt(index);
                            final ratings = _staffRatings[staffName]!;
                            return _buildStaffRatingCard(staffName, ratings, index);
                          },
                        ),
                ),
              ],
            ),
    );
  }
}
