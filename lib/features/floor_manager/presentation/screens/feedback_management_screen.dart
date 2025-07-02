import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/constants/colors.dart';

class FeedbackManagementScreen extends StatefulWidget {
  const FeedbackManagementScreen({Key? key}) : super(key: key);

  @override
  State<FeedbackManagementScreen> createState() => _FeedbackManagementScreenState();
}

class _FeedbackManagementScreenState extends State<FeedbackManagementScreen> {
  // Firestore refs
  final CollectionReference questionsRef = FirebaseFirestore.instance.collection('Feedback_questions');
  final CollectionReference optionsRef = FirebaseFirestore.instance.collection('Feedback_options');

  // Controllers
  final TextEditingController _questionController = TextEditingController();
  final TextEditingController _optionController = TextEditingController();
  final TextEditingController _scoreController = TextEditingController();

  String? editingQuestionId;
  String? editingOptionId;

  @override
  void dispose() {
    _questionController.dispose();
    _optionController.dispose();
    _scoreController.dispose();
    super.dispose();
  }

  void _showQuestionDialog({String? question, String? id}) {
    _questionController.text = question ?? '';
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.black,
        title: Text(id == null ? 'Add Question' : 'Edit Question', style: TextStyle(color: AppColors.primary)),
        content: TextField(
          controller: _questionController,
          style: TextStyle(color: Colors.white),
          decoration: InputDecoration(hintText: 'Enter question', hintStyle: TextStyle(color: Colors.grey)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Cancel', style: TextStyle(color: AppColors.primary)),
          ),
          TextButton(
            onPressed: () async {
              final text = _questionController.text.trim();
              if (text.isNotEmpty) {
                if (id == null) {
                  await questionsRef.add({'question': text});
                } else {
                  await questionsRef.doc(id).update({'question': text});
                }
                Navigator.of(context).pop();
              }
            },
            child: Text('Save', style: TextStyle(color: AppColors.primary)),
          ),
        ],
      ),
    );
  }

  void _showOptionDialog({String? option, int? score, String? id}) {
    _optionController.text = option ?? '';
    _scoreController.text = score?.toString() ?? '';
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.black,
        title: Text(id == null ? 'Add Option' : 'Edit Option', style: TextStyle(color: AppColors.primary)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _optionController,
              style: TextStyle(color: Colors.white),
              decoration: InputDecoration(hintText: 'Enter option', hintStyle: TextStyle(color: Colors.grey)),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _scoreController,
              keyboardType: TextInputType.number,
              style: TextStyle(color: Colors.white),
              decoration: InputDecoration(hintText: 'Enter score (e.g. 0, 1, 2...)', hintStyle: TextStyle(color: Colors.grey)),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Cancel', style: TextStyle(color: AppColors.primary)),
          ),
          TextButton(
            onPressed: () async {
              final text = _optionController.text.trim();
              final scoreText = _scoreController.text.trim();
              final scoreVal = int.tryParse(scoreText) ?? 0;
              if (text.isNotEmpty) {
                if (id == null) {
                  await optionsRef.add({'label': text, 'score': scoreVal});
                } else {
                  await optionsRef.doc(id).update({'label': text, 'score': scoreVal});
                }
                Navigator.of(context).pop();
              }
            },
            child: Text('Save', style: TextStyle(color: AppColors.primary)),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteQuestion(String id) async {
    await questionsRef.doc(id).delete();
  }

  Future<void> _deleteOption(String id) async {
    await optionsRef.doc(id).delete();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: IconThemeData(color: AppColors.primary),
        title: Text('Feedback Management', style: TextStyle(color: AppColors.primary)),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Questions CRUD (Top Half)
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Questions', style: TextStyle(color: AppColors.primary, fontSize: 18, fontWeight: FontWeight.bold)),
                      IconButton(
                        icon: Icon(Icons.add, color: AppColors.primary),
                        onPressed: () => _showQuestionDialog(),
                        tooltip: 'Add Question',
                      ),
                    ],
                  ),
                  Expanded(
                    child: StreamBuilder<QuerySnapshot>(
                      stream: questionsRef.snapshots(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return Center(child: CircularProgressIndicator(color: AppColors.primary));
                        }
                        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                          return Center(child: Text('No questions found.', style: TextStyle(color: Colors.white70)));
                        }
                        return ListView(
                          children: snapshot.data!.docs.map((doc) {
                            final data = doc.data() as Map<String, dynamic>;
                            return ListTile(
                              title: Text(data['question'] ?? '', style: TextStyle(color: Colors.white)),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: Icon(Icons.edit, color: AppColors.primary),
                                    onPressed: () => _showQuestionDialog(question: data['question'], id: doc.id),
                                  ),
                                  IconButton(
                                    icon: Icon(Icons.delete, color: Colors.red),
                                    onPressed: () => _deleteQuestion(doc.id),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            Divider(color: Colors.grey[800]),
            // Options CRUD (Bottom Half)
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Feedback Options', style: TextStyle(color: AppColors.primary, fontSize: 18, fontWeight: FontWeight.bold)),
                      IconButton(
                        icon: Icon(Icons.add, color: AppColors.primary),
                        onPressed: () => _showOptionDialog(),
                        tooltip: 'Add Option',
                      ),
                    ],
                  ),
                  Expanded(
                    child: StreamBuilder<QuerySnapshot>(
                      stream: optionsRef.snapshots(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return Center(child: CircularProgressIndicator(color: AppColors.primary));
                        }
                        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                          return Center(child: Text('No options found.', style: TextStyle(color: Colors.white70)));
                        }
                        return ListView(
                          children: snapshot.data!.docs.map((doc) {
                            final data = doc.data() as Map<String, dynamic>;
                            return ListTile(
                              title: Text(
                                '${data['label'] ?? ''} - (${data['score'] ?? 0})',
                                style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold),
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: Icon(Icons.edit, color: AppColors.primary),
                                    onPressed: () => _showOptionDialog(option: data['label'], score: data['score'], id: doc.id),
                                  ),
                                  IconButton(
                                    icon: Icon(Icons.delete, color: Colors.red),
                                    onPressed: () => _deleteOption(doc.id),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
