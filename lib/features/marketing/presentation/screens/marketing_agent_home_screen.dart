import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../../core/constants/colors.dart';
import '../../../../core/providers/app_auth_provider.dart';
import '../../data/models/marketing_post.dart';
import '../../widgets/attendance_actions_widget.dart';
import '../../../../core/services/fcm_service.dart';
import '../../../../core/services/attendance_location_service.dart';
import '../../../../core/services/device_location_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MarketingAgentHomeScreen extends StatefulWidget {
  const MarketingAgentHomeScreen({super.key});

  @override
  State<MarketingAgentHomeScreen> createState() => _MarketingAgentHomeScreenState();
}

class _MarketingAgentHomeScreenState extends State<MarketingAgentHomeScreen> {
  final List<MarketingPost> _posts = [];
  int _selectedIndex = 0;
  bool _isClockedIn = false;
  String? _address;
  // Break logic
  bool _isOnBreak = false;
  DateTime? _breakStartTime;
  List<Map<String, dynamic>> _breakHistory = [];
  final TextEditingController _breakReasonController = TextEditingController();
  bool _isLoading = false;
  String? _userId;

  @override
  void initState() {
    super.initState();
    FCMService().init();
    WidgetsBinding.instance.addPostFrameCallback((_) => _initUser());
  }

  Future<void> _initUser() async {
    final appAuth = Provider.of<AppAuthProvider>(context, listen: false);
    setState(() {
      _userId = appAuth.appUser?.uid;
    });
    await _loadBreakHistory();
  }

  @override
  void dispose() {
    _breakReasonController.dispose();
    super.dispose();
  }

