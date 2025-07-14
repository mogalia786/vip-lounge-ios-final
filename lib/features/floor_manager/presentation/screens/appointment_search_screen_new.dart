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

  // Search appointments by reference number or minister's first name
  Future<void> _searchAppointments(String query) async {
    final searchQuery = query.trim();
    if (searchQuery.isEmpty) {
      setState(() {
        _appointmentData = null;
        _searchResults = [];
        _errorMessage = null;
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
      print('🔍 Searching for appointments with query: "$searchQuery"');
      
      // First, try to get all appointments to debug
      print('📋 Fetching all appointments to check data...');
      final allAppointments = await _firestore.collection('appointments').limit(5).get();
      
      if (allAppointments.docs.isEmpty) {
        print('❌ No appointments found in the appointments collection');
      } else {
        print('ℹ️ Found ${allAppointments.docs.length} appointments in collection');
        print('Sample appointment data:');
        _logDocumentFields(allAppointments.docs.first);
      }
      
      // Try exact match on referenceNumber first (case-insensitive)
      final refQuery = searchQuery.toUpperCase();
      print('🔎 Searching for referenceNumber: "$refQuery"');
      
      // Try different possible field names for reference number
      final possibleRefFields = ['referenceNumber', 'bookingReference', 'refNumber', 'id'];
      bool foundMatch = false;
      
      for (final field in possibleRefFields) {
        try {
          final refSnapshot = await _firestore
              .collection('appointments')
              .where(field, isEqualTo: refQuery)
              .get();
              
          print('   - Checked field "$field": found ${refSnapshot.docs.length} matches');
          
          if (refSnapshot.docs.isNotEmpty) {
            print('✅ Found match in field: $field');
            _processSearchResults(refSnapshot.docs);
            foundMatch = true;
            return;
          }
        } catch (e) {
          print('⚠️ Error searching field "$field": $e');
        }
      }
      
      // If no exact reference match, search by minister's name (case-insensitive)
      if (!foundMatch) {
        print('🔍 No reference match found, trying minister name search...');
        final nameQuery = searchQuery.toLowerCase();
        print('👤 Searching for minister name containing: "$nameQuery"');
        
        try {
          // First try with exact case
          var nameSnapshot = await _firestore
              .collection('appointments')
              .where('ministerName', isGreaterThanOrEqualTo: nameQuery)
              .where('ministerName', isLessThanOrEqualTo: nameQuery + '\uf8ff')
              .get();
              
          if (nameSnapshot.docs.isEmpty) {
            // Try with capitalized first letter
            final capitalizedQuery = nameQuery.isNotEmpty 
                ? nameQuery[0].toUpperCase() + nameQuery.substring(1)
                : nameQuery;
                
            nameSnapshot = await _firestore
                .collection('appointments')
                .where('ministerName', isGreaterThanOrEqualTo: capitalizedQuery)
                .where('ministerName', isLessThanOrEqualTo: capitalizedQuery + '\uf8ff')
                .get();
                
            if (nameSnapshot.docs.isEmpty) {
              // Try with all uppercase
              nameSnapshot = await _firestore
                  .collection('appointments')
                  .where('ministerName', isGreaterThanOrEqualTo: nameQuery.toUpperCase())
                  .where('ministerName', isLessThanOrEqualTo: nameQuery.toUpperCase() + '\uf8ff')
                  .get();
            }
          }
          
          if (nameSnapshot.docs.isNotEmpty) {
            print('✅ Found ${nameSnapshot.docs.length} matches by minister name');
            _processSearchResults(nameSnapshot.docs);
            return;
          }
        } catch (e) {
          print('⚠️ Error searching by minister name: $e');
        }
      }
      
      // If we get here, no matches were found
      print('❌ No appointments found matching "$searchQuery"');
      setState(() {
        _appointmentData = null;
        _searchResults = [];
        _errorMessage = 'No appointments found for "$searchQuery"\n\nTry a different reference number or minister name.';
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
  
  Widget _buildInfoRow(String label, String value, {bool isImportant = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.grey[700],
                fontSize: 14,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value.isNotEmpty ? value : 'Not specified',
              style: TextStyle(
                fontWeight: isImportant ? FontWeight.w600 : FontWeight.normal,
                color: isImportant ? AppColors.primary : Colors.black87,
                fontSize: 14,
              ),
            ),
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
                      hintText: 'Search by reference or minister name...',
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
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12.0),
      ),
      child: Column(
        children: [
          // Back button to return to search results
          if (_searchResults.length > 1)
            InkWell(
              onTap: () {
                setState(() {
                  _appointmentData = null;
                });
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(12),
                    topRight: Radius.circular(12),
                  ),
                ),
                child: Row(
                  children: const [
                    Icon(Icons.arrow_back, size: 16, color: Colors.blueGrey),
                    SizedBox(width: 8),
                    Text(
                      'Back to results',
                      style: TextStyle(
                        color: Colors.blueGrey,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header with reference and status
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Ref: ${appointment['referenceNumber'] ?? 'N/A'}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.blueGrey,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
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
                    ],
                  ),
                  
                  const Divider(height: 32, thickness: 1.2),
                  
                  // Appointment details
                  _buildSectionTitle('Appointment Details'),
                  _buildInfoRow('Date', formattedDate, isImportant: true),
                  _buildInfoRow('Time', formattedTime, isImportant: true),
                  _buildInfoRow('Duration', '${appointment['duration'] ?? '60'} minutes'),
                  
                  // Minister details
                  _buildSectionTitle('Minister Information'),
                  _buildInfoRow('Name', appointment['ministerName'] ?? 'N/A', isImportant: true),
                  if (appointment['ministerEmail'] != null)
                    _buildInfoRow('Email', appointment['ministerEmail']),
                  if (appointment['ministerPhone'] != null)
                    _buildInfoRow('Phone', appointment['ministerPhone']),
                  
                  // Consultant details
                  if (appointment['consultantName'] != null) ...[
                    _buildSectionTitle('Consultant'),
                    _buildInfoRow('Name', appointment['consultantName'] ?? 'N/A'),
                    if (appointment['consultantEmail'] != null)
                      _buildInfoRow('Email', appointment['consultantEmail']),
                    if (appointment['consultantPhone'] != null)
                      _buildInfoRow('Phone', appointment['consultantPhone']),
                  ],
                  
                  // Additional information
                  if (appointment['reason'] != null || 
                      appointment['notes'] != null ||
                      appointment['specialRequirements'] != null) 
                    _buildSectionTitle('Additional Information'),
                    
                  if (appointment['reason'] != null)
                    _buildInfoRow('Reason', appointment['reason']),
                        
                  if (appointment['specialRequirements'] != null)
                    _buildInfoRow('Requirements', appointment['specialRequirements']),
                  
                  // Notes section
                  if (appointment['notes'] != null) ...[
                    _buildSectionTitle('Notes'),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12.0),
                      decoration: BoxDecoration(
                        color: Colors.blue[50],
                        borderRadius: BorderRadius.circular(8.0),
                        border: Border.all(color: Colors.blue[100]!),
                      ),
                      child: Text(
                        appointment['notes'],
                        style: const TextStyle(fontSize: 14, height: 1.5),
                      ),
                    ),
                  ],
                  
                  const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
