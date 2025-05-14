import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'dart:async';

import '../../../../core/constants/colors.dart';
import '../../../../core/providers/app_auth_provider.dart';
import '../../../../core/services/notification_service.dart';
import '../widgets/appointment_status_chip.dart';
import '../widgets/service_action_button.dart';
import '../widgets/activity_entry_dialog.dart';

class AppointmentDetailScreen extends StatefulWidget {
  final Map<String, dynamic> appointment;
  
  const AppointmentDetailScreen({
    Key? key,
    required this.appointment,
  }) : super(key: key);

  @override
  State<AppointmentDetailScreen> createState() => _AppointmentDetailScreenState();
}

class _AppointmentDetailScreenState extends State<AppointmentDetailScreen> {
  Map<String, dynamic> _appointment = {};
  bool _isLoading = false;
  List<Map<String, dynamic>> _activities = [];
  List<Map<String, dynamic>> _documents = [];
  bool _isAppointmentStarted = false;
  bool _isAppointmentCompleted = false;
  DateTime? _startTime;
  DateTime? _endTime;
  
  // Image picker
  final _imagePicker = ImagePicker();
  
  @override
  void initState() {
    super.initState();
    _appointment = widget.appointment;
    _loadActivities();
    _loadDocuments();
    _checkAppointmentStatus();
  }
  
  @override
  void dispose() {
    super.dispose();
  }
  
  void _checkAppointmentStatus() {
    // Check if appointment is already started or completed
    final status = _appointment['status']?.toString().toLowerCase() ?? '';
    final hasStartTime = _appointment['sessionStartTime'] != null;
    final hasEndTime = _appointment['sessionEndTime'] != null;
    
    setState(() {
      _isAppointmentStarted = status == 'in-progress' || status == 'in_progress' || hasStartTime;
      _isAppointmentCompleted = status == 'completed' || hasEndTime;
      
      if (hasStartTime) {
        _startTime = _appointment['sessionStartTime'] is Timestamp 
            ? (_appointment['sessionStartTime'] as Timestamp).toDate()
            : _appointment['sessionStartTime'];
      }
      
      if (hasEndTime) {
        _endTime = _appointment['sessionEndTime'] is Timestamp 
            ? (_appointment['sessionEndTime'] as Timestamp).toDate()
            : _appointment['sessionEndTime'];
      }
    });
    
    print('DEBUG: Appointment status - Started: $_isAppointmentStarted, Completed: $_isAppointmentCompleted');
  }
  
  Future<void> _loadActivities() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('activities')
          .where('appointmentId', isEqualTo: _appointment['id'])
          .orderBy('timestamp', descending: true)
          .get();
          
