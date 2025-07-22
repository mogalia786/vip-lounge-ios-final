import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/colors.dart';

// Data models
class FeedbackQuestion {
  final String id;
  final String questionText;
  
  FeedbackQuestion({required this.id, required this.questionText});
}

class FeedbackOption {
  final String id;
  final String questionId;
  final String responseLabel;
  final int responseScore;
  final int order;
  
  FeedbackOption({
    required this.id,
    required this.questionId,
    required this.responseLabel,
    required this.responseScore,
    required this.order,
  });
}

class AppointmentInfo {
  final String referenceNumber;
  final String typeOfVip;
  final String ministerFirstName;
  final String ministerLastName;
  final String consultantName;
  final String conciergeName;
  final DateTime appointmentDate;
  final String serviceId;
  
  AppointmentInfo({
    required this.referenceNumber,
    required this.typeOfVip,
    required this.ministerFirstName,
    required this.ministerLastName,
    required this.consultantName,
    required this.conciergeName,
    required this.appointmentDate,
    required this.serviceId,
  });
  
  String get ministerFullName => '$ministerFirstName $ministerLastName'.trim();
}

class FeedbackResponse {
  final String questionId;
  final int responseScore;
  final String questionText;
  final String selectedOptionText;
  final List<FeedbackOption> allOptions;
  
  FeedbackResponse({
    required this.questionId,
    required this.responseScore,
    required this.questionText,
    required this.selectedOptionText,
    required this.allOptions,
  });
}

class ClientFeedback {
  final String id;
  final String referenceNumber;
  final DateTime createdAt;
  final String? comment;
  final List<FeedbackResponse> responses;
  final AppointmentInfo appointmentInfo;
  
  ClientFeedback({
    required this.id,
    required this.referenceNumber,
    required this.createdAt,
    this.comment,
    required this.responses,
    required this.appointmentInfo,
  });
  
  double get averageScore {
    if (responses.isEmpty) return 0.0;
    double total = responses.fold(0.0, (sum, response) => sum + response.responseScore);
    return (total / responses.length) * (5.0 / 4.0); // Convert to /5 scale assuming max score is 4
  }
}

class FeedbackReceivedScreen extends StatefulWidget {
  const FeedbackReceivedScreen({Key? key}) : super(key: key);

  @override
  State<FeedbackReceivedScreen> createState() => _FeedbackReceivedScreenState();
}

class _FeedbackReceivedScreenState extends State<FeedbackReceivedScreen> {
  bool _isLoading = false;
  DateTime _selectedMonth = DateTime.now();
  
  // Step 2: Storage maps
  Map<String, AppointmentInfo> _appointmentsMap = {};
  Map<String, FeedbackQuestion> _questionsMap = {};
  Map<String, List<FeedbackOption>> _optionsMap = {};
  
  // Final hierarchy: Minister > Feedbacks
  Map<String, List<ClientFeedback>> _ministerFeedbacks = {};
  
  // Color scheme for ministers
  final List<Color> _ministerColors = [
    Colors.blue, Colors.green, Colors.red, Colors.purple,
    Colors.orange, Colors.teal, Colors.indigo, Colors.pink,
  ];

  @override
  void initState() {
    super.initState();
    _fetchAllData();
  }

  Color _getMinisterColor(int index) {
    return _ministerColors[index % _ministerColors.length];
  }

  Future<void> _fetchAllData() async {
    setState(() => _isLoading = true);
    
    try {
      debugPrint('🔍 Starting 4-step process...');
      
      // Calculate date range
      final startOfMonth = DateTime(_selectedMonth.year, _selectedMonth.month, 1);
      final endOfMonth = DateTime(_selectedMonth.year, _selectedMonth.month + 1, 0, 23, 59, 59);
      
      // STEP 1: Query Client_feedback collection
      debugPrint('📋 STEP 1: Fetching Client_feedback...');
      final feedbackQuery = await FirebaseFirestore.instance
          .collection('Client_feedback')
          .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfMonth))
          .where('createdAt', isLessThanOrEqualTo: Timestamp.fromDate(endOfMonth))
          .get();
      
      debugPrint('📊 Found ${feedbackQuery.docs.length} feedback documents');
      
      // Extract unique reference numbers
      Set<String> referenceNumbers = {};
      for (final doc in feedbackQuery.docs) {
        final refNum = doc.data()['referenceNumber']?.toString();
        if (refNum != null && refNum.isNotEmpty) {
          referenceNumbers.add(refNum);
        }
      }
      
      // STEP 2: Query appointments using referenceNumbers
      debugPrint('🏥 STEP 2: Fetching appointments for ${referenceNumbers.length} references...');
      _appointmentsMap.clear();
      
