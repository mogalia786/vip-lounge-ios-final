import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';

// Model for option data
class OptionData {
  final String id;
  final String text;
  final int score;
  final int order;

  OptionData({
    required this.id,
    required this.text,
    required this.score,
    required this.order,
  });
}

// Model for question responses
class QuestionResponse {
  final String questionId;
  final String questionText;
  final List<OptionData> availableOptions;
  final String selectedOptionId;
  final String selectedOptionText;
  final int selectedScore;

  QuestionResponse({
    required this.questionId,
    required this.questionText,
    required this.availableOptions,
    required this.selectedOptionId,
    required this.selectedOptionText,
    required this.selectedScore,
  });
}

// Model to hold feedback data
class FeedbackData {
  final String id;
  final String ministerId;
  final String ministerName;
  final String appointmentId;
  final String? referenceNumber;
  final String? serviceId;
  final DateTime date;
  final List<QuestionResponse> questions;
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
    this.serviceId,
    required this.date,
    required this.questions,
    this.comment,
    this.consultantName,
    this.conciergeName,
    this.rating,
  });
}

class FeedbackReceivedScreen extends StatefulWidget {
  const FeedbackReceivedScreen({Key? key}) : super(key: key);

  @override
  _FeedbackReceivedScreenState createState() => _FeedbackReceivedScreenState();
}

class _FeedbackReceivedScreenState extends State<FeedbackReceivedScreen> {
  bool _isLoading = false;
  DateTime _selectedMonth = DateTime.now();
  List<FeedbackData> _allFeedback = [];
  
  // Color scheme for ministers
  final List<Color> _ministerColors = [
    Colors.blue,
    Colors.green,
    Colors.red,
    Colors.purple,
    Colors.orange,
    Colors.teal,
    Colors.indigo,
    Colors.pink,
  ];

  @override
  void initState() {
    super.initState();
    _fetchFeedback();
  }

  Color _getMinisterColor(int index) {
    return _ministerColors[index % _ministerColors.length];
  }

  Future<void> _fetchFeedback() async {
    setState(() => _isLoading = true);
    
    try {
      debugPrint('🔍 Fetching feedback for ${DateFormat('MMMM yyyy').format(_selectedMonth)}');
      
      // Calculate date range for the selected month
      final startOfMonth = DateTime(_selectedMonth.year, _selectedMonth.month, 1);
      final endOfMonth = DateTime(_selectedMonth.year, _selectedMonth.month + 1, 0, 23, 59, 59);
      
      // Query Client_feedback collection
      final feedbackQuery = await FirebaseFirestore.instance
          .collection('Client_feedback')
          .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfMonth))
          .where('createdAt', isLessThanOrEqualTo: Timestamp.fromDate(endOfMonth))
          .orderBy('createdAt', descending: true)
          .get();

      debugPrint('📊 Found ${feedbackQuery.docs.length} feedback documents');

      List<FeedbackData> feedbackList = [];