      setState(() {
        _activities = snapshot.docs.map((doc) => {
          'id': doc.id,
          ...doc.data(),
        }).toList();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading activities: $e')),
      );
    }
  }
  
  Future<void> _loadDocuments() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('documents')
          .where('appointmentId', isEqualTo: _appointment['id'])
          .orderBy('timestamp', descending: true)
          .get();
          
      setState(() {
        _documents = snapshot.docs.map((doc) => {
          'id': doc.id,
          ...doc.data(),
        }).toList();
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading documents: $e')),
      );
    }
  }
  
  Future<void> _startAppointment() async {
    final user = Provider.of<AppAuthProvider>(context, listen: false).appUser;
    if (user == null) return;
    
    try {
      setState(() {
        _isLoading = true;
      });
      
      final now = DateTime.now();
      
      // Update appointment status in both collections to be sure
      for (final collection in ['appointments', 'bookings']) {
        final docRef = FirebaseFirestore.instance.collection(collection).doc(_appointment['id']);
        final docSnapshot = await docRef.get();
        
        if (docSnapshot.exists) {
          await docRef.update({
            'status': 'in_progress',
            'sessionStartTime': Timestamp.fromDate(now),
          });
          print('DEBUG: Updated $collection document ${_appointment['id']} with start time');
        }
      }
      
      // Create activity record
      final activityRef = await FirebaseFirestore.instance
          .collection('activities')
          .add({
            'appointmentId': _appointment['id'],
            'userId': user.id,
            'userName': user.name,
            'type': 'session_start',
            'detail': 'Session started by ${user.name}',
            'timestamp': Timestamp.fromDate(now),
          });
      
      print('DEBUG: Created activity record ${activityRef.id}');
      
      // Send notification to minister
      await _sendNotification(
        title: 'Appointment Started',
        body: 'Your appointment with ${user.name} has begun',
        receiverId: _appointment['ministerId'] ?? _appointment['userId'],
        type: 'appointment_start'
      );
      
      // Send notification to floor manager
      await _sendNotification(
        title: 'Appointment Started',
        body: '${user.name} has started an appointment with ${_appointment['ministerName'] ?? 'a minister'}',
        receiverRole: 'floor_manager',
        type: 'staff_appointment_start'
      );
      
      setState(() {
        _isLoading = false;
        _isAppointmentStarted = true;
        _startTime = now;
        _appointment = {
          ..._appointment,
          'status': 'in_progress',
          'sessionStartTime': now,
        };
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Appointment started successfully')),
      );
      
      // Refresh the activities
      _loadActivities();
      
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error starting appointment: $e')),
      );
      print('ERROR starting appointment: $e');
    }
  }
  
  Future<void> _endAppointment() async {
    final user = Provider.of<AppAuthProvider>(context, listen: false).appUser;
    if (user == null) return;
    
    try {
      setState(() {
        _isLoading = true;
      });
      
      final now = DateTime.now();
      
      // Update appointment status in both collections to be sure
      for (final collection in ['appointments', 'bookings']) {
        final docRef = FirebaseFirestore.instance.collection(collection).doc(_appointment['id']);
        final docSnapshot = await docRef.get();
        
        if (docSnapshot.exists) {
          await docRef.update({
            'status': 'completed',
            'sessionEndTime': Timestamp.fromDate(now),
          });
          print('DEBUG: Updated $collection document ${_appointment['id']} with end time');
        }
      }
      
      // Create activity record
      final activityRef = await FirebaseFirestore.instance
          .collection('activities')
          .add({
            'appointmentId': _appointment['id'],
            'userId': user.id,
            'userName': user.name,
            'type': 'session_end',
            'detail': 'Session completed by ${user.name}',
            'timestamp': Timestamp.fromDate(now),
          });
      
      print('DEBUG: Created activity record ${activityRef.id}');
      
      // Send thank you notification to minister
      await _sendNotification(
        title: 'Thank You for Your Visit',
        body: 'Thank you for visiting us. We hope you enjoyed your appointment.',
        receiverId: _appointment['ministerId'] ?? _appointment['userId'],
        type: 'appointment_completed'
      );
      
      // Send rating request notification to minister
      final ministerId = _appointment['ministerId'] ?? _appointment['userId'];
      final notificationService = NotificationService();
      
      try {
        await notificationService.sendRatingRequestToMinister(
          appointmentId: _appointment['id'],
          consultantId: user.id,
          consultantName: user.name,
          ministerId: ministerId,
        );
        print('DEBUG: Rating request sent to minister $ministerId');
      } catch (e) {
        print('ERROR sending rating request: $e');
      }
      
      // Send notification to floor manager
      await _sendNotification(
        title: 'Appointment Completed',
        body: '${user.name} has completed an appointment with ${_appointment['ministerName'] ?? 'a minister'}',
        receiverRole: 'floor_manager',
        type: 'staff_appointment_completed'
      );
      
      // Send notification to concierge to escort minister
      await _sendNotification(
        title: 'Minister Escort Required',
        body: 'Please assist ${_appointment['ministerName'] ?? 'the minister'} to their vehicle',
        receiverRole: 'concierge',
        type: 'minister_escort'
      );
      
      setState(() {
        _isLoading = false;
        _isAppointmentCompleted = true;
        _endTime = now;
        _appointment = {
          ..._appointment,
          'status': 'completed',
          'sessionEndTime': now,
        };
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Appointment completed successfully')),
      );
      
      // Refresh the activities
      _loadActivities();
      
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error completing appointment: $e')),
      );
      print('ERROR completing appointment: $e');
    }
  }

  // Helper to send notifications
  Future<void> _sendNotification({
    required String title,
    required String body,
    String? receiverId,
    String? receiverRole,
    required String type,
  }) async {
    final user = Provider.of<AppAuthProvider>(context, listen: false).appUser;
    if (user == null) return;
    
    try {
      // Create notification data
      String updatedBody = body;
      if (type == 'session_end' || title.toLowerCase().contains('session ended')) {
        final venue = _appointment['venue'] ?? _appointment['venueName'] ?? 'Venue not specified';
        updatedBody = body.contains(venue) ? body : body + ' at ' + venue;
      }
      final notificationData = {
        'title': title,
        'body': updatedBody,
        'senderId': user.id,
        'senderName': user.name,
        'type': type,
        'appointmentId': _appointment['id'],
        'timestamp': Timestamp.fromDate(DateTime.now()),
        'isRead': false,
      };
      
      // Use the NotificationService to send notifications
      final notificationService = NotificationService();
      
      if (receiverRole == 'floor_manager') {
        // For floor managers, create notification in Firestore and send FCM
        await notificationService.createNotification(
          title: title,
          body: body,
          data: {
            ...notificationData,
            ..._appointment, // Include appointment data
          },
          role: 'floor_manager',
          // No assignedToId for floor_manager as it should go to all floor managers
        );
        
        // Send FCM to floor managers
        await notificationService.sendFCMToFloorManager(
          title: title,
          body: body,
          data: {
            ...notificationData,
            ..._appointment,
          },
        );
        
        print('DEBUG: Sent notification to floor managers');
      } 
      else if (receiverRole == 'minister') {
        // For ministers, create notification with assignedToId
        final ministerId = _appointment['ministerId'];
        if (ministerId != null) {
          await notificationService.createNotification(
            title: title,
            body: body,
            data: {
              ...notificationData,
              ..._appointment,
            },
            role: 'minister',
            assignedToId: ministerId,
          );
          
          print('DEBUG: Sent notification to minister $ministerId');
        }
      }
      else if (receiverId != null) {
        // For specific users by ID, create notification with assignedToId
        await notificationService.createNotification(
          title: title,
          body: body,
          data: {
            ...notificationData,
            ..._appointment,
          },
          role: receiverRole ?? 'unknown', // Default to 'unknown' if no role provided
          assignedToId: receiverId,
        );
        
        print('DEBUG: Sent notification to user $receiverId with role ${receiverRole ?? "unknown"}');
      }
    } catch (e) {
      print('ERROR sending notification: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error sending notification: $e')),
      );
    }
  }
  
  Future<void> _refreshAppointment() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('appointments')
          .doc(_appointment['id'])
          .get();
          
      if (snapshot.exists) {
        setState(() {
          _appointment = {
            'id': snapshot.id,
            ...snapshot.data()!,
          };
          
          // Convert timestamps to DateTime
          if (_appointment['appointmentTime'] != null) {
            _appointment['appointmentTime'] = 
                (_appointment['appointmentTime'] as Timestamp).toDate();
          }
          if (_appointment['sessionStartTime'] != null) {
            _appointment['sessionStartTime'] = 
                (_appointment['sessionStartTime'] as Timestamp).toDate();
          }
          if (_appointment['sessionEndTime'] != null) {
            _appointment['sessionEndTime'] = 
                (_appointment['sessionEndTime'] as Timestamp).toDate();
          }
        });
      }
      
      // Reload activities
      _loadActivities();
      _loadDocuments();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error refreshing appointment: $e')),
      );
    }
  }
  
  void _showAddActivityDialog() {
    showDialog(
      context: context,
      builder: (context) => ActivityEntryDialog(
        onSave: (String activityDetail) {
          _addActivity(activityDetail);
        },
      ),
    );
  }
  
  Future<void> _addActivity(String detail) async {
    final user = Provider.of<AppAuthProvider>(context, listen: false).appUser;
    if (user == null) return;
    
    try {
      final now = DateTime.now();
      
      // Create activity record
      await FirebaseFirestore.instance
          .collection('activities')
          .add({
            'appointmentId': _appointment['id'],
            'userId': user.id,
            'userName': user.name,
            'type': 'service',
            'detail': detail,
            'timestamp': Timestamp.fromDate(now),
          });
      
      // Reload activities
      _loadActivities();
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Activity added successfully')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error adding activity: $e')),
      );
    }
  }
  
  Future<void> _uploadDocument() async {
    if (!_isAppointmentStarted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please start the appointment first to upload documents')),
      );
      return;
    }
    
    try {
      // Show options dialog for camera or gallery
      await showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            backgroundColor: Colors.grey[900],
            title: Text('Take Document Photo', style: TextStyle(color: Colors.white)),
            content: Text('Choose capture method', style: TextStyle(color: Colors.white70)),
            actions: [
              TextButton(
                child: Text('Camera', style: TextStyle(color: AppColors.gold)),
                onPressed: () {
                  Navigator.pop(context);
                  _captureDocumentImage(ImageSource.camera);
                },
              ),
              TextButton(
                child: Text('Gallery', style: TextStyle(color: Colors.white70)),
                onPressed: () {
                  Navigator.pop(context);
                  _captureDocumentImage(ImageSource.gallery);
                },
              ),
            ],
          );
        },
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error opening camera: $e')),
      );
    }
  }
  
  Future<void> _captureDocumentImage(ImageSource source) async {
    try {
      final user = Provider.of<AppAuthProvider>(context, listen: false).appUser;
      if (user == null) return;
    
      setState(() {
        _isLoading = true;
      });
      
      // Capture image using camera
      final XFile? pickedFile = await _imagePicker.pickImage(
        source: source,
        imageQuality: 80,
      );
      
      if (pickedFile == null) {
        setState(() {
          _isLoading = false;
        });
        return;
      }
      
      // Get file extension
      final fileName = pickedFile.name;
      final fileExtension = fileName.split('.').last.toLowerCase();
      
      // Upload file to Firebase Storage
      final storageRef = FirebaseStorage.instance
          .ref()
          .child('documents')
          .child('${DateTime.now().millisecondsSinceEpoch}_$fileName');
      
      final file = File(pickedFile.path);
      final uploadTask = await storageRef.putFile(file);
      final downloadUrl = await uploadTask.ref.getDownloadURL();
      
      // Save document reference in Firestore
      await FirebaseFirestore.instance
          .collection('documents')
          .add({
            'appointmentId': _appointment['id'],
            'userId': user.id,
            'userName': user.name,
            'fileName': fileName,
            'fileType': fileExtension,
            'fileUrl': downloadUrl,
            'timestamp': Timestamp.fromDate(DateTime.now()),
          });
      
      // Add activity entry
      await _addActivity('Document uploaded: $fileName');
      
      // Refresh documents
      await _loadDocuments();
      
      // Delete the local file after successful upload
      if (file.existsSync()) {
        await file.delete();
        print('DEBUG: Local document file deleted after upload: ${pickedFile.path}');
      }
      
      setState(() {
        _isLoading = false;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Document uploaded successfully')),
      );
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error uploading document: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final ministerName = _appointment['ministerName'] ?? 'Unknown Minister';
    final serviceName = _appointment['serviceName'] ?? _appointment['service'] ?? 'Consultation';
    final status = _appointment['status'] ?? 'pending';
    final venue = _appointment['venue'] ?? 'Not specified';
    final DateTime appointmentTime = _appointment['appointmentTime'] is DateTime
        ? _appointment['appointmentTime'] as DateTime
        : (_appointment['appointmentTime'] as Timestamp?)?.toDate() ?? DateTime.now();
    
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Appointment Details'),
        backgroundColor: Colors.black,
        elevation: 0,
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: AppColors.gold))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Appointment Header Card
                  Card(
                    color: Colors.grey.shade900,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: AppColors.gold),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Flexible(
                                child: Text(
                                  serviceName,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 22,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Container(
                                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: _getStatusColor(status).withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: _getStatusColor(status)),
                                ),
                                child: Text(
                                  _formatStatus(status),
                                  style: TextStyle(
                                    color: _getStatusColor(status),
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 16),
                          
                          _buildInfoRow(Icons.person, 'Minister', ministerName),
                          _buildInfoRow(Icons.access_time, 'Time', DateFormat('h:mm a').format(appointmentTime)),
                          _buildInfoRow(Icons.calendar_today, 'Date', DateFormat('EEEE, MMMM d, yyyy').format(appointmentTime)),
                          _buildInfoRow(Icons.location_on, 'Venue', venue),
                          
                          if (_startTime != null)
                            _buildInfoRow(Icons.play_arrow, 'Started', DateFormat('h:mm a').format(_startTime!)),
                          
                          if (_endTime != null)
                            _buildInfoRow(Icons.stop, 'Ended', DateFormat('h:mm a').format(_endTime!)),
                          
                          SizedBox(height: 24),
                          
                          // Action buttons
                          if (!_isAppointmentCompleted) ...[
                            if (!_isAppointmentStarted)
                              _buildActionButton(
                                'Start Appointment',
                                Icons.play_arrow,
                                Colors.green,
                                _startAppointment,
                              )
                            else
                              _buildActionButton(
                                'End Appointment',
                                Icons.stop,
                                Colors.red,
                                _endAppointment,
                              ),
                          ] else
                            Center(
                              child: Container(
                                padding: EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.green.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  'Appointment Completed',
                                  style: TextStyle(color: Colors.green),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  
                  SizedBox(height: 24),
                  
                  // Disabled notice if appointment not started
                  if (!_isAppointmentStarted && !_isAppointmentCompleted)
                    Container(
                      padding: EdgeInsets.all(12),
                      margin: EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.amber.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.amber.withOpacity(0.5)),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline, color: Colors.amber),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Please start the appointment to enable document upload and activity tracking',
                              style: TextStyle(color: Colors.amber),
                            ),
                          ),
                        ],
                      ),
                    ),
                  
                  // Feature buttons (enabled only if appointment started and not completed)
                  if (_isAppointmentStarted && !_isAppointmentCompleted)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 24.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _buildFeatureButton(
                            'Add Note',
                            Icons.note_add,
                            AppColors.gold,
                            _showAddActivityDialog,
                          ),
                          _buildFeatureButton(
                            'Take Photo',
                            Icons.camera_alt,
                            Colors.blue,
                            _uploadDocument,
                          ),
                        ],
                      ),
                    ),
                  
                  // Activities Section (disabled if appointment not started)
                  Text(
                    'Activities & Notes',
                    style: TextStyle(
                      color: AppColors.gold,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColors.gold),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: _activities.isEmpty
                        ? Padding(
                            padding: const EdgeInsets.all(16),
                            child: Center(
                              child: Text(
                                _isAppointmentStarted 
                                    ? 'No activities recorded yet' 
                                    : 'Activities will be available after starting the appointment',
                                style: TextStyle(color: Colors.grey),
                              ),
                            ),
                          )
                        : ListView.builder(
                            shrinkWrap: true,
                            physics: NeverScrollableScrollPhysics(),
                            itemCount: _activities.length,
                            itemBuilder: (context, index) {
                              final activity = _activities[index];
                              final timestamp = (activity['timestamp'] as Timestamp).toDate();
                              
                              return ListTile(
                                leading: _getActivityIcon(activity['type']),
                                title: Text(
                                  activity['detail'],
                                  style: TextStyle(color: Colors.white),
                                ),
                                subtitle: Text(
                                  DateFormat('MMM d, h:mm a').format(timestamp),
                                  style: TextStyle(color: Colors.grey),
                                ),
                              );
                            },
                          ),
                  ),
                  
                  SizedBox(height: 24),
                  
                  // Documents Section (disabled if appointment not started)
                  Text(
                    'Documents',
                    style: TextStyle(
                      color: AppColors.gold,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColors.gold),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: _documents.isEmpty
                        ? Padding(
                            padding: const EdgeInsets.all(16),
                            child: Center(
                              child: Text(
                                _isAppointmentStarted 
                                    ? 'No documents uploaded yet' 
                                    : 'Document uploads will be available after starting the appointment',
                                style: TextStyle(color: Colors.grey),
                              ),
                            ),
                          )
                        : ListView.builder(
                            shrinkWrap: true,
                            physics: NeverScrollableScrollPhysics(),
                            itemCount: _documents.length,
                            itemBuilder: (context, index) {
                              final document = _documents[index];
                              final timestamp = (document['timestamp'] as Timestamp).toDate();
                              final docId = document['id'] ?? '';
                              
                              IconData fileIcon;
                              String fileDescription;
                              
                              switch (document['fileType']) {
                                case 'pdf':
                                  fileIcon = Icons.picture_as_pdf;
                                  fileDescription = 'PDF Document';
                                  break;
                                case 'doc':
                                case 'docx':
                                  fileIcon = Icons.description;
                                  fileDescription = 'Word Document';
                                  break;
                                case 'jpg':
                                case 'jpeg':
                                case 'png':
                                  fileIcon = Icons.image;
                                  fileDescription = 'Image';
                                  break;
                                default:
                                  fileIcon = Icons.insert_drive_file;
                                  fileDescription = 'Document';
                              }
                              
                              return ListTile(
                                leading: Icon(fileIcon, color: Colors.white, size: 28),
                                title: Text(
                                  document['fileName'] ?? fileDescription,
                                  style: TextStyle(color: Colors.white),
                                ),
                                subtitle: Text(
                                  'Uploaded: ${DateFormat('MMM d, h:mm a').format(timestamp)}',
                                  style: TextStyle(color: Colors.grey),
                                ),
                                trailing: IconButton(
                                  icon: Icon(Icons.open_in_new, color: AppColors.gold),
                                  onPressed: () {
                                    // Open document URL
                                    if (document['fileUrl'] != null) {
                                      // Open URL in browser or viewer
                                    }
                                  },
                                ),
                              );
                            },
                          ),
                  ),
                  
                  SizedBox(height: 40),
                ],
              ),
            ),
    );
  }

  // Helper widgets

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.gold, size: 18),
          SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: AppColors.gold,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
                Text(
                  value,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(String label, IconData icon, Color color, VoidCallback onPressed) {
    return Center(
      child: ElevatedButton.icon(
        icon: Icon(icon, color: Colors.white),
        label: Text(label),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
        ),
        onPressed: onPressed,
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
        return Colors.green;
      case 'in-progress':
      case 'in_progress':
        return Colors.blue;
      case 'cancelled':
        return Colors.red;
      case 'pending':
      default:
        return Colors.orange;
    }
  }

  String _formatStatus(String status) {
    switch (status.toLowerCase()) {
      case 'in-progress':
      case 'in_progress':
        return 'In Progress';
      case 'completed':
        return 'Completed';
      case 'cancelled':
        return 'Cancelled';
      case 'pending':
      default:
        return 'Pending';
    }
  }

  Widget _buildFeatureButton(String label, IconData icon, Color color, VoidCallback onPressed) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        CircleAvatar(
          backgroundColor: color.withOpacity(0.2),
          radius: 28,
          child: IconButton(
            icon: Icon(icon, color: color),
            onPressed: onPressed,
          ),
        ),
        SizedBox(height: 4),
        Text(label, style: TextStyle(color: Colors.white70, fontSize: 12)),
      ],
    );
  }

  Icon _getActivityIcon(String type) {
    switch (type) {
      case 'session_start':
        return Icon(Icons.play_arrow, color: Colors.green);
      case 'session_end':
        return Icon(Icons.stop, color: Colors.red);
      case 'note':
        return Icon(Icons.note, color: Colors.amber);
      case 'document':
        return Icon(Icons.description, color: Colors.blue);
      default:
        return Icon(Icons.info, color: Colors.white);
    }
  }
}
