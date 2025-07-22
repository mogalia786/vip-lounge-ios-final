import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/colors.dart';

class FeedbackReceivedScreen extends StatefulWidget {
  const FeedbackReceivedScreen({super.key});

  @override
  State<FeedbackReceivedScreen> createState() => _FeedbackReceivedScreenState();
}

// Simplified data models for VIP_feedback collection
class VipFeedback {
  final String id;
  final String referenceNumber;
  final String ministerName;
  final String typeOfUser;
  final DateTime appointmentDateTime;
  final DateTime feedbackCreatedAt;
  final String consultantName;
  final String conciergeName;
  final List<QuestionResponse> questionResponses;
  final int totalScore;
  final int numberOfQuestions;

  VipFeedback({
    required this.id,
    required this.referenceNumber,
    required this.ministerName,
    required this.typeOfUser,
    required this.appointmentDateTime,
    required this.feedbackCreatedAt,
    required this.consultantName,
    required this.conciergeName,
    required this.questionResponses,
    required this.totalScore,
    required this.numberOfQuestions,
  });

  // This will be updated with the correct calculation in the state class
  double get averageScore => numberOfQuestions > 0 ? totalScore / numberOfQuestions : 0.0;
}

class QuestionResponse {
  final String questionLabel;
  final String text;
  final int selectedOption;
  final List<String> availableOptions;

  QuestionResponse({
    required this.questionLabel,
    required this.text,
    required this.selectedOption,
    required this.availableOptions,
  });
}

class _FeedbackReceivedScreenState extends State<FeedbackReceivedScreen> {
  bool _isLoading = true;
  DateTime _selectedMonth = DateTime.now();
  Map<String, List<VipFeedback>> _ministerFeedbacks = {};
  Map<String, List<String>> _optionsMap = {}; // questionId -> list of option labels
  List<String> _allOptionLabels = []; // All available option labels
  int _maxOptionsAvailable = 5; // Track the maximum number of options available

  @override
  void initState() {
    super.initState();
    _fetchAllData();
  }