      for (final doc in feedbackQuery.docs) {
        final data = doc.data();
        debugPrint('📋 Processing feedback: ${doc.id}');
        
        // Get appointment details
        final appointmentId = data['appointmentId'];
        if (appointmentId == null) continue;
        
        // Fetch appointment details
        final appointmentDoc = await FirebaseFirestore.instance
            .collection('appointments')
            .doc(appointmentId)
            .get();
            
        if (!appointmentDoc.exists) continue;
        
        final appointmentData = appointmentDoc.data()!;
        final serviceId = appointmentData['serviceId'] ?? appointmentData['service_id'] ?? 'Unknown';
        final consultantName = appointmentData['consultantName'] ?? 'Not assigned';
        final conciergeName = appointmentData['conciergeName'] ?? 'Not assigned';
        
        // Get minister details
        final ministerId = data['ministerId'] ?? appointmentData['ministerId'] ?? '';
        final ministerFirstName = appointmentData['ministerFirstname'] ?? '';
        final ministerLastName = appointmentData['ministerLastname'] ?? '';
        final ministerName = '$ministerFirstName $ministerLastName'.trim();
        
        // Process questions and responses
        List<QuestionResponse> questionResponses = [];
        final responses = data['responses'] as List<dynamic>? ?? [];
        
        for (final response in responses) {
          if (response is Map<String, dynamic>) {
            final questionId = response['questionId']?.toString();
            final selectedOptionId = response['selectedOptionId']?.toString();
            
            if (questionId != null && selectedOptionId != null) {
              // Fetch question details
              final questionDoc = await FirebaseFirestore.instance
                  .collection('Feedback_questions')
                  .doc(questionId)
                  .get();
              
              if (!questionDoc.exists) continue;
              
              final questionData = questionDoc.data()!;
              final questionText = questionData['questionText'] ?? questionData['text'] ?? 'Question';
              
              // Fetch all options for this question
              final optionsQuery = await FirebaseFirestore.instance
                  .collection('Feedback_options')
                  .where('questionId', isEqualTo: questionId)
                  .orderBy('order')
                  .get();
              
              List<OptionData> options = [];
              String selectedOptionText = 'Unknown';
              int selectedScore = 0;
              
              for (final optionDoc in optionsQuery.docs) {
                final optionData = optionDoc.data();
                final option = OptionData(
                  id: optionDoc.id,
                  text: optionData['optionText'] ?? optionData['text'] ?? 'Option',
                  score: optionData['score'] ?? optionData['value'] ?? 0,
                  order: optionData['order'] ?? 0,
                );
                options.add(option);
                
                // Check if this is the selected option
                if (optionDoc.id == selectedOptionId) {
                  selectedOptionText = option.text;
                  selectedScore = option.score;
                }
              }
              
              questionResponses.add(QuestionResponse(
                questionId: questionId,
                questionText: questionText,
                availableOptions: options,
                selectedOptionId: selectedOptionId,
                selectedOptionText: selectedOptionText,
                selectedScore: selectedScore,
              ));
            }
          }
        }
        
        // Create feedback data
        final feedback = FeedbackData(
          id: doc.id,
          ministerId: ministerId,
          ministerName: ministerName.isEmpty ? 'Unknown Minister' : ministerName,
          appointmentId: appointmentId,
          serviceId: serviceId,
          date: (data['createdAt'] as Timestamp).toDate(),
          questions: questionResponses,
          comment: data['comment'],
          consultantName: consultantName,
          conciergeName: conciergeName,
          rating: data['averageScore']?.toDouble(),
        );
        
        feedbackList.add(feedback);
        debugPrint('✅ Added feedback for ${feedback.ministerName} with ${feedback.questions.length} questions');
      }

      setState(() {
        _allFeedback = feedbackList;
        _isLoading = false;
      });
      
