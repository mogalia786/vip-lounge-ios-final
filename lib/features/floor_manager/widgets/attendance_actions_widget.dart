import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'dart:math';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:vip_lounge/core/services/device_location_service.dart';

class AttendanceActionsWidget extends StatefulWidget {
  final String userId;
  final String name;
  final String role;
  final bool isTestMode;

  const AttendanceActionsWidget({
    Key? key,
    required this.userId,
    required this.name,
    required this.role,
    this.isTestMode = false,
  }) : super(key: key);

  @override
  State<AttendanceActionsWidget> createState() => _AttendanceActionsWidgetState();
}

class _AttendanceActionsWidgetState extends State<AttendanceActionsWidget> {
  bool _isClockedIn = false;
  bool _isOnBreak = false;
  DateTime? _clockInTime;
  DateTime? _breakStartTime;
  String? _breakReason;
  bool _isLoading = false;
  final ScrollController _scrollController = ScrollController();
  List<Map<String, dynamic>> _breakHistory = [];
  bool _isTestMode = false;

  static String get googleMapsApiKey {
    return dotenv.env['GOOGLE_MAPS_API_KEY'] ?? '';
  }

  Future<void> _loadBreakHistory() async {
    if (widget.userId.isEmpty) return;
    final querySnapshot = await FirebaseFirestore.instance
        .collection('breaks')
        .where('userId', isEqualTo: widget.userId)
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
  void initState() {
    super.initState();
    _isTestMode = widget.isTestMode;
    _loadStatus();
    _loadBreakHistory();
    print('[INIT] AttendanceActionsWidget for user: ${widget.userId}');
  }

  @override
  void didUpdateWidget(covariant AttendanceActionsWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.userId != oldWidget.userId) {
      _loadStatus();
      _loadBreakHistory();
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadStatus() async {
    if (widget.userId.isEmpty) return;
    final doc = await FirebaseFirestore.instance.collection('attendance').doc(widget.userId).get();
    if (!doc.exists) return;
    final data = doc.data()!;
    setState(() {
      _isClockedIn = data['isClockedIn'] == true;
      _isOnBreak = data['isOnBreak'] == true;
      _clockInTime = (data['clockInTime'] as Timestamp?)?.toDate();
      _breakStartTime = (data['breakStartTime'] as Timestamp?)?.toDate();
      _breakReason = data['breakReason'] as String?;
    });
  }

  Future<Map<String, dynamic>?> _getBusinessLocation() async {
    final doc = await FirebaseFirestore.instance.collection('business').doc('settings').get();
    if (!doc.exists) return null;
    final data = doc.data()!;
    return data; // Return the entire settings map for flexible business hour logic
  }

  Future<bool> _requestLocationPermission() async {
    final status = await Permission.location.request();
    return status == PermissionStatus.granted;
  }

  // Replace Google Maps API location fetch with DeviceLocationService.getCurrentUserLocation
  Future<Map<String, double>?> _getUserLocation() async {
    try {
      final userLoc = await DeviceLocationService.getCurrentUserLocation(context);
      if (userLoc == null) return null;
      return {'latitude': userLoc.latitude, 'longitude': userLoc.longitude};
    } catch (e) {
      _showSnackBar('Error fetching device location: $e');
      return null;
    }
  }

  double _calculateDistance(double lat1, double lng1, double lat2, double lng2) {
    // Haversine formula
    const R = 6371000; // meters
    final dLat = (lat2 - lat1) * pi / 180.0;
    final dLon = (lng2 - lng1) * pi / 180.0;
    final a = pow(sin(dLat / 2), 2) +
        cos(lat1 * pi / 180.0) * cos(lat2 * pi / 180.0) * pow(sin(dLon / 2), 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return R * c;
  }

  Future<bool> _verifyLocation() async {
    final business = await _getBusinessLocation();
    if (business == null) return false;
    final userLoc = await _getUserLocation();
    if (userLoc == null) return false;
    print('[DEBUG] Business coordinates: lat=${business['latitude']?.toString() ?? 'null'}, lng=${business['longitude']?.toString() ?? 'null'}');
    print('[DEBUG] Device coordinates: lat=${userLoc['latitude']?.toString() ?? 'null'}, lng=${userLoc['longitude']?.toString() ?? 'null'}');
    final dist = _calculateDistance(
      business['latitude'] ?? 0, business['longitude'] ?? 0,
      userLoc['latitude'] ?? 0, userLoc['longitude'] ?? 0,
    );
    print('[DEBUG] Distance between business and device: ${dist.toStringAsFixed(2)} meters');
    return dist < 2000; // meters (2km buffer)
  }

  Future<void> _logAttendanceAction({
    required String event,
    String? breakReason,
    Map<String, dynamic>? extraData,
  }) async {
    final now = DateTime.now();
    await FirebaseFirestore.instance
      .collection('attendance_logs')
      .doc(widget.userId)
      .collection('logs')
      .add({
        'event': event,
        'timestamp': now,
        'userId': widget.userId,
        'name': widget.name,
        'role': widget.role,
        if (breakReason != null) 'breakReason': breakReason,
        if (extraData != null) ...extraData,
        'date': DateFormat('yyyy-MM-dd').format(now),
      });
  }

  void _showSnackBar(String message) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger != null) {
      messenger.showSnackBar(SnackBar(content: Text(message)));
    } else {
      // Fallback: print to console
      print(message);
    }
  }

  Future<void> _clockIn() async {
    setState(() => _isLoading = true);
    final now = DateTime.now();
    final bool isTestMode = _isTestMode;
    if (isTestMode) {
      // Bypass all checks in test mode
      await FirebaseFirestore.instance.collection('attendance').doc(widget.userId).set({
        'isClockedIn': true,
        'isOnBreak': false,
        'clockInTime': now,
        'clockOutTime': null,
        'breaks': [],
      }, SetOptions(merge: true));
      await _logAttendanceAction(event: 'clock_in');
      setState(() {
        _isClockedIn = true;
        _clockInTime = now;
        _isOnBreak = false;
        _breakStartTime = null;
        _breakReason = null;
        _isLoading = false;
      });
      String timeString = DateFormat('yyyy-MM-dd HH:mm:ss').format(now);
      _showSnackBar('[TEST MODE] Clocked in without restrictions. Time: $timeString');
      print('[CLOCKIN] Clocked in at $now for user: ${widget.userId}');
      await _loadStatus();
      return;
    }
    final today = DateTime(now.year, now.month, now.day);
    final systemNow = DateTime.now();
    final systemToday = DateTime(systemNow.year, systemNow.month, systemNow.day);
    double? lat;
    double? lng;
    String? address;
    if (today != systemToday) {
      setState(() => _isLoading = false);
      _showSnackBar('You can only clock in once per day.');
      return;
    }
    // Fetch business settings from Firestore
    Map<String, dynamic>? business;
    Map<String, double>? userLoc;
    try {
      business = await _getBusinessLocation();
      if (business == null) {
        print('[DEBUG] Business settings document is null!');
      } else {
        print('[DEBUG] Business coordinates: lat=${business['latitude']?.toString() ?? 'null'}, lng=${business['longitude']?.toString() ?? 'null'}');
      }
      userLoc = await _getUserLocation();
      if (userLoc == null) {
        print('[DEBUG] Device coordinates: null');
      } else {
        print('[DEBUG] Device coordinates: lat=${userLoc['latitude']?.toString() ?? 'null'}, lng=${userLoc['longitude']?.toString() ?? 'null'}');
      }
      if (business != null && business['latitude'] != null && business['longitude'] != null && userLoc != null) {
        final dist = _calculateDistance(
          business['latitude'] ?? 0, business['longitude'] ?? 0,
          userLoc['latitude'] ?? 0, userLoc['longitude'] ?? 0,
        );
        print('[DEBUG] Distance between business and device: ${dist.toStringAsFixed(2)} meters');
      }
      if (business == null) {
        setState(() => _isLoading = false);
        _showSnackBar('Could not determine business location.');
        return;
      }
      // Buffer logic for clock in
      final open = business['openingHours'] ?? '08:00';
      final openParts = open.split(':');
      final nowDate = DateTime.now();
      final openTime = TimeOfDay(hour: int.parse(openParts[0]), minute: int.parse(openParts[1]));
      final openBuffer = DateTime(nowDate.year, nowDate.month, nowDate.day, openTime.hour, openTime.minute).subtract(const Duration(hours: 1));
      if (now.isBefore(openBuffer)) {
        setState(() => _isLoading = false);
        _showSnackBar('Clock in only allowed from ${DateFormat('HH:mm').format(openBuffer)}.');
        return;
      }
      userLoc = await _getUserLocation();
      if (userLoc == null) {
        setState(() => _isLoading = false);
        _showSnackBar('Could not determine your location.');
        return;
      }
      final ok = _calculateDistance(
        business['latitude'] ?? 0, business['longitude'] ?? 0,
        userLoc['latitude'] ?? 0, userLoc['longitude'] ?? 0,
      ) < 2000;
      if (!ok) {
        setState(() => _isLoading = false);
        _showSnackBar('You must be at the business location to clock in.');
        return;
      }
    } catch (e) {
      setState(() => _isLoading = false);
      _showSnackBar('You must be at the business location to clock in.');
      return;
    }
    lat = userLoc['latitude'];
    lng = userLoc['longitude'];
    address = (business['address'] as String?)?.isNotEmpty == true
      ? business['address'] as String
      : null;
    await FirebaseFirestore.instance.collection('attendance').doc(widget.userId).set({
      'isClockedIn': true,
      'isOnBreak': false,
      'clockInTime': now,
      'clockOutTime': null,
      'breaks': [],
    });
    await _logAttendanceAction(event: 'clock_in');
    setState(() {
      _isClockedIn = true;
      _clockInTime = now;
      _isOnBreak = false;
      _breakStartTime = null;
      _breakReason = null;
      _isLoading = false;
    });
    String timeString = DateFormat('yyyy-MM-dd HH:mm:ss').format(now);
    _showSnackBar('Clocked in. Time: $timeString');
    print('[CLOCKIN] Clocked in at $now for user: ${widget.userId}');
    await _loadStatus();
  }

  Future<void> _clockOut() async {
    setState(() => _isLoading = true);
    final now = DateTime.now();
    final bool isTestMode = _isTestMode;
    double? lat;
    double? lng;
    String? address;
    if (!isTestMode) {
      // Always get business location and user location for toast, but only allow clock out if both are available and valid
      Map<String, dynamic>? business;
      Map<String, double>? userLoc;
      try {
        business = await _getBusinessLocation();
        userLoc = await _getUserLocation();
        if (business == null || userLoc == null) {
          setState(() => _isLoading = false);
          _showSnackBar('Could not determine location.');
          return;
        }
        
        final ok = _calculateDistance(
          business['latitude'] ?? 0, business['longitude'] ?? 0,
          userLoc['latitude'] ?? 0, userLoc['longitude'] ?? 0,
        ) < 2000;
        if (!ok) {
          setState(() => _isLoading = false);
          _showSnackBar('You must be at the business location to clock out.');
          return;
        }
      } catch (e) {
        setState(() => _isLoading = false);
        _showSnackBar('Location verification failed: $e');
        return;
      }
      lat = userLoc['latitude'];
      lng = userLoc['longitude'];
      address = (business['address'] as String?)?.isNotEmpty == true
        ? business['address'] as String
        : null;
    }
    await FirebaseFirestore.instance.collection('attendance').doc(widget.userId).set({
      'isClockedIn': false,
      'isOnBreak': false,
      'clockOutTime': now,
    }, SetOptions(merge: true));
    await _logAttendanceAction(event: 'clock_out');
    setState(() {
      _isClockedIn = false;
      _isOnBreak = false;
      _breakStartTime = null;
      _breakReason = null;
      _isLoading = false;
    });
    String locationString = address != null && address.isNotEmpty
        ? address
        : (lat != null && lng != null ? '($lat, $lng)' : 'Unknown location');
    String timeString = DateFormat('yyyy-MM-dd HH:mm:ss').format(now);
    _showSnackBar('Clocked out at $locationString\nTime: $timeString');
    print('[CLOCKOUT] Clocked out at $now for user: ${widget.userId}');
    await _loadStatus();
  }

  Future<void> _startBreak(String reason) async {
    setState(() => _isLoading = true);
    final now = DateTime.now();
    // Write to breaks collection (history)
    await FirebaseFirestore.instance.collection('breaks').add({
      'userId': widget.userId,
      'userName': widget.name,
      'startTime': Timestamp.fromDate(now),
      'reason': reason,
      'role': widget.role,
      'endTime': null,
    });
    await _logAttendanceAction(event: 'break_start', breakReason: reason);
    setState(() {
      _isOnBreak = true;
      _breakStartTime = now;
      _breakReason = reason;
      _isLoading = false;
    });
    _showSnackBar('Break started: $reason');
  }

  Future<void> _endBreak() async {
    setState(() => _isLoading = true);
    final now = DateTime.now();
    // Find the latest active break for this user
    final query = await FirebaseFirestore.instance
        .collection('breaks')
        .where('userId', isEqualTo: widget.userId)
        .where('endTime', isEqualTo: null)
        .orderBy('startTime', descending: true)
        .limit(1)
        .get();
    if (query.docs.isNotEmpty) {
      final breakDoc = query.docs.first;
      await breakDoc.reference.update({'endTime': Timestamp.fromDate(now)});
    }
    await _logAttendanceAction(event: 'break_end');
    await FirebaseFirestore.instance.collection('attendance').doc(widget.userId).set({
      'isOnBreak': false,
      'breakStartTime': null,
      'breakReason': null,
    }, SetOptions(merge: true));
    setState(() {
      _isOnBreak = false;
      _breakStartTime = null;
      _breakReason = null;
      _isLoading = false;
    });
    _showSnackBar('Break ended.');
  }

  @override
  Widget build(BuildContext context) {
    final double widgetWidth = MediaQuery.of(context).size.width;
    return Material(
      color: Colors.transparent,
      child: Container(
        width: widgetWidth,
        constraints: const BoxConstraints(
          minHeight: 100,
          maxHeight: 180,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // TEST MODE CHECKBOX (DEV ONLY)
              Row(
                children: [
                  Checkbox(
                    value: _isTestMode,
                    onChanged: (val) {
                      if (val != null) {
                        setState(() {
                          _isTestMode = val;
                        });
                      }
                    },
                  ),
                  const Text('Test Mode', style: TextStyle(color: Colors.amber)),
                ],
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 6.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    if (!_isClockedIn)
                      SizedBox(
                        height: 34,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            minimumSize: Size(80, 34),
                            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                            textStyle: TextStyle(fontSize: 13),
                          ),
                          onPressed: _isLoading ? null : _clockIn,
                          icon: const Icon(Icons.login, color: Colors.black, size: 18),
                          label: const Text('Clock In', style: TextStyle(color: Colors.black)),
                        ),
                      ),
                    if (_isClockedIn && !_isOnBreak)
                      SizedBox(
                        height: 34,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange,
                            minimumSize: Size(90, 34),
                            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                            textStyle: TextStyle(fontSize: 13),
                          ),
                          onPressed: _isLoading ? null : () async {
                            final reason = await showDialog<String>(
                              context: context,
                              builder: (context) {
                                final controller = TextEditingController();
                                return AlertDialog(
                                  backgroundColor: Colors.black,
                                  title: const Text('Start Break', style: TextStyle(color: Colors.amber)),
                                  content: TextField(
                                    controller: controller,
                                    decoration: const InputDecoration(
                                      labelText: 'Reason for break',
                                      labelStyle: TextStyle(color: Colors.amber),
                                    ),
                                    style: const TextStyle(color: Colors.white),
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(context),
                                      child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
                                    ),
                                    ElevatedButton(
                                      style: ElevatedButton.styleFrom(backgroundColor: Colors.amber),
                                      onPressed: () => Navigator.pop(context, controller.text),
                                      child: const Text('Start', style: TextStyle(color: Colors.black)),
                                    ),
                                  ],
                                );
                              },
                            );
                            if (reason != null && reason.trim().isNotEmpty) {
                              await _startBreak(reason.trim());
                              await _loadBreakHistory();
                            }
                          },
                          icon: const Icon(Icons.coffee, color: Colors.black, size: 18),
                          label: const Text('Start Break', style: TextStyle(color: Colors.black)),
                        ),
                      ),
                    if (_isClockedIn && _isOnBreak)
                      SizedBox(
                        height: 34,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange[700],
                            minimumSize: Size(90, 34),
                            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                            textStyle: TextStyle(fontSize: 13),
                          ),
                          onPressed: _isLoading ? null : () async {
                            await _endBreak();
                            await _loadBreakHistory();
                          },
                          icon: const Icon(Icons.coffee_outlined, color: Colors.white, size: 18),
                          label: const Text('End Break', style: TextStyle(color: Colors.white)),
                        ),
                      ),
                    if (_isClockedIn)
                      SizedBox(
                        height: 34,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.redAccent,
                            minimumSize: Size(80, 34),
                            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                            textStyle: TextStyle(fontSize: 13),
                          ),
                          onPressed: _isLoading ? null : _clockOut,
                          icon: const Icon(Icons.logout, color: Colors.white, size: 18),
                          label: const Text('Clock Out', style: TextStyle(color: Colors.white)),
                        ),
                      ),
                  ],
                ),
              ),
              if (_breakHistory.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(left: 4, bottom: 4, top: 8),
                  child: Text('Your Break History', style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold)),
                ),
              if (_breakHistory.isNotEmpty)
                SizedBox(
                  height: 90, // Reduced height
                  width: widgetWidth - 24, // match horizontal padding
                  child: Scrollbar(
                    thumbVisibility: true,
                    controller: _scrollController,
                    child: ListView.builder(
                      controller: _scrollController,
                      scrollDirection: Axis.horizontal,
                      itemCount: _breakHistory.length,
                      itemBuilder: (context, index) {
                        final breakData = _breakHistory[index];
                        final startTime = breakData['startTime'] is Timestamp
                            ? (breakData['startTime'] as Timestamp).toDate()
                            : breakData['startTime'] as DateTime?;
                        final endTime = breakData['endTime'] is Timestamp
                            ? (breakData['endTime'] as Timestamp).toDate()
                            : breakData['endTime'] as DateTime?;
                        final reason = breakData['reason'] ?? '';
                        final duration = (startTime != null && endTime != null)
                            ? endTime.difference(startTime).inMinutes
                            : null;
                        return Card(
                          color: Colors.grey[900],
                          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          child: SingleChildScrollView(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  startTime != null ? 'Start: ' + DateFormat('hh:mm a').format(startTime) : '',
                                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                                ),
                                if (endTime != null)
                                  Text(
                                    'End: ' + DateFormat('hh:mm a').format(endTime),
                                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                                  ),
                                if (reason.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 4.0),
                                    child: Text('Reason: $reason', style: TextStyle(color: Colors.orange, fontStyle: FontStyle.italic, fontSize: 13)),
                                  ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Icon(Icons.timer, color: duration != null ? Colors.white : Colors.orange, size: 16),
                                    const SizedBox(width: 4),
                                    Text(
                                      duration != null ? '$duration min' : 'In progress',
                                      style: TextStyle(color: duration != null ? Colors.white : Colors.orange, fontWeight: FontWeight.bold, fontSize: 13),
                                      overflow: TextOverflow.ellipsis,
                                      maxLines: 1,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