  Future<void> _fetchAllData() async {
    setState(() => _isLoading = true);
    try {
      debugPrint('🔍 Fetching VIP_feedback data...');
      
      // Calculate date range
      final startOfMonth = DateTime(_selectedMonth.year, _selectedMonth.month, 1);
      final endOfMonth = DateTime(_selectedMonth.year, _selectedMonth.month + 1, 0, 23, 59, 59);
      
      // Simple read from Feedback_options collection
      debugPrint('🎯 Fetching options from Feedback_options...');
      
      final optionsQuery = await FirebaseFirestore.instance
          .collection('Feedback_options')
          .get();
      
      debugPrint('📊 Found ${optionsQuery.docs.length} documents in Feedback_options');
      
      _allOptionLabels.clear();
      List<Map<String, dynamic>> optionsWithOrder = [];
      
      // First, collect all options with their order information
      for (final doc in optionsQuery.docs) {
        final data = doc.data() as Map<String, dynamic>;
        debugPrint('🔍 Document ${doc.id}: $data');
        
        // Get the option label - try common field names
        String optionLabel = data['responseLabel']?.toString() ?? 
                            data['label']?.toString() ?? 
                            data['text']?.toString() ?? 
                            'Option ${optionsWithOrder.length + 1}';
        
        int order = data['order'] ?? 999; // Default high order for unordered items
        int score = data['responseScore'] ?? data['score'] ?? (optionsWithOrder.length + 1);
        
        optionsWithOrder.add({
          'label': optionLabel,
          'order': order,
          'score': score,
        });
        
        debugPrint('✅ Added option: "$optionLabel" with order: $order, score: $score');
      }
      
      // Sort options by order field
      optionsWithOrder.sort((a, b) => a['order'].compareTo(b['order']));
      
      // Extract sorted labels
      _allOptionLabels = optionsWithOrder.map((option) => option['label'] as String).toList();
      _maxOptionsAvailable = optionsWithOrder.isNotEmpty 
          ? optionsWithOrder.map((o) => o['score'] as int).reduce((a, b) => a > b ? a : b)
          : 5;
      
      debugPrint('🎯 Final options list: $_allOptionLabels');
      debugPrint('🔢 Total options: ${_allOptionLabels.length}');
      
      // Query VIP_feedback collection
      final vipFeedbackQuery = await FirebaseFirestore.instance
          .collection('VIP_feedback')
          .where('feedbackCreatedAt', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfMonth))
          .where('feedbackCreatedAt', isLessThanOrEqualTo: Timestamp.fromDate(endOfMonth))
          .orderBy('feedbackCreatedAt', descending: true)
          .get();
      
      debugPrint('📊 Found ${vipFeedbackQuery.docs.length} VIP_feedback documents');
      
      _ministerFeedbacks.clear();
      
      for (final doc in vipFeedbackQuery.docs) {
        final data = doc.data();
        
        final ministerName = data['ministerName']?.toString() ?? 'Unknown Minister';
        final referenceNumber = data['referenceNumber']?.toString() ?? '';
        final typeOfUser = data['typeOfUser']?.toString() ?? 'Standard';
        final appointmentDateTime = (data['appointmentDateTime'] as Timestamp?)?.toDate() ?? DateTime.now();
        final feedbackCreatedAt = (data['feedbackCreatedAt'] as Timestamp?)?.toDate() ?? DateTime.now();
        final consultantName = data['consultantName']?.toString() ?? 'Not assigned';
        final conciergeName = data['conciergeName']?.toString() ?? 'Not assigned';
        final totalScore = data['totalScore'] ?? 0;
        final numberOfQuestions = data['numberOfQuestions'] ?? 0;
        
        final questionResponsesData = data['questionResponses'] as List<dynamic>? ?? [];
        
        // Build question responses with available options from Feedback_options
        List<QuestionResponse> questionResponses = [];
        for (final questionData in questionResponsesData) {
          final questionMap = questionData as Map<String, dynamic>;
          final questionLabel = questionMap['questionLabel']?.toString() ?? 'Question';
          final text = questionMap['text']?.toString() ?? '';
          final selectedOption = questionMap['selectedOption'] ?? 1;
          
          // Use ONLY the actual options from Feedback_options collection
          List<String> availableOptions = _allOptionLabels;
          
          debugPrint('🎯 Using ${availableOptions.length} REAL options from Firestore for question "$questionLabel": $availableOptions');
          
          if (availableOptions.isEmpty) {
            debugPrint('⚠️ WARNING: No options loaded from Feedback_options collection!');
          }
          
          questionResponses.add(QuestionResponse(
            questionLabel: questionLabel,
            text: text,
            selectedOption: selectedOption,
            availableOptions: availableOptions,
          ));
          
          debugPrint('📝 Question: "$questionLabel", Selected: $selectedOption, Available: $availableOptions');
        }
        
        // Create VIP feedback object
        final vipFeedback = VipFeedback(
          id: doc.id,
          referenceNumber: referenceNumber,
          ministerName: ministerName,
          typeOfUser: typeOfUser,
          appointmentDateTime: appointmentDateTime,
          feedbackCreatedAt: feedbackCreatedAt,
          consultantName: consultantName,
          conciergeName: conciergeName,
          questionResponses: questionResponses,
          totalScore: totalScore,
          numberOfQuestions: numberOfQuestions,
        );
        
        // Group by minister name
        if (!_ministerFeedbacks.containsKey(ministerName)) {
          _ministerFeedbacks[ministerName] = [];
        }
        _ministerFeedbacks[ministerName]!.add(vipFeedback);
        
        debugPrint('✅ Added feedback for minister "$ministerName" with ${questionResponses.length} responses');
      }
      
      setState(() => _isLoading = false);
      debugPrint('✅ Data fetch complete: ${_ministerFeedbacks.length} ministers, ${vipFeedbackQuery.docs.length} total feedbacks');
      
    } catch (e) {
      debugPrint('❌ Error fetching VIP_feedback: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _selectMonth() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedMonth,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      helpText: 'Select Month',
    );
    
    if (picked != null && picked != _selectedMonth) {
      setState(() {
        _selectedMonth = DateTime(picked.year, picked.month);
      });
      _fetchAllData();
    }
  }

  double _calculateOverallAverage() {
    if (_ministerFeedbacks.isEmpty || _maxOptionsAvailable == 0) return 0.0;
    
    int totalScore = 0;
    int totalQuestions = 0;
    
    for (final feedbacks in _ministerFeedbacks.values) {
      for (final feedback in feedbacks) {
        totalScore += feedback.totalScore;
        totalQuestions += feedback.numberOfQuestions;
      }
    }
    
    if (totalQuestions == 0) return 0.0;
    
    // Calculate normalized average: (totalScore / (totalQuestions * maxOptions)) * 5
    // This converts any scale to a 5-point scale
    final maxPossibleScore = totalQuestions * _maxOptionsAvailable;
    final normalizedAverage = (totalScore / maxPossibleScore) * 5.0;
    
    debugPrint('🧮 Average calculation: totalScore=$totalScore, totalQuestions=$totalQuestions, maxOptions=$_maxOptionsAvailable');
    debugPrint('🧮 Normalized average: ($totalScore / ($totalQuestions * $_maxOptionsAvailable)) * 5 = $normalizedAverage');
    
    return normalizedAverage;
  }
  
  double _calculateMinisterAverage(List<VipFeedback> feedbacks) {
    if (feedbacks.isEmpty || _maxOptionsAvailable == 0) return 0.0;
    
    int totalScore = 0;
    int totalQuestions = 0;
    
    for (final feedback in feedbacks) {
      totalScore += feedback.totalScore;
      totalQuestions += feedback.numberOfQuestions;
    }
    
    if (totalQuestions == 0) return 0.0;
    
    // Calculate normalized average for this minister
    final maxPossibleScore = totalQuestions * _maxOptionsAvailable;
    final normalizedAverage = (totalScore / maxPossibleScore) * 5.0;
    
    return normalizedAverage;
  }

