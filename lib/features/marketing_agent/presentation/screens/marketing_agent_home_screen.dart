import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../../../../core/constants/colors.dart';
import '../../../../core/providers/app_auth_provider.dart';
import '../../../auth/presentation/screens/login_screen.dart';
import './create_social_feed_post_screen.dart';
import '../../../../core/services/fcm_service.dart'; 
import 'package:vip_lounge/features/floor_manager/widgets/attendance_actions_widget.dart';

class MarketingAgentHomeScreen extends StatefulWidget {
  const MarketingAgentHomeScreen({super.key});

  @override
  State<MarketingAgentHomeScreen> createState() => _MarketingAgentHomeScreenState();
}

class _MarketingAgentHomeScreenState extends State<MarketingAgentHomeScreen> {
  final ScrollController _attendanceScrollController = ScrollController();
  final ScrollController _visualBarScrollController = ScrollController();
  List<Map<String, dynamic>> _posts = [];
  bool _isClockedIn = false;
  bool _isOnBreak = false;
  DateTime? _breakStartTime;
  List<Map<String, dynamic>> _breakHistory = [];
  final TextEditingController _breakReasonController = TextEditingController();
  bool _isLoading = false;
  String? _userId;
  String? _userName;
  String? _address;
  double? _latitude;
  double? _longitude;

  static const Map<String, Color> kTypeColors = {
    'Specials': Color(0xFF00C9A7),
    'Data Bundle Special': Color(0xFF1E90FF),
    'Device Specials': Color(0xFFFFA500),
    'Upgrade Specials': Color(0xFF8A2BE2),
    'New Contract Specials': Color(0xFF43A047),
    'Accessories Specials': Color(0xFFFB3C62),
  };

  Color getContrastTextColor(Color bg) {
    return bg.computeLuminance() > 0.5 ? Colors.black : Colors.white;
  }

  @override
  void initState() {
    // Initialize ScrollControllers
    _attendanceScrollController.addListener(() {});
    _visualBarScrollController.addListener(() {});
    super.initState();
    FCMService().init(); 
    WidgetsBinding.instance.addPostFrameCallback((_) => _initUser());
  }

  Future<void> _initUser() async {
    final appAuth = Provider.of<AppAuthProvider>(context, listen: false);
    setState(() {
      _userId = appAuth.appUser?.uid;
      _userName = appAuth.appUser?.firstName ?? 'Marketing Agent';
    });
    await _fetchPosts();
    await _loadBreakHistory();
  }

  Future<void> _fetchPosts() async {
    final snapshot = await FirebaseFirestore.instance.collection('marketing_posts').orderBy('createdAt', descending: true).get();
    setState(() {
      _posts = snapshot.docs.map((doc) => doc.data()).toList();
    });
  }

  Future<void> _deletePost(String postId) async {
    await FirebaseFirestore.instance.collection('marketing_posts').doc(postId).delete();
    _fetchPosts();
  }

