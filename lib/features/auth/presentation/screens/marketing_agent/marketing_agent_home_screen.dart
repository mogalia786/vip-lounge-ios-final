import 'package:flutter/material.dart';
import '../../../../../../core/constants/colors.dart';
import '../../../../../features/marketing_agent/presentation/widgets/marketing_agent_clock_in_out_widget.dart';

class MarketingAgentHomeScreen extends StatefulWidget {
  const MarketingAgentHomeScreen({super.key});

  @override
  State<MarketingAgentHomeScreen> createState() => _MarketingAgentHomeScreenState();
}

class _MarketingAgentHomeScreenState extends State<MarketingAgentHomeScreen> {
  bool _isClockedIn = false;
  String? _address;

  void _handleClockIn() {
    setState(() {
      _isClockedIn = true;
      _address = 'Demo Address, City'; // Replace with actual location logic
    });
  }

  void _handleClockOut() {
    setState(() {
      _isClockedIn = false;
      _address = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.black,
      appBar: AppBar(
        title: const Text('Marketing Agent Home'),
        backgroundColor: AppColors.black,
        foregroundColor: AppColors.primary,
      ),
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          MarketingAgentClockInOutWidget(
            agentId: 'demo_agent_id',
            isClockedIn: _isClockedIn,
            address: _address,
            onClockIn: _handleClockIn,
            onClockOut: _handleClockOut,
          ),
          const SizedBox(height: 24),
          if (!_isClockedIn)
            const Text('Please clock in to access marketing features.', style: TextStyle(color: Colors.redAccent)),
        ],
      ),
    );
  }
}
