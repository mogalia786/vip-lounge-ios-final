import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/constants/colors.dart';

class AppointmentSearchScreen extends StatefulWidget {
  const AppointmentSearchScreen({super.key});

  @override
  _AppointmentSearchScreenState createState() => _AppointmentSearchScreenState();
}

class _AppointmentSearchScreenState extends State<AppointmentSearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  // State variables
  Map<String, dynamic>? _appointmentData;
  List<Map<String, dynamic>> _searchResults = [];
  bool _isLoading = false;
  String? _errorMessage;
  bool _hasSearched = false;
  
  // Date formatters
  final DateFormat _dateFormat = DateFormat('EEEE, MMMM d, y');
  final DateFormat _timeFormat = DateFormat('h:mm a');

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }
  
  void _onSearchChanged() {
    if (_searchController.text.isEmpty) {
      setState(() {
        _appointmentData = null;
        _errorMessage = null;
        _hasSearched = false;
      });
    }
  }
  
  // Helper method to log document fields for debugging
  void _logDocumentFields(QueryDocumentSnapshot doc) {
    print('Document ID: ${doc.id}');
    print('Data: ${doc.data()}');
    (doc.data() as Map<String, dynamic>).forEach((key, value) {
      print('  $key: $value (${value.runtimeType})');
    });
  }

  // Search appointments by reference number only
  Future<void> _searchAppointments(String query) async {
    final searchQuery = query.trim();
    if (searchQuery.isEmpty) {
      setState(() {
        _appointmentData = null;
        _searchResults = [];
        _errorMessage = 'Please enter a reference number to search';
        _hasSearched = false;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _hasSearched = true;
      _searchResults = [];
    });

    try {
      // Convert to uppercase as we know reference numbers are stored in uppercase
      final refQuery = searchQuery.trim().toUpperCase();
      print('🔍 [SEARCH] Searching for reference: "$refQuery"');
      
      // Direct query for the referenceNumber field
      final querySnapshot = await _firestore
          .collection('appointments')
          .where('referenceNumber', isEqualTo: refQuery)
          .limit(1)
          .get();
          
      print('📊 Found ${querySnapshot.docs.length} matching documents');
      
      if (querySnapshot.docs.isNotEmpty) {
        final doc = querySnapshot.docs.first;
        print('✅ Found matching appointment');
        print('📄 Document ID: ${doc.id}');
        print('📄 Document data:');
        _logDocumentFields(doc);
        
        // Process the result
        final data = doc.data() as Map<String, dynamic>;
        final result = {'id': doc.id, ...data};
        
        setState(() {
          _appointmentData = result;
          _searchResults = [result];
          _isLoading = false;
        });
        return;
      } else {
        // If no match found, try to check if the collection exists and has any documents
        try {
          final sampleDoc = await _firestore.collection('appointments').limit(1).get();
          if (sampleDoc.docs.isEmpty) {
            print('❌ Appointments collection exists but is empty');
            setState(() {
              _errorMessage = 'No appointments found in the system';
            });
          } else {
            print('ℹ️ Found ${sampleDoc.size} documents in appointments collection');
            print('📄 Sample document fields: ${sampleDoc.docs.first.data().keys.toList()}');
            
            // If we have documents but no match, show a more specific message
            setState(() {
              _errorMessage = 'No appointment found with reference: $refQuery';
            });
          }
        } catch (e) {
          print('⚠️ Error checking appointments collection: $e');
          setState(() {
            _errorMessage = 'Error accessing appointments: ${e.toString()}';
          });
        }
      }
      
      // If we get here, no matches were found
      print('❌ No appointment found with reference: "$refQuery"');
      setState(() {
        _appointmentData = null;
        _searchResults = [];
        _errorMessage = 'No appointment found with reference: $refQuery\n\nPlease check the reference number and try again.';
        _isLoading = false;
      });
    } catch (e) {
      print('Error searching appointments: $e');
      setState(() {
        _appointmentData = null;
        _searchResults = [];
        _errorMessage = 'Error searching appointments. Please try again.';
      });
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
  
  // Process search results and update UI
  void _processSearchResults(List<QueryDocumentSnapshot> docs) {
    try {
      print('🔧 Processing ${docs.length} search results...');
      
      final results = <Map<String, dynamic>>[];
      
      for (final doc in docs) {
        try {
          print('\n📄 Processing document ID: ${doc.id}');
          final data = doc.data() as Map<String, dynamic>;
          
          // Log all fields for debugging
          print('📋 Document data:');
          data.forEach((key, value) {
            print('   - $key: $value (${value.runtimeType})');
          });
          
          // Ensure required fields exist
          final result = {'id': doc.id, ...data};
          
          // Check for ministerName or alternative field names
          if (!result.containsKey('ministerName')) {
            // Try to find minister name in alternative fields
            final nameFields = ['name', 'minister', 'minister_name', 'clientName'];
            for (final field in nameFields) {
              if (result.containsKey(field) && result[field] != null) {
                result['ministerName'] = result[field];
                print('⚠️ Using alternative field "$field" for ministerName: ${result[field]}');
                break;
              }
            }
          }
          
          // Ensure reference number exists
          if (!result.containsKey('referenceNumber')) {
            // Try to find reference in alternative fields
            final refFields = ['bookingReference', 'refNumber', 'id', 'bookingId'];
            for (final field in refFields) {
              if (result.containsKey(field) && result[field] != null) {
                result['referenceNumber'] = result[field];
                print('⚠️ Using alternative field "$field" for referenceNumber: ${result[field]}');
                break;
              }
            }
          }
          
          results.add(result);
          print('✅ Added result: ${result['ministerName'] ?? 'Unnamed'} (Ref: ${result['referenceNumber'] ?? 'N/A'})');
          
        } catch (e) {
          print('⚠️ Error processing document ${doc.id}: $e');
        }
      }
      
      setState(() {
        _searchResults = results;
        _isLoading = false;
        _errorMessage = null;
      });
      
      print('\n🔍 Search complete. Found ${results.length} valid results.');
      
      // If only one result, show it directly
      if (results.length == 1) {
        print('ℹ️ Showing single result directly');
        setState(() {
          _appointmentData = results.first;
        });
      } else if (results.isNotEmpty) {
        print('ℹ️ Showing list of ${results.length} results');
      } else {
        print('ℹ️ No valid results found after processing');
        setState(() {
          _errorMessage = 'No valid appointment data found. The appointments may be missing required fields.';
        });
      }
      
    } catch (e) {
      print('❌ Error processing search results: $e');
      print('Stack trace: ${StackTrace.current}');
      
      setState(() {
        _errorMessage = 'Error processing search results. Please try again.';
        _isLoading = false;
      });
    } 
  }
  
  // Build an info row with label and value
  Widget _buildInfoRow(String label, String value, {bool isImportant = false, bool isMultiline = false}) {
    if (value.isEmpty) return const SizedBox.shrink();
    
    // Check if this is a contact field that should be clickable
    final bool isEmail = label.toLowerCase().contains('email');
    final bool isPhone = label.toLowerCase().contains('phone');
    
    Widget valueWidget = Text(
      value,
      style: TextStyle(
        fontWeight: isImportant ? FontWeight.w600 : FontWeight.normal,
        color: isImportant ? Colors.blueGrey[900] : Colors.blueGrey[800],
        fontSize: 14,
        decoration: (isEmail || isPhone) ? TextDecoration.underline : null,
        decorationColor: (isEmail || isPhone) ? Colors.blue : null,
      ),
      maxLines: isMultiline ? null : 1,
      overflow: isMultiline ? null : TextOverflow.ellipsis,
    );
    
    // Make email and phone clickable
    if (isEmail) {
      valueWidget = GestureDetector(
        onTap: () async {
          final Uri emailLaunchUri = Uri(
            scheme: 'mailto',
            path: value,
          );
          if (await canLaunchUrl(emailLaunchUri)) {
            await launchUrl(emailLaunchUri);
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Could not launch email client')),
            );
          }
        },
        child: valueWidget,
      );
    } else if (isPhone) {
      valueWidget = GestureDetector(
        onTap: () async {
          final Uri phoneLaunchUri = Uri(
            scheme: 'tel',
            path: value.replaceAll(RegExp(r'[^0-9+]'), ''),
          );
          if (await canLaunchUrl(phoneLaunchUri)) {
            await launchUrl(phoneLaunchUri);
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Could not launch phone app')),
            );
          }
        },
        child: valueWidget,
      );
    }
    
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: isMultiline ? CrossAxisAlignment.start : CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              '$label:',
              style: TextStyle(
                fontWeight: isImportant ? FontWeight.bold : FontWeight.normal,
                color: Colors.grey[700],
                fontSize: 14,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: valueWidget,
          ),
        ],
      ),
    );
  }
  
  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 16.0, bottom: 8.0),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: Colors.blueGrey,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
  
  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'confirmed':
        return Colors.blue;
      case 'completed':
        return Colors.green;
      case 'cancelled':
        return Colors.red;
      case 'rescheduled':
        return Colors.orange;
      case 'in progress':
        return Colors.amber[700]!;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Appointment Search'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          // Search bar
          Container(
            padding: const EdgeInsets.all(16.0),
            color: Colors.grey[50],
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search by reference',
                      prefixIcon: const Icon(Icons.search, color: Colors.grey),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, color: Colors.grey),
                              onPressed: () {
                                _searchController.clear();
                                setState(() {
                                  _appointmentData = null;
                                  _searchResults = [];
                                  _errorMessage = null;
                                  _hasSearched = false;
                                });
                              },
                            )
                          : null,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12.0),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                    ),
                    onSubmitted: _searchAppointments,
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () => _searchAppointments(_searchController.text),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12.0),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                  child: const Text('Search', style: TextStyle(color: Colors.white)),
                ),
              ],
            ),
          ),
          
          // Loading indicator
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: CircularProgressIndicator(),
            ),
            
          // Error message
          if (_errorMessage != null && !_isLoading)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Text(
                _errorMessage!,
                style: const TextStyle(color: Colors.red, fontSize: 14),
                textAlign: TextAlign.center,
              ),
            ),
            
          // Search results list or single appointment view
          if (_hasSearched && !_isLoading && _errorMessage == null)
            Expanded(
              child: _appointmentData != null
                  ? SingleChildScrollView(
                      padding: const EdgeInsets.all(16.0),
                      child: _buildAppointmentCard(),
                    )
                  : _buildSearchResultsList(),
            ),
            
          // Empty state
          if (!_hasSearched && _appointmentData == null && _searchResults.isEmpty)
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.calendar_today_rounded,
                      size: 64,
                      color: Colors.grey[300],
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Search for an appointment',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 32.0),
                      child: Text(
                        'Enter a reference number or minister name to search',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
  
  // Build the search results list
  Widget _buildSearchResultsList() {
    if (_searchResults.isEmpty) {
      return const Center(
        child: Text(
          'No appointments found',
          style: TextStyle(color: Colors.grey, fontSize: 16),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16.0),
      itemCount: _searchResults.length,
      itemBuilder: (context, index) {
        final appointment = _searchResults[index];
        return _buildAppointmentListItem(appointment);
      },
    );
  }
  
  // Build a single appointment list item
  Widget _buildAppointmentListItem(Map<String, dynamic> appointment) {
    // Format date and time
    String formattedDate = 'Not specified';
    String formattedTime = 'Not specified';
    
    try {
      if (appointment['appointmentTime'] != null) {
        final dateTime = (appointment['appointmentTime'] as Timestamp).toDate();
        formattedDate = _dateFormat.format(dateTime);
        formattedTime = _timeFormat.format(dateTime);
      } else if (appointment['date'] != null && appointment['time'] != null) {
        final date = (appointment['date'] as Timestamp).toDate();
        final timeParts = (appointment['time'] as String).split(':');
        final time = TimeOfDay(
          hour: int.parse(timeParts[0]),
          minute: int.parse(timeParts[1]),
        );
        formattedDate = _dateFormat.format(date);
        formattedTime = _timeFormat.format(DateTime(
          date.year,
          date.month,
          date.day,
          time.hour,
          time.minute,
        ));
      }
    } catch (e) {
      debugPrint('Error formatting date/time: $e');
    }
    
    // Get status with fallback
    final status = (appointment['status'] as String?)?.toLowerCase() ?? 'scheduled';
    final statusColor = _getStatusColor(status);
    
    return Card(
      margin: const EdgeInsets.only(bottom: 16.0),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12.0),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12.0),
        onTap: () {
          setState(() {
            _appointmentData = appointment;
          });
        },
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      appointment['ministerName'] ?? 'No Name',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: statusColor.withOpacity(0.3)),
                    ),
                    child: Text(
                      status.toUpperCase(),
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.calendar_today, size: 16, color: Colors.grey),
                  const SizedBox(width: 8),
                  Text(
                    formattedDate,
                    style: const TextStyle(fontSize: 13, color: Colors.grey),
                  ),
                  const SizedBox(width: 16),
                  const Icon(Icons.access_time, size: 16, color: Colors.grey),
                  const SizedBox(width: 8),
                  Text(
                    formattedTime,
                    style: const TextStyle(fontSize: 13, color: Colors.grey),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (appointment['referenceNumber'] != null)
                Row(
                  children: [
                    const Icon(Icons.receipt, size: 16, color: Colors.grey),
                    const SizedBox(width: 8),
                    Text(
                      'Ref: ${appointment['referenceNumber']}',
                      style: const TextStyle(fontSize: 13, color: Colors.grey),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildAppointmentCard() {
    final appointment = _appointmentData!;
    
    // Format date and time
    String formattedDate = 'Not specified';
    String formattedTime = 'Not specified';
    
    try {
      if (appointment['appointmentTime'] != null) {
        final dateTime = (appointment['appointmentTime'] as Timestamp).toDate();
        formattedDate = _dateFormat.format(dateTime);
        formattedTime = _timeFormat.format(dateTime);
      } else if (appointment['date'] != null) {
        final date = (appointment['date'] as Timestamp).toDate();
        formattedDate = _dateFormat.format(date);
        
        if (appointment['time'] != null) {
          try {
            final timeParts = (appointment['time'] as String).split(':');
            if (timeParts.length >= 2) {
              final time = TimeOfDay(
                hour: int.parse(timeParts[0]),
                minute: int.parse(timeParts[1]),
              );
              formattedTime = _timeFormat.format(DateTime(
                date.year,
                date.month,
                date.day,
                time.hour,
                time.minute,
              ));
            } else {
              formattedTime = appointment['time'].toString();
            }
          } catch (e) {
            formattedTime = appointment['time'].toString();
          }
        }
      }
    } catch (e) {
      debugPrint('Error formatting date/time: $e');
    }
    
    // Get status with fallback
    final status = (appointment['status'] as String?)?.toLowerCase() ?? 'scheduled';
    final statusColor = _getStatusColor(status);
    
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12.0),
      ),
      margin: const EdgeInsets.all(16.0),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header with reference and status
            Container(
              padding: const EdgeInsets.all(16.0),
              decoration: BoxDecoration(
                color: Colors.blueGrey[50],
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  topRight: Radius.circular(12),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: Text(
                      'Reference: ${appointment['referenceNumber'] ?? 'N/A'}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.blueGrey,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: statusColor.withOpacity(0.3)),
                    ),
                    child: Text(
                      status.toUpperCase(),
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            // Main content
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Appointment Details Section
                  _buildSection('Appointment Details', [
                    _buildInfoRow('Date', formattedDate, isImportant: true),
                    _buildInfoRow('Time', formattedTime, isImportant: true),
                    if (appointment['duration'] != null)
                      _buildInfoRow('Duration', '${appointment['duration']} minutes'),
                    if (appointment['serviceName'] != null)
                      _buildInfoRow('Service', appointment['serviceName']),
                    if (appointment['reason'] != null)
                      _buildInfoRow('Reason', appointment['reason']),
                  ]),
                  
                  // Minister Information Section
                  _buildSection('Minister Information', [
                    if (appointment['ministerName'] != null)
                      _buildInfoRow('Name', appointment['ministerName'], isImportant: true),
                    if (appointment['ministerEmail'] != null)
                      _buildInfoRow('Email', appointment['ministerEmail']),
                    if (appointment['ministerPhone'] != null)
                      _buildInfoRow('Phone', appointment['ministerPhone']),
                    if (appointment['userType'] != null)
                      _buildInfoRow('User Type', appointment['userType']),
                  ]),
                  
                  // Consultant Information Section
                  if (appointment['consultantName'] != null || 
                      appointment['consultantEmail'] != null ||
                      appointment['consultantPhone'] != null)
                    _buildSection('Consultant', [
                      if (appointment['consultantName'] != null)
                        _buildInfoRow('Name', appointment['consultantName']),
                      if (appointment['consultantEmail'] != null)
                        _buildInfoRow('Email', appointment['consultantEmail']),
                      if (appointment['consultantPhone'] != null)
                        _buildInfoRow('Phone', appointment['consultantPhone']),
                    ]),
                  
                  // Additional Information Section
                  _buildSection('Additional Information', [
                    if (appointment['specialRequirements'] != null && appointment['specialRequirements'].toString().isNotEmpty)
                      _buildInfoRow('Special Requirements', appointment['specialRequirements'].toString()),
                    if (appointment['notes'] != null && appointment['notes'].toString().isNotEmpty)
                      _buildInfoRow('Notes', appointment['notes'].toString(), isMultiline: true),
                    if ((appointment['specialRequirements'] == null || appointment['specialRequirements'].toString().isEmpty) &&
                        (appointment['notes'] == null || appointment['notes'].toString().isEmpty))
                      _buildInfoRow('No additional information', 'No special requirements or notes provided'),
                  ]),
                  
                  // Session Information Section
                  if (appointment['conciergeSessionStarted'] != null ||
                      appointment['conciergeSessionEnded'] != null ||
                      appointment['consultantSessionStarted'] != null ||
                      appointment['consultantSessionEnded'] != null)
                    _buildSection('Session Status', [
                      if (appointment['conciergeSessionStarted'] != null)
                        _buildInfoRow('Concierge Session', 
                            appointment['conciergeSessionStarted'] ? 'Started' : 'Not Started'),
                      if (appointment['conciergeSessionEnded'] != null)
                        _buildInfoRow('Concierge Session', 
                            appointment['conciergeSessionEnded'] ? 'Completed' : 'In Progress'),
                      if (appointment['consultantSessionStarted'] != null)
                        _buildInfoRow('Consultant Session', 
                            appointment['consultantSessionStarted'] ? 'Started' : 'Not Started'),
                      if (appointment['consultantSessionEnded'] != null)
                        _buildInfoRow('Consultant Session', 
                            appointment['consultantSessionEnded'] ? 'Completed' : 'In Progress'),
                    ]),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  // Helper method to create a section with title and content
  Widget _buildSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.blueGrey,
          ),
        ),
        const SizedBox(height: 8),
        Card(
          elevation: 1,
          margin: const EdgeInsets.only(bottom: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8.0),
            side: BorderSide(color: Colors.grey[200]!),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: children,
            ),
          ),
        ),
      ],
    );
  }
}
