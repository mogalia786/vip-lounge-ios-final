import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:workmanager/workmanager.dart';
import '../../../../core/constants/constants.dart';
import '../../../../core/services/phone_data_updater.dart';
import '../../../../injection_container.dart' as di;

class PhoneDataSettingsScreen extends StatefulWidget {
  const PhoneDataSettingsScreen({Key? key}) : super(key: key);

  @override
  _PhoneDataSettingsScreenState createState() => _PhoneDataSettingsScreenState();
}

class _PhoneDataSettingsScreenState extends State<PhoneDataSettingsScreen> {
  bool _isUpdating = false;
  String _lastUpdate = 'Never';
  String _status = '';

  @override
  void initState() {
    super.initState();
    _loadLastUpdateTime();
  }

  Future<void> _loadLastUpdateTime() async {
    final prefs = await SharedPreferences.getInstance();
    final lastUpdate = prefs.getInt('last_phone_data_update');
    
    if (lastUpdate != null) {
      final date = DateTime.fromMillisecondsSinceEpoch(lastUpdate);
      setState(() {
        _lastUpdate = DateFormat('yyyy-MM-dd HH:mm').format(date);
      });
    }
  }

  Future<void> _updatePhoneData() async {
    if (_isUpdating) return;

    setState(() {
      _isUpdating = true;
      _status = 'Updating phone data...';
    });

    try {
      final updater = PhoneDataUpdater(apiKey: di.sl());
      await updater.updateAllPhoneData();
      
      // Update last update time
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('last_phone_data_update', DateTime.now().millisecondsSinceEpoch);
      
      setState(() {
        _status = 'Phone data updated successfully!';
        _lastUpdate = DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now());
      });
    } catch (e) {
      setState(() {
        _status = 'Error updating phone data: $e';
      });
    } finally {
      setState(() {
        _isUpdating = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Phone Data Settings'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Phone Database',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text('Last updated: $_lastUpdate'),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _isUpdating ? null : _updatePhoneData,
                      child: _isUpdating
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : const Text('Update Now'),
                    ),
                    if (_status.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Text(
                        _status,
                        style: TextStyle(
                          color: _status.contains('Error') ? Colors.red : Colors.green,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'About',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'The phone database contains specifications for various phone models. '
                      'You can update this data manually or it will update automatically once a month.',
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