      for (final refNum in referenceNumbers) {
        final appointmentQuery = await FirebaseFirestore.instance
            .collection('appointments')
            .where('referenceNumber', isEqualTo: refNum)
            .limit(1)
            .get();
        
        if (appointmentQuery.docs.isNotEmpty) {
          final data = appointmentQuery.docs.first.data();
          _appointmentsMap[refNum] = AppointmentInfo(
            referenceNumber: refNum,
            typeOfVip: data['typeOfVip'] ?? 'Standard',
            ministerFirstName: data['ministerFirstName'] ?? '',
            ministerLastName: data['ministerLastName'] ?? '',
            consultantName: data['consultantName'] ?? 'Not assigned',
            conciergeName: data['conciergeName'] ?? 'Not assigned',
            appointmentDate: (data['appointmentTime'] as Timestamp?)?.toDate() ?? DateTime.now(),
            serviceId: data['serviceId'] ?? 'Unknown',
          );
        }
      }
      
      // STEP 3: Query Feedback_questions
      debugPrint('❓ STEP 3: Fetching all feedback questions...');
      final questionsQuery = await FirebaseFirestore.instance
          .collection('Feedback_questions')
          .get();
      
      _questionsMap.clear();
      for (final doc in questionsQuery.docs) {
        _questionsMap[doc.id] = FeedbackQuestion(
          id: doc.id,
          questionText: doc.data()['questionText'] ?? 'Question',
        );
      }
      debugPrint('📝 Stored ${_questionsMap.length} questions');
      
      // STEP 4: Query Feedback_options
      debugPrint('⚙️ STEP 4: Fetching all feedback options...');
      final optionsQuery = await FirebaseFirestore.instance
          .collection('Feedback_options')
          .orderBy('order')
          .get();
      
      _optionsMap.clear();
      for (final doc in optionsQuery.docs) {
        final data = doc.data();
        final questionId = data['questionId']?.toString();
        if (questionId != null) {
          if (!_optionsMap.containsKey(questionId)) {
            _optionsMap[questionId] = [];
          }
          _optionsMap[questionId]!.add(FeedbackOption(
            id: doc.id,
            questionId: questionId,
            responseLabel: data['responseLabel'] ?? 'Option',
            responseScore: data['responseScore'] ?? 0,
            order: data['order'] ?? 0,
          ));
        }
      }
      debugPrint('🎯 Stored options for ${_optionsMap.length} questions');
      
      // STEP 5: Build the hierarchy
      debugPrint('🏗️ STEP 5: Building Minister > Feedback > Questions hierarchy...');
      _ministerFeedbacks.clear();
      
      for (final doc in feedbackQuery.docs) {
        final data = doc.data();
        final refNum = data['referenceNumber']?.toString();
        
        if (refNum == null || !_appointmentsMap.containsKey(refNum)) continue;
        
        final appointmentInfo = _appointmentsMap[refNum]!;
        
        // Process enhanced responses
        List<FeedbackResponse> responses = [];
        final enhancedResponses = data['enhancedResponses'] as List<dynamic>? ?? [];
        
        for (final response in enhancedResponses) {
          if (response is Map<String, dynamic>) {
            final questionId = response['questionId']?.toString();
            final responseScore = response['responseScore'] ?? 0;
            
            if (questionId != null && _questionsMap.containsKey(questionId)) {
              final question = _questionsMap[questionId]!;
              final options = _optionsMap[questionId] ?? [];
              
              // Find selected option text
              String selectedOptionText = 'Option ${responseScore + 1}';
              for (final option in options) {
                if (option.responseScore == responseScore) {
                  selectedOptionText = option.responseLabel;
                  break;
                }
              }
              
              responses.add(FeedbackResponse(
                questionId: questionId,
                responseScore: responseScore,
                questionText: question.questionText,
                selectedOptionText: selectedOptionText,
                allOptions: options,
              ));
            }
          }
        }
        
        final feedback = ClientFeedback(
          id: doc.id,
          referenceNumber: refNum,
          createdAt: (data['createdAt'] as Timestamp).toDate(),
          comment: data['comment'],
          responses: responses,
          appointmentInfo: appointmentInfo,
        );
        
        // Group by minister
        final ministerName = appointmentInfo.ministerFullName.isEmpty 
            ? 'Unknown Minister' 
            : appointmentInfo.ministerFullName;
            
        if (!_ministerFeedbacks.containsKey(ministerName)) {
          _ministerFeedbacks[ministerName] = [];
        }
        _ministerFeedbacks[ministerName]!.add(feedback);
      }
      