      debugPrint('🎉 Loaded ${_allFeedback.length} complete feedback records');
      
    } catch (e) {
      debugPrint('❌ Error fetching feedback: $e');
      setState(() => _isLoading = false);
    }
  }

  double _calculateMonthlyAverage() {
    if (_allFeedback.isEmpty) return 0.0;
    
    double totalScore = 0.0;
    double totalPossible = 0.0;
    
    for (final feedback in _allFeedback) {
      for (final question in feedback.questions) {
        totalScore += question.selectedScore.toDouble();
        // Find max possible score for this question
        final maxScore = question.availableOptions.isNotEmpty 
            ? question.availableOptions.map((o) => o.score).reduce((a, b) => a > b ? a : b)
            : 5;
        totalPossible += maxScore.toDouble();
      }
    }
    
    if (totalPossible == 0) return 0.0;
    
    final ratio = totalScore / totalPossible;
    final average = ratio * 5.0; // Convert to /5 scale
    
    debugPrint('📊 Monthly Average: $totalScore/$totalPossible = ${average.toStringAsFixed(2)}/5.0');
    return average;
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
        _selectedMonth = picked;
      });
      _fetchFeedback();
    }
  }

  Widget _buildFeedbackCard(FeedbackData feedback, int ministerIndex) {
    final ministerColor = _getMinisterColor(ministerIndex);
    
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 6,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        children: [
          // Minister Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: ministerColor,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: Colors.white,
                  child: Text(
                    feedback.ministerName.isNotEmpty ? feedback.ministerName[0] : 'M',
                    style: TextStyle(
                      color: ministerColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        feedback.ministerName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        DateFormat('MMM dd, yyyy').format(feedback.date),
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          // Content
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Service ID
                if (feedback.serviceId != null) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: ministerColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: ministerColor.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.business_center, color: ministerColor, size: 16),
                        const SizedBox(width: 8),
                        const Text('Service ID: ', style: TextStyle(fontWeight: FontWeight.bold)),
                        Text(feedback.serviceId!, style: const TextStyle(fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                
                // Staff Information
                if (feedback.consultantName != null || feedback.conciergeName != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Staff:', style: TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        if (feedback.consultantName != null)
                          Text('Consultant: ${feedback.consultantName}'),
                        if (feedback.conciergeName != null)
                          Text('Concierge: ${feedback.conciergeName}'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                
                // Questions and Responses
                ...feedback.questions.asMap().entries.map((entry) {
                  final index = entry.key;
                  final question = entry.value;
                  
                  return Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      border: Border.all(color: ministerColor.withOpacity(0.3)),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Question Header
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 12,
                              backgroundColor: ministerColor,
                              child: Text(
                                '${index + 1}',
                                style: const TextStyle(color: Colors.white, fontSize: 12),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                question.questionText,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        
                        // All Options
                        const Text('Available Options:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                        const SizedBox(height: 6),
                        ...question.availableOptions.map((option) {
                          final isSelected = option.id == question.selectedOptionId;
                          return Container(
                            margin: const EdgeInsets.only(bottom: 4),
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                            decoration: BoxDecoration(
                              color: isSelected ? ministerColor.withOpacity(0.1) : Colors.grey.withOpacity(0.05),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                color: isSelected ? ministerColor : Colors.grey.withOpacity(0.3),
                                width: isSelected ? 2 : 1,
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                                  color: isSelected ? ministerColor : Colors.grey,
                                  size: 16,
                                ),
                                const SizedBox(width: 6),
                                Expanded(child: Text(option.text, style: const TextStyle(fontSize: 12))),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: isSelected ? ministerColor : Colors.grey.withOpacity(0.3),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    '${option.score}',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: isSelected ? Colors.white : Colors.black54,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                        
                        const SizedBox(height: 8),
                        
                        // Selected Summary
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: ministerColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.check_circle, color: ministerColor, size: 16),
                              const SizedBox(width: 6),
                              const Text('Selected: ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                              Expanded(
                                child: Text(
                                  question.selectedOptionText,
                                  style: TextStyle(color: ministerColor, fontWeight: FontWeight.w600, fontSize: 12),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: ministerColor,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  'Score: ${question.selectedScore}',
                                  style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
                
                // Comments
                if (feedback.comment?.isNotEmpty ?? false) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Comments:', style: TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        Text(feedback.comment!),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMonthlyAverageCard() {
    final average = _calculateMonthlyAverage();
    
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue.shade600, Colors.blue.shade800],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          const Text(
            'Monthly Average Score',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            DateFormat('MMMM yyyy').format(_selectedMonth),
            style: const TextStyle(color: Colors.white70, fontSize: 14),
          ),
          const SizedBox(height: 16),
          Text(
            average > 0 ? '${average.toStringAsFixed(2)}/5.0' : 'No data',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (average > 0) ...[
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (index) {
                return Icon(
                  index < average.floor()
                      ? Icons.star
                      : index < average.ceil()
                          ? Icons.star_half
                          : Icons.star_border,
                  color: Colors.amber,
                  size: 24,
                );
              }),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Feedback Received'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
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
          : Column(
              children: [
                _buildMonthlyAverageCard(),
                Expanded(
                  child: _allFeedback.isEmpty
                      ? const Center(
                          child: Text(
                            'No feedback found for this month',
                            style: TextStyle(fontSize: 16, color: Colors.grey),
                          ),
                        )
                      : ListView.builder(
                          itemCount: _allFeedback.length,
                          itemBuilder: (context, index) {
                            return _buildFeedbackCard(_allFeedback[index], index);
                          },
                        ),
                ),
              ],
            ),
    );
  }
}
