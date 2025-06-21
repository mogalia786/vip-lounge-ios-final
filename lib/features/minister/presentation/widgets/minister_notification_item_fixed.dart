import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../../core/constants/colors.dart';
import '../../../../core/providers/app_auth_provider.dart';

class MinisterNotificationItemFixed extends StatefulWidget {
  final Map<String, dynamic> notification;
  final VoidCallback? onTap;
  final void Function(int rating, String comment)? onRate;

  const MinisterNotificationItemFixed({Key? key, required this.notification, this.onTap, this.onRate}) : super(key: key);

  @override
  State<MinisterNotificationItemFixed> createState() => _MinisterNotificationItemFixedState();
}

class _MinisterNotificationItemFixedState extends State<MinisterNotificationItemFixed> {
  String _formatTime(dynamic timestamp) {
    DateTime? dt;
    if (timestamp is DateTime) {
      dt = timestamp;
    } else if (timestamp is String) {
      dt = DateTime.tryParse(timestamp);
    } else if (timestamp != null && timestamp.toString().isNotEmpty) {
      try {
        dt = DateTime.parse(timestamp.toString());
      } catch (_) {}
    }
    if (dt == null) return '';
    return DateFormat('HH:mm').format(dt);
  }

  late bool _hasRatedLocal;
  late String _staffName;
  late String _staffId;
  late String _notificationType;
  late String _title;
  late String _body;
  late String _time;
  late bool _isQuery;
  late bool _isAppointment;
  late Map<String, dynamic> _data;

  @override
  void initState() {
    super.initState();
    _hasRatedLocal = widget.notification['hasRated'] == true;
    _data = widget.notification['data'] ?? {};
    _notificationType = _data['type'] ?? widget.notification['type'] ?? '';
    _title = _data['title']?.toString() ?? widget.notification['title']?.toString() ?? '';
    _body = _data['body']?.toString() ?? widget.notification['body']?.toString() ?? '';
    _time = _formatTime(_data['createdAt'] ?? _data['timestamp'] ?? widget.notification['createdAt'] ?? widget.notification['timestamp']);
    _isQuery = _notificationType == 'query' || _notificationType == 'query_resolved';
    _isAppointment = !_isQuery;
    _staffName = '';
    _staffId = '';
    if (_isQuery) {
      _staffName = _data['senderName'] ?? widget.notification['senderName'] ?? '';
      _staffId = _data['senderId'] ?? widget.notification['senderId'] ?? '';
    }
  }

  Future<Map<String, String>> _fetchStaffFromQuery() async {
    final queryId = _data['queryId'] ?? widget.notification['queryId'];
    String staffName = '';
    String staffId = '';
    if (queryId != null && queryId.toString().isNotEmpty) {
      try {
        final queryDoc = await FirebaseFirestore.instance.collection('queries').doc(queryId).get();
        final queryData = queryDoc.data();
        if (queryData != null) {
          staffId = queryData['assignedStaffId'] ?? queryData['staffId'] ?? '';
          staffName = queryData['assignedStaffName'] ?? queryData['staffName'] ?? '';
        }
      } catch (e) {
        debugPrint('ERROR: _fetchStaffFromQuery failed: $e');
      }
    }
    return {'staffId': staffId, 'staffName': staffName};
  }

  Future<Map<String, String>> _fetchStaffFromAppointment() async {
    final appointmentId = _data['appointmentId'] ?? widget.notification['appointmentId'];
    String staffName = '';
    String staffId = '';
    String header = (_title + ' ' + _body).toLowerCase();
    if (appointmentId != null && appointmentId.toString().isNotEmpty) {
      try {
        final appointmentDoc = await FirebaseFirestore.instance.collection('appointments').doc(appointmentId).get();
        final appointmentData = appointmentDoc.data();
        if (appointmentData != null) {
          if (header.contains('concierge')) {
            staffId = appointmentData['conciergeId'] ?? '';
            staffName = appointmentData['conciergeName'] ?? '';
          } else if (header.contains('consultant')) {
            staffId = appointmentData['consultantId'] ?? '';
            staffName = appointmentData['consultantName'] ?? '';
          } else if (header.contains('assignedstaff') || header.contains('assigned staff')) {
            staffId = appointmentData['assignedStaffId'] ?? '';
            staffName = appointmentData['assignedStaffName'] ?? '';
          } else {
            staffId = appointmentData['consultantId'] ?? appointmentData['conciergeId'] ?? appointmentData['assignedStaffId'] ?? '';
            staffName = appointmentData['consultantName'] ?? appointmentData['conciergeName'] ?? appointmentData['assignedStaffName'] ?? '';
          }
        }
      } catch (e) {
        debugPrint('ERROR: _fetchStaffFromAppointment failed: $e');
      }
    }
    return {'staffId': staffId, 'staffName': staffName};
  }