      setState(() => _isLoading = false);
      debugPrint('✅ Hierarchy complete: ${_ministerFeedbacks.length} ministers, ${feedbackQuery.docs.length} total feedbacks');
      
    } catch (e) {
      debugPrint('❌ Error in fetch process: $e');
      setState(() => _isLoading = false);
    }
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
      setState(() => _selectedMonth = picked);
      _fetchAllData();
    }
  }

  double _calculateOverallAverage() {
    double totalScore = 0.0;
    int totalResponses = 0;
    
    for (final feedbacks in _ministerFeedbacks.values) {
      for (final feedback in feedbacks) {
        for (final response in feedback.responses) {
          totalScore += response.responseScore.toDouble();
          totalResponses++;
        }
      }
    }
    
    if (totalResponses == 0) return 0.0;
    return (totalScore / totalResponses) * (5.0 / 4.0); // Convert to /5 scale
  }

  Widget _buildAverageCard() {
    final average = _calculateOverallAverage();
    
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
            '${average.toStringAsFixed(2)}/5.0',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.bold,
            ),
          ),
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
      ),
    );
  }

  Widget _buildMinisterCard(String ministerName, List<ClientFeedback> feedbacks, int index) {
    final ministerColor = _getMinisterColor(index);
    final totalQuestions = feedbacks.fold<int>(0, (sum, feedback) => sum + feedback.responses.length);
    
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: ministerColor,
          radius: 24,
          child: Text(
            ministerName.isNotEmpty ? ministerName[0] : 'M',
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
          ),
        ),
        title: Text(
          ministerName,
          style: TextStyle(
            color: ministerColor,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: ministerColor.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${feedbacks.length} Feedbacks',
                style: TextStyle(color: ministerColor, fontWeight: FontWeight.bold, fontSize: 12),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '$totalQuestions Questions',
                style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold, fontSize: 12),
              ),
            ),
          ],
        ),
        children: [
          ...feedbacks.asMap().entries.map((entry) {
            final feedbackIndex = entry.key;
            final feedback = entry.value;
            return _buildFeedbackCard(feedback, ministerColor, feedbackIndex);
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildFeedbackCard(ClientFeedback feedback, Color ministerColor, int feedbackIndex) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: ExpansionTile(
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: ministerColor.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.feedback, color: ministerColor, size: 20),
          ),
          title: Text(
            'Feedback ${feedbackIndex + 1}',
            style: TextStyle(
              color: ministerColor,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                DateFormat('MMM dd, yyyy').format(feedback.createdAt),
                style: const TextStyle(fontSize: 14, color: Colors.grey),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.amber.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.amber, width: 1),
                ),
                child: Text(
                  'Ref: ${feedback.referenceNumber}',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                ),
              ),
            ],
          ),
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Questions and Responses
                  ...feedback.responses.asMap().entries.map((entry) {
                    final index = entry.key;
                    final response = entry.value;
                    
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
                                  response.questionText,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          
                          // All Options
                          const Text('Available Options:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                          const SizedBox(height: 6),
                          ...response.allOptions.map((option) {
                            final isSelected = option.responseScore == response.responseScore;
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
                                  Expanded(child: Text(option.responseLabel, style: const TextStyle(fontSize: 12))),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: isSelected ? ministerColor : Colors.grey.withOpacity(0.3),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      '${option.responseScore}',
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
                                    response.selectedOptionText,
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
                                    'Score: ${response.responseScore}',
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
                  
                  // Appointment Details
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue.withOpacity(0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Appointment Details:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        const SizedBox(height: 8),
                        Text('VIP Type: ${feedback.appointmentInfo.typeOfVip}'),
                        Text('Date: ${DateFormat('MMM dd, yyyy').format(feedback.appointmentInfo.appointmentDate)}'),
                        Text('Service ID: ${feedback.appointmentInfo.serviceId}'),
                        Text('Consultant: ${feedback.appointmentInfo.consultantName}'),
                        Text('Concierge: ${feedback.appointmentInfo.conciergeName}'),
                        Text('Average Score: ${feedback.averageScore.toStringAsFixed(2)}/5.0'),
                      ],
                    ),
                  ),
                  
                  // Comments
                  if (feedback.comment?.isNotEmpty ?? false) ...[
                    const SizedBox(height: 12),
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
                _buildAverageCard(),
                Expanded(
                  child: _ministerFeedbacks.isEmpty
                      ? const Center(
                          child: Text(
                            'No feedback found for this month',
                            style: TextStyle(fontSize: 16, color: Colors.grey),
                          ),
                        )
                      : ListView.builder(
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
}
