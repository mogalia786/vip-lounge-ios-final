import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class QuerySearchSimple extends StatefulWidget {
  const QuerySearchSimple({super.key});

  @override
  _QuerySearchSimpleState createState() => _QuerySearchSimpleState();
}

class _QuerySearchSimpleState extends State<QuerySearchSimple> {
  final TextEditingController _searchController = TextEditingController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  Map<String, dynamic>? _result;
  String? _errorMessage;
  bool _isLoading = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _search(String referenceNumber) async {
    if (referenceNumber.trim().isEmpty) {
      setState(() {
        _errorMessage = 'Please enter a reference number';
        _isLoading = false;
        _result = null;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _result = null;
    });

    try {
      final searchNumber = referenceNumber.trim().toUpperCase();
      
      // Search in appointments
      var snapshot = await _firestore
          .collection('appointments')
          .where('referenceNumber', isEqualTo: searchNumber)
          .limit(1)
          .get();

      // If not found, search in queries
      if (snapshot.docs.isEmpty) {
        snapshot = await _firestore
            .collection('queries')
            .where('referenceNumber', isEqualTo: searchNumber)
            .limit(1)
            .get();
      }

      if (snapshot.docs.isNotEmpty) {
        setState(() {
          _result = {
            'id': snapshot.docs.first.id,
            ...snapshot.docs.first.data(),
            'isAppointment': snapshot.docs.first.reference.path.contains('appointments'),
          };
        });
      } else {
        setState(() {
          _errorMessage = 'No results found for: $searchNumber';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error: ${e.toString()}';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Search Reference'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                labelText: 'Enter Reference Number',
                hintText: 'e.g., REF12345',
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.search),
                  onPressed: _isLoading ? null : () => _search(_searchController.text),
                ),
              ),
              onSubmitted: _isLoading ? null : (value) => _search(value),
              enabled: !_isLoading,
            ),
            const SizedBox(height: 20),
            if (_isLoading) const CircularProgressIndicator(),
            if (_errorMessage != null)
              Text(
                _errorMessage!,
                style: const TextStyle(color: Colors.red),
              ),
            if (_result != null) _buildResultCard(),
          ],
        ),
      ),
    );
  }

  Widget _buildResultCard() {
    final data = _result!;
    final isAppointment = data['isAppointment'] == true;

    return Card(
      margin: const EdgeInsets.only(top: 20),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isAppointment ? 'Appointment Details' : 'Query Details',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const Divider(),
            ..._buildDataRows(data),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildDataRows(Map<String, dynamic> data) {
    final rows = <Widget>[];
    
    data.forEach((key, value) {
      // Skip internal fields
      if (key == 'isAppointment' || key == 'id') return;
      
      String displayValue;
      if (value is Timestamp) {
        displayValue = value.toDate().toString();
      } else {
        displayValue = value?.toString() ?? 'N/A';
      }
      
      rows.add(Padding(
        padding: const EdgeInsets.symmetric(vertical: 4.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 120,
              child: Text(
                '${key[0].toUpperCase()}${key.substring(1)}:',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(child: Text(displayValue)),
          ],
        ),
      ));
    });
    
    return rows;
  }
}
