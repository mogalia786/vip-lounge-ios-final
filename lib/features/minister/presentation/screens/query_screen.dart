import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/constants/colors.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../../core/providers/app_auth_provider.dart';
import 'package:vip_lounge/core/services/vip_query_service.dart';
import 'package:vip_lounge/core/services/vip_notification_service.dart';

class QueryScreen extends StatefulWidget {
  const QueryScreen({super.key});

  @override
  State<QueryScreen> createState() => _QueryScreenState();
}

class _QueryScreenState extends State<QueryScreen> {
  final _queryController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }

  Future<void> _submitQuery() async {
    if (_queryController.text.trim().isEmpty) return;

    setState(() {
      _isLoading = true;
    });

    try {
      // Get minister info from provider
      final authProvider = Provider.of<AppAuthProvider>(context, listen: false);
      final ministerData = authProvider.ministerData;
      if (ministerData == null) throw Exception('Minister data not found');
      final ministerId = ministerData['uid'] ?? '';
      final ministerFirstName = ministerData['firstName'] ?? '';
      final ministerLastName = ministerData['lastName'] ?? '';
      final ministerEmail = ministerData['email'] ?? '';
      final ministerPhone = ministerData['phoneNumber'] ?? '';
      final subject = 'General Query';
      final queryText = _queryController.text.trim();
      final refNumber = await VipQueryService().submitMinisterQuery(
        ministerId: ministerId,
        ministerFirstName: ministerFirstName,
        ministerLastName: ministerLastName,
        ministerEmail: ministerEmail,
        ministerPhone: ministerPhone,
        subject: subject,
        queryText: queryText,
      );
      // Send notification to minister
      await VipNotificationService().createNotification(
        title: 'Query Received',
        body: 'Your query ($refNumber) has been received. We will get back to you shortly.',
        data: {
          'referenceNumber': refNumber,
          'query': queryText,
          'status': 'pending',
        },
        role: 'minister',
        assignedToId: ministerId,
        notificationType: 'query_acknowledgement',
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Query submitted successfully!',
            style: TextStyle(color: Colors.black),
          ),
          backgroundColor: AppColors.richGold,
        ),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Error submitting query: $e',
            style: TextStyle(color: Colors.white),
          ),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Text(
          'Submit Query',
          style: TextStyle(color: AppColors.richGold),
        ),
        iconTheme: IconThemeData(color: AppColors.richGold),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            GlassCard(
              child: TextField(
                controller: _queryController,
                maxLines: 5,
                style: TextStyle(color: AppColors.richGold),
                decoration: InputDecoration(
                  hintText: 'Enter your query here...',
                  hintStyle: TextStyle(color: AppColors.richGold.withOpacity(0.5)),
                  border: InputBorder.none,
                ),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _isLoading ? null : _submitQuery,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.richGold,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
                      ),
                    )
                  : const Text(
                      'Submit Query',
                      style: TextStyle(fontSize: 16),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