  Future<void> _handleLogout(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    if (context.mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const LoginScreen()),
        (route) => false,
      );
    }
  }

  Future<void> _clockIn() async {
    if (_userId == null || _userName == null) return;
    final now = DateTime.now();
    await FirebaseFirestore.instance.collection('attendance').doc(_userId).set({
      'isClockedIn': true,
      'clockInTime': Timestamp.fromDate(now),
      'clockOutTime': null,
      'isOnBreak': false,
      'breakReason': null,
      'breakStartTime': null,
      'breakEndTime': null,
      'name': _userName,
      'role': 'marketing_agent',
    }, SetOptions(merge: true));
    setState(() {
      _isClockedIn = true;
    });
  }

  Future<void> _clockOut() async {
    if (_userId == null || _userName == null) return;
    final now = DateTime.now();
    await FirebaseFirestore.instance.collection('attendance').doc(_userId).set({
      'isClockedIn': false,
      'clockOutTime': Timestamp.fromDate(now),
      'isOnBreak': false,
      'breakReason': null,
      'breakStartTime': null,
      'breakEndTime': null,
      'name': _userName,
      'role': 'marketing_agent',
    }, SetOptions(merge: true));
    setState(() {
      _isClockedIn = false;
    });
  }

  Future<void> _startBreak(String reason) async {
    if (_userId == null || _userName == null) return;
    final now = DateTime.now();
    await FirebaseFirestore.instance.collection('attendance').doc(_userId).set({
      'isOnBreak': true,
      'breakReason': reason,
      'breakStartTime': Timestamp.fromDate(now),
      'breakEndTime': null,
      'name': _userName,
      'role': 'marketing_agent',
    }, SetOptions(merge: true));
    setState(() {
      _isOnBreak = true;
      _breakStartTime = now;
    });
  }

  Future<void> _endBreak() async {
    if (_userId == null || _userName == null) return;
    final now = DateTime.now();
    await FirebaseFirestore.instance.collection('attendance').doc(_userId).set({
      'isOnBreak': false,
      'breakEndTime': Timestamp.fromDate(now),
      'name': _userName,
      'role': 'marketing_agent',
    }, SetOptions(merge: true));
    setState(() {
      _isOnBreak = false;
    });
  }

  Future<void> _loadBreakHistory() async {
    if (_userId == null) return;
    final querySnapshot = await FirebaseFirestore.instance
        .collection('attendance')
        .doc(_userId)
        .collection('history')
        .orderBy('timestamp', descending: true)
        .limit(10)
        .get();
    setState(() {
      _breakHistory = querySnapshot.docs.map((doc) {
        return {
          'id': doc.id,
          ...doc.data(),
        };
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Marketing Posts',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        backgroundColor: AppColors.black,
        foregroundColor: AppColors.gold,
        actions: [
          if (!_isOnBreak)
            IconButton(
              icon: const Icon(Icons.add, color: AppColors.gold),
              tooltip: 'Create Post',
              onPressed: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => CreateSocialFeedPostScreen(
                      agentId: _userId ?? '',
                      agentName: _userName ?? 'Marketing Agent',
                    ),
                  ),
                );
                if (result == true) _fetchPosts();
              },
            ),
          IconButton(
            icon: const Icon(Icons.logout, color: AppColors.gold),
            onPressed: () => _handleLogout(context),
          ),
        ],
      ),
      backgroundColor: AppColors.black,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Scrollbar(
                        controller: _attendanceScrollController,
                        thumbVisibility: true,
                        thickness: 6,
                        radius: const Radius.circular(8),
                        child: SingleChildScrollView(
                          controller: _attendanceScrollController,
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              if (_userId != null && _userName != null)
                                AttendanceActionsWidget(
                                  userId: _userId!,
                                  name: _userName!,
                                  role: 'marketing_agent',
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                // Add a visual scrollbar track below the buttons
                SizedBox(
                  height: 8,
                  child: Scrollbar(
                    controller: _visualBarScrollController,
                    thumbVisibility: true,
                    thickness: 6,
                    radius: const Radius.circular(8),
                    child: SingleChildScrollView(
                      controller: _visualBarScrollController,
                      scrollDirection: Axis.horizontal,
                      child: SizedBox(width: 400), // Dummy width for visual bar
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (_isClockedIn && _isOnBreak && _breakStartTime != null)
            Padding(
              padding: const EdgeInsets.only(left: 16, bottom: 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('On break since: ' + _breakStartTime!.toLocal().toString().substring(0, 16), style: const TextStyle(color: Colors.redAccent)),
              ),
            ),
          if (_isClockedIn)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('Break History', style: TextStyle(color: AppColors.gold, fontWeight: FontWeight.bold)),
              ),
            ),
          if (_isClockedIn)
            SizedBox(
              height: 120,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _breakHistory.length,
                itemBuilder: (context, i) {
                  final b = _breakHistory[i];
                  final start = b['timestamp'] != null ? b['timestamp'].toDate() : null;
                  final reason = b['breakReason'] ?? '';
                  return Card(
                    color: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                      side: BorderSide(color: Colors.grey),
                    ),
                    margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    child: Container(
                      width: 200,
                      padding: const EdgeInsets.all(8),
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(reason, style: TextStyle(color: Colors.white)),
                            if (start != null)
                              Text('Start: ' + start.toString().substring(0, 16), style: TextStyle(color: Colors.grey)),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          Expanded(
            child: _posts.isEmpty
                ? const Center(child: Text('No posts yet.', style: TextStyle(color: AppColors.gold)))
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _posts.length,
                    itemBuilder: (context, index) {
                      final post = _posts[index];
                      final imageUrls = (post['imageUrls'] ?? []) as List?;
                      return Card(
                        elevation: 8,
                        color: Colors.black,
                        margin: const EdgeInsets.only(bottom: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (post['type'] != null && post['type'].toString().isNotEmpty)
                              Container(
                                decoration: BoxDecoration(
                                  color: kTypeColors[post['type']] ?? AppColors.gold,
                                  borderRadius: const BorderRadius.only(
                                    topLeft: Radius.circular(18),
                                    topRight: Radius.circular(18),
                                  ),
                                ),
                                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                                child: Text(
                                  post['type'],
                                  style: TextStyle(
                                    color: getContrastTextColor(kTypeColors[post['type']] ?? AppColors.gold),
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                    letterSpacing: 1.1,
                                  ),
                                ),
                              ),
                            ListTile(
                              contentPadding: const EdgeInsets.all(12),
                              leading: (imageUrls != null && imageUrls.isNotEmpty)
                                  ? ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: Image.network(imageUrls[0], width: 60, height: 60, fit: BoxFit.cover),
                                    )
                                  : const Icon(Icons.image, color: AppColors.gold, size: 40),
                              title: Text(
                                post['details'] ?? '',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (post['telephoneNumber'] != null)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 2),
                                      child: Text('Phone: ${post['telephoneNumber']}', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                                    ),
                                  if (post['termsAndConditions'] != null)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 2),
                                      child: Text('Terms: ${post['termsAndConditions']}', style: const TextStyle(color: Colors.white54, fontSize: 12)),
                                    ),
                                  if (post['beginDate'] != null && post['expirationDate'] != null)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 2),
                                      child: Text(
                                        'Valid: ${post['beginDate'].toDate().toString().substring(0, 10)} - ${post['expirationDate'].toDate().toString().substring(0, 10)}',
                                        style: const TextStyle(color: Colors.white38, fontSize: 12)),
                                    ),
                                ],
                              ),
                              trailing: IconButton(
                                icon: const Icon(Icons.delete, color: Colors.redAccent),
                                onPressed: () => _deletePost(post['id']),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),

    );
  }
}