  Color _getMinisterColor(int index) {
    final colors = [
      AppColors.primary,
      Colors.blue.shade600,
      Colors.green.shade600,
      Colors.orange.shade600,
      Colors.purple.shade600,
      Colors.teal.shade600,
    ];
    return colors[index % colors.length];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppBar(
        title: const Text(
          'Feedback Received',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: AppColors.primary,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_month),
            onPressed: _selectMonth,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _ministerFeedbacks.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.feedback_outlined, size: 64, color: Colors.grey.shade400),
                      const SizedBox(height: 16),
                      Text(
                        'No feedback received for ${DateFormat('MMMM yyyy').format(_selectedMonth)}',
                        style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                )
              : Column(
                  children: [
                    // Overall average card
                    _buildAverageCard(),
                    // Minister feedbacks list
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _ministerFeedbacks.keys.length,
                        itemBuilder: (context, index) {
                          final ministerName = _ministerFeedbacks.keys.elementAt(index);
                          final feedbacks = _ministerFeedbacks[ministerName]!;
                          return _buildMinisterCard(ministerName, feedbacks, index);
                        },
                      ),
                    ),
                  ],
                ),
    );
  }

  Widget _buildAverageCard() {
    final overallAverage = _calculateOverallAverage();
    final totalFeedbacks = _ministerFeedbacks.values.fold(0, (sum, feedbacks) => sum + feedbacks.length);
    
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            'Overall Feedback Summary',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              Column(
                children: [
                  Text(
                    '${overallAverage.toStringAsFixed(1)}/5.0',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Text(
                    'Average Score',
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
              ),
              Column(
                children: [
                  Text(
                    '$totalFeedbacks',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Text(
                    'Total Feedbacks',
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
              ),
              Column(
                children: [
                  Text(
                    '${_ministerFeedbacks.keys.length}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Text(
                    'Ministers',
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMinisterCard(String ministerName, List<VipFeedback> feedbacks, int index) {
    final ministerColor = _getMinisterColor(index);
    final ministerAverage = _calculateMinisterAverage(feedbacks);
    
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: ministerColor,
          child: Text(
            ministerName.split(' ').map((n) => n.isNotEmpty ? n[0] : '').join().toUpperCase(),
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ),
        title: Text(
          ministerName,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        subtitle: Text(
          '${feedbacks.length} feedback${feedbacks.length != 1 ? 's' : ''} • Avg: ${ministerAverage.toStringAsFixed(1)}/5.0',
          style: TextStyle(color: Colors.grey.shade600),
        ),
        children: feedbacks.map((feedback) => _buildFeedbackCard(feedback, ministerColor)).toList(),
      ),
    );
  }

  Widget _buildFeedbackCard(VipFeedback feedback, Color ministerColor) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with appointment info
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Reference: ${feedback.referenceNumber}',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    Text(
                      'Type: ${feedback.typeOfUser}',
                      style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                    ),
                    Text(
                      'Appointment: ${DateFormat('MMM dd, yyyy h:mm a').format(feedback.appointmentDateTime)}',
                      style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                    ),
                    Text(
                      'Feedback: ${DateFormat('MMM dd, yyyy h:mm a').format(feedback.feedbackCreatedAt)}',
                      style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: ministerColor,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  '${feedback.averageScore.toStringAsFixed(1)}/5.0',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 12),
          
          // Staff info
          Row(
            children: [
              Expanded(
                child: Text(
                  'Consultant: ${feedback.consultantName}',
                  style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
                ),
              ),
              Expanded(
                child: Text(
                  'Concierge: ${feedback.conciergeName}',
                  style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // Questions and responses
          ...feedback.questionResponses.map((response) => _buildQuestionResponseCard(response)),
        ],
      ),
    );
  }

  Widget _buildQuestionResponseCard(QuestionResponse response) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Question
          Text(
            response.questionLabel,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
          
          const SizedBox(height: 8),
          
          // Available options with selected one highlighted
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: response.availableOptions.asMap().entries.map((entry) {
              final optionIndex = entry.key + 1; // 1-based indexing
              final optionText = entry.value;
              final isSelected = optionIndex == response.selectedOption;
              
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.primary : Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected ? AppColors.primary : Colors.grey.shade300,
                  ),
                ),
                child: Text(
                  '$optionIndex. $optionText',
                  style: TextStyle(
                    color: isSelected ? Colors.white : Colors.grey.shade700,
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              );
            }).toList(),
          ),
          
          // Comments (collapsible if long)
          if (response.text.isNotEmpty) ...[
            const SizedBox(height: 8),
            ExpansionTile(
              title: const Text(
                'Comments',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              ),
              tilePadding: EdgeInsets.zero,
              childrenPadding: const EdgeInsets.only(top: 8),
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    response.text,
                    style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