  Widget _buildHeader(String name) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6.0),
      child: Text(
        name,
        style: const TextStyle(
          color: AppColors.primary,
          fontWeight: FontWeight.bold,
          fontSize: 18,
        ),
      ),
    );
  }

  Widget _buildNotificationContent(String name, String id) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (name.isNotEmpty) _buildHeader(name),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_title.isNotEmpty)
                    Text(
                      _title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                  if (_body.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 6.0, bottom: 10.0),
                      child: Text(
                        _body,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Text(
              _time,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 12,
              ),
            ),
          ],
        ),
        if (!_hasRatedLocal && name.isNotEmpty && id.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.18),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(10),
                      onTap: () async {
                        final result = await showDialog(
                          context: context,
                          builder: (context) => RatingDialogFixed(senderName: name, senderId: id),
                        );
                        if (result is Map && result['hasRated'] == true) {
                          setState(() => _hasRatedLocal = true);
                        }
                      },
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          Icon(Icons.star, color: Colors.white, size: 22),
                          SizedBox(width: 8),
                          Text('Rate Experience', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return _isAppointment
        ? FutureBuilder<Map<String, String>>(
            future: _fetchStaffFromAppointment(),
            builder: (context, snapshot) {
              String name = _staffName;
              String id = _staffId;
              if (snapshot.hasData) {
                name = snapshot.data!['staffName'] ?? '';
                id = snapshot.data!['staffId'] ?? '';
              }
              return _buildNotificationContent(name, id);
            },
          )
        : (_staffName.isNotEmpty
            ? _buildNotificationContent(_staffName, _staffId)
            : FutureBuilder<Map<String, String>>(
                future: _fetchStaffFromQuery(),
                builder: (context, snapshot) {
                  String name = _staffName;
                  String id = _staffId;
                  if (snapshot.hasData) {
                    name = snapshot.data!['staffName'] ?? '';
                    id = snapshot.data!['staffId'] ?? '';
                  }
                  return _buildNotificationContent(name, id);
                },
              ));
  }
}

class RatingDialogFixed extends StatefulWidget {
  final String senderName;
  final String senderId;
  const RatingDialogFixed({Key? key, required this.senderName, required this.senderId}) : super(key: key);

  @override
  State<RatingDialogFixed> createState() => _RatingDialogFixedState();
}

class _RatingDialogFixedState extends State<RatingDialogFixed> {
  int _rating = 0;
  String _comment = '';
  bool _submitting = false;

  void _submitRating() async {
    setState(() => _submitting = true);
    final appAuth = Provider.of<AppAuthProvider>(context, listen: false);
    final user = appAuth.appUser;
    final now = DateTime.now();
    try {
      await FirebaseFirestore.instance.collection('ratings').add({
        'senderName': widget.senderName,
        'senderId': widget.senderId,
        'rating': _rating,
        'comment': _comment,
        'createdAt': now,
        'ratedBy': user?.uid,
      });
      Navigator.of(context).pop({'rating': _rating, 'comment': _comment, 'hasRated': true});
      setState(() => _submitting = false);
    } catch (e) {
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to submit rating: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Colors.blue[900],
      title: Text('Rate Experience for ${widget.senderName}', style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (index) => IconButton(
              icon: Icon(
                _rating > index ? Icons.star : Icons.star_border,
                color: AppColors.primary,
              ),
              onPressed: _submitting ? null : () => setState(() => _rating = index + 1),
            )),
          ),
          TextField(
            enabled: !_submitting,
            onChanged: (val) => _comment = val,
            decoration: const InputDecoration(
              labelText: 'Add a comment (optional)',
              labelStyle: TextStyle(color: Colors.white70),
            ),
            style: const TextStyle(color: Colors.white),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _submitting ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
          ),
          onPressed: _submitting || _rating == 0 ? null : _submitRating,
          child: const Text('Submit'),
        ),
      ],
    );
  }
}