  Future<void> _handleClockIn() async {
    try {
      bool testMode = false;
      final prefs = await SharedPreferences.getInstance();
      testMode = prefs.getBool('test_mode') ?? false;
      if (!testMode) {
        final userLocation = await DeviceLocationService.getCurrentUserLocation(context);
        if (userLocation == null) return;
        bool isAllowed = await AttendanceLocationService.isWithinAllowedDistance(userLocation: userLocation);
        if (!isAllowed) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('You are not within the allowed area to clock in.')),
          );
          return;
        }
      }
      setState(() {
        _isClockedIn = true;
      });
      // Optionally: Store attendance record in Firestore here
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error clocking in: $e')),
      );
    }
  }

  Future<void> _handleClockOut() async {
    try {
      bool testMode = false;
      final prefs = await SharedPreferences.getInstance();
      testMode = prefs.getBool('test_mode') ?? false;
      if (!testMode) {
        final userLocation = await DeviceLocationService.getCurrentUserLocation(context);
        if (userLocation == null) return;
        bool isAllowed = await AttendanceLocationService.isWithinAllowedDistance(userLocation: userLocation);
        if (!isAllowed) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('You are not within the allowed area to clock out.')),
          );
          return;
        }
      }
      setState(() {
        _isClockedIn = false;
        _isOnBreak = false;
        _breakStartTime = null;
      });
      // Optionally: Update attendance record in Firestore here
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error clocking out: $e')),
      );
    }
  }

  void _showBreakDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppColors.black,
          title: const Text('Start Break', style: TextStyle(color: AppColors.gold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _breakReasonController,
                decoration: const InputDecoration(
                  labelText: 'Reason for break',
                  labelStyle: TextStyle(color: AppColors.gold),
                ),
                style: const TextStyle(color: Colors.white),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.gold),
              onPressed: _isLoading ? null : _startBreak,
              child: _isLoading
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.black))
                  : const Text('Start', style: TextStyle(color: AppColors.black)),
            ),
          ],
        );
      },
    );
  }

  Future<void> _startBreak() async {
    if (_breakReasonController.text.trim().isEmpty || _userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please enter a reason for your break')),
      );
      return;
    }
    setState(() {
      _isLoading = true;
    });
    final now = DateTime.now();
    await FirebaseFirestore.instance.collection('breaks').add({
      'userId': _userId,
      'startTime': Timestamp.fromDate(now),
      'reason': _breakReasonController.text.trim(),
      'role': 'marketing_agent',
      'endTime': null,
    });
    setState(() {
      _isOnBreak = true;
      _breakStartTime = now;
      _isLoading = false;
      _breakReasonController.clear();
    });
    await _loadBreakHistory();
    Navigator.pop(context);
  }

  Future<void> _endBreak() async {
    if (_userId == null) return;
    setState(() {
      _isLoading = true;
    });
    final now = DateTime.now();
    final query = await FirebaseFirestore.instance
        .collection('breaks')
        .where('userId', isEqualTo: _userId)
        .where('endTime', isEqualTo: null)
        .orderBy('startTime', descending: true)
        .limit(1)
        .get();
    if (query.docs.isNotEmpty) {
      await query.docs.first.reference.update({
        'endTime': Timestamp.fromDate(now),
      });
    }
    setState(() {
      _isOnBreak = false;
      _breakStartTime = null;
      _isLoading = false;
    });
    await _loadBreakHistory();
  }

  Future<void> _loadBreakHistory() async {
    if (_userId == null) return;
    final querySnapshot = await FirebaseFirestore.instance
        .collection('breaks')
        .where('userId', isEqualTo: _userId)
        .orderBy('startTime', descending: true)
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
      backgroundColor: AppColors.black,
      appBar: AppBar(
        backgroundColor: AppColors.black,
        title: const Text(
          'Marketing Post',
          style: TextStyle(
            color: AppColors.gold,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          AttendanceActionsWidget(
            agentId: _userId ?? '',
            isClockedIn: _isClockedIn,
            address: _address,
            onClockIn: _handleClockIn,
            onClockOut: _handleClockOut,
          ),
          if (_isClockedIn)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (!_isOnBreak)
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(backgroundColor: AppColors.gold),
                      onPressed: _showBreakDialog,
                      icon: const Icon(Icons.coffee, color: Colors.black),
                      label: const Text('Start Break', style: TextStyle(color: Colors.black)),
                    ),
                  if (_isOnBreak)
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
                      onPressed: _isLoading ? null : _endBreak,
                      icon: const Icon(Icons.stop_circle, color: Colors.white),
                      label: const Text('End Break', style: TextStyle(color: Colors.white)),
                    ),
                  if (_isOnBreak && _breakStartTime != null)
                    Padding(
                      padding: const EdgeInsets.only(left: 12),
                      child: Text('On break since: ' + DateFormat('h:mm a').format(_breakStartTime!), style: const TextStyle(color: Colors.redAccent)),
                    ),
                ],
              ),
            ),
          const SizedBox(height: 24),
          if (!_isClockedIn)
            const Text('Please clock in to access marketing features.', style: TextStyle(color: Colors.redAccent)),
          if (_isClockedIn)
            Expanded(child: _buildPostsList()),
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
                  final start = (b['startTime'] as Timestamp).toDate();
                  final end = b['endTime'] != null ? (b['endTime'] as Timestamp).toDate() : null;
                  final reason = b['reason'] ?? '';
                  return Card(
                    color: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                      side: BorderSide(color: end == null ? Colors.red : Colors.grey),
                    ),
                    margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    child: Container(
                      width: 200,
                      padding: const EdgeInsets.all(8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(reason, style: TextStyle(color: Colors.white)),
                          Text('Start: ' + DateFormat('h:mm a').format(start), style: TextStyle(color: Colors.grey)),
                          if (end != null)
                            Text('End: ' + DateFormat('h:mm a').format(end), style: TextStyle(color: Colors.grey)),
                          if (end == null)
                            Text('In progress...', style: TextStyle(color: Colors.red)),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        backgroundColor: AppColors.black,
        selectedItemColor: AppColors.gold,
        unselectedItemColor: Colors.white54,
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
          });
          if (index == 1 && _isClockedIn && !_isOnBreak) {
            _showAddPostDialog();
          } else if (index == 1 && (!_isClockedIn || _isOnBreak)) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(_isOnBreak ? 'End your break to create a post.' : 'Please clock in to create a post.')),
            );
          }
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.list),
            label: 'My Posts',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.add_circle_outline),
            label: 'Create Post',
          ),
        ],
      ),
    );
  }

  Widget _buildPostsList() {
    if (_posts.isEmpty) {
      return const Center(
        child: Text('No posts yet. Tap "Create Post" below.', style: TextStyle(color: AppColors.gold)),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _posts.length,
      itemBuilder: (context, index) {
        final post = _posts[index];
        return Card(
          color: AppColors.black,
          margin: const EdgeInsets.only(bottom: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: ListTile(
            leading: post.imageUrl != null && post.imageUrl!.isNotEmpty
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(post.imageUrl!, width: 60, height: 60, fit: BoxFit.cover),
                  )
                : const Icon(Icons.image, color: AppColors.gold, size: 40),
            title: Text(post.title, style: const TextStyle(color: AppColors.gold, fontWeight: FontWeight.bold)),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(post.description, style: const TextStyle(color: Colors.white70)),
                if (post.type.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text('Type: ${post.type}', style: const TextStyle(color: Colors.white38, fontSize: 12)),
                  ),
                if (post.phone.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text('Phone: ${post.phone}', style: const TextStyle(color: Colors.white38, fontSize: 12)),
                  ),
                if (post.terms.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text('Terms: ${post.terms}', style: const TextStyle(color: Colors.white38, fontSize: 12)),
                  ),
              ],
            ),
            trailing: IconButton(
              icon: const Icon(Icons.delete, color: Colors.redAccent),
              onPressed: () => setState(() => _posts.removeAt(index)),
            ),
          ),
        );
      },
    );
  }

  void _showAddPostDialog() {
    showDialog(
      context: context,
      builder: (context) {
        String title = '';
        String description = '';
        String imageUrl = '';
        String type = '';
        String phone = '';
        String terms = '';
        return AlertDialog(
          backgroundColor: AppColors.black,
          title: const Text('Create Post', style: TextStyle(color: AppColors.gold)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  decoration: const InputDecoration(labelText: 'Title', labelStyle: TextStyle(color: AppColors.gold)),
                  style: const TextStyle(color: Colors.white),
                  onChanged: (v) => title = v,
                ),
                TextField(
                  decoration: const InputDecoration(labelText: 'Description', labelStyle: TextStyle(color: AppColors.gold)),
                  style: const TextStyle(color: Colors.white),
                  onChanged: (v) => description = v,
                ),
                TextField(
                  decoration: const InputDecoration(labelText: 'Image URL', labelStyle: TextStyle(color: AppColors.gold)),
                  style: const TextStyle(color: Colors.white),
                  onChanged: (v) => imageUrl = v,
                ),
                TextField(
                  decoration: const InputDecoration(labelText: 'Type', labelStyle: TextStyle(color: AppColors.gold)),
                  style: const TextStyle(color: Colors.white),
                  onChanged: (v) => type = v,
                ),
                TextField(
                  decoration: const InputDecoration(labelText: 'Phone', labelStyle: TextStyle(color: AppColors.gold)),
                  style: const TextStyle(color: Colors.white),
                  onChanged: (v) => phone = v,
                ),
                TextField(
                  decoration: const InputDecoration(labelText: 'Terms', labelStyle: TextStyle(color: AppColors.gold)),
                  style: const TextStyle(color: Colors.white),
                  onChanged: (v) => terms = v,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.gold),
              onPressed: () {
                if (title.isNotEmpty && description.isNotEmpty) {
                  setState(() {
                    _posts.insert(0, MarketingPost(
                      title: title,
                      description: description,
                      imageUrl: imageUrl,
                      type: type,
                      phone: phone,
                      terms: terms,
                    ));
                  });
                  Navigator.pop(context);
                }
              },
              child: const Text('Create', style: TextStyle(color: AppColors.black)),
            ),
          ],
        );
      },
    );
  }
}

class MarketingPost {
  final String title;
  final String description;
  final String? imageUrl;
  final String type;
  final String phone;
  final String terms;

  MarketingPost({
    required this.title,
    required this.description,
    this.imageUrl,
    this.type = '',
    this.phone = '',
    this.terms = '',
  });
}
