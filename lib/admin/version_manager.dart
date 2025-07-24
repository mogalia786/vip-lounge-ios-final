import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import '../services/firebase_update_service.dart';

class VersionManagerScreen extends StatefulWidget {
  const VersionManagerScreen({Key? key}) : super(key: key);

  @override
  State<VersionManagerScreen> createState() => _VersionManagerScreenState();
}

class _VersionManagerScreenState extends State<VersionManagerScreen> {
  final _formKey = GlobalKey<FormState>();
  final _versionController = TextEditingController();
  final _buildNumberController = TextEditingController();
  final _messageController = TextEditingController();
  final _releaseNotesController = TextEditingController();
  
  bool _forceUpdate = false;
  bool _isUploading = false;
  String? _selectedApkPath;
  Map<String, dynamic>? _currentVersionInfo;

  @override
  void initState() {
    super.initState();
    _loadCurrentVersionInfo();
  }

  Future<void> _loadCurrentVersionInfo() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('app_versions')
          .doc('current')
          .get();
      
      if (doc.exists) {
        setState(() {
          _currentVersionInfo = doc.data();
        });
      }
    } catch (e) {
      debugPrint('Error loading current version info: $e');
    }
  }

  Future<void> _pickApkFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['apk'],
      );

      if (result != null) {
        setState(() {
          _selectedApkPath = result.files.single.path;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error picking file: $e')),
      );
    }
  }

  Future<void> _uploadNewVersion() async {
    if (!_formKey.currentState!.validate() || _selectedApkPath == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all fields and select an APK file')),
      );
      return;
    }

    setState(() {
      _isUploading = true;
    });

    try {
      final releaseNotes = _releaseNotesController.text
          .split('\n')
          .where((note) => note.trim().isNotEmpty)
          .toList();

      await FirebaseUpdateService.uploadNewVersion(
        version: _versionController.text.trim(),
        buildNumber: int.parse(_buildNumberController.text.trim()),
        apkFilePath: _selectedApkPath!,
        message: _messageController.text.trim(),
        releaseNotes: releaseNotes,
        forceUpdate: _forceUpdate,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('New version uploaded successfully!'),
          backgroundColor: Colors.green,
        ),
      );

      // Refresh current version info
      await _loadCurrentVersionInfo();

      // Clear form
      _versionController.clear();
      _buildNumberController.clear();
      _messageController.clear();
      _releaseNotesController.clear();
      setState(() {
        _selectedApkPath = null;
        _forceUpdate = false;
      });

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error uploading version: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isUploading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Version Manager'),
        backgroundColor: Colors.blue[800],
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Current Version Info
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Current Version',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (_currentVersionInfo != null) ...[
                      _buildInfoRow('Version', _currentVersionInfo!['version'] ?? 'Unknown'),
                      _buildInfoRow('Build Number', _currentVersionInfo!['buildNumber']?.toString() ?? 'Unknown'),
                      _buildInfoRow('APK File', _currentVersionInfo!['apkFileName'] ?? 'Unknown'),
                      _buildInfoRow('Force Update', _currentVersionInfo!['forceUpdate'] == true ? 'Yes' : 'No'),
                      _buildInfoRow('Message', _currentVersionInfo!['message'] ?? 'No message'),
                      if (_currentVersionInfo!['uploadedAt'] != null)
                        _buildInfoRow('Uploaded', 
                          (_currentVersionInfo!['uploadedAt'] as Timestamp).toDate().toString()),
                    ] else
                      const Text('No version information available'),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Upload New Version Form
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Upload New Version',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      
                      // Version
                      TextFormField(
                        controller: _versionController,
                        decoration: const InputDecoration(
                          labelText: 'Version (e.g., 2.1.0)',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter version';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      
                      // Build Number
                      TextFormField(
                        controller: _buildNumberController,
                        decoration: const InputDecoration(
                          labelText: 'Build Number (e.g., 15)',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter build number';
                          }
                          if (int.tryParse(value.trim()) == null) {
                            return 'Please enter valid number';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      
                      // Update Message
                      TextFormField(
                        controller: _messageController,
                        decoration: const InputDecoration(
                          labelText: 'Update Message',
                          border: OutlineInputBorder(),
                        ),
                        maxLines: 2,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter update message';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      
                      // Release Notes
                      TextFormField(
                        controller: _releaseNotesController,
                        decoration: const InputDecoration(
                          labelText: 'Release Notes (one per line)',
                          border: OutlineInputBorder(),
                          hintText: 'Fixed staff attendance calculations\nAdded corrupted timestamp detection\nEnhanced feedback management',
                        ),
                        maxLines: 5,
                      ),
                      const SizedBox(height: 16),
                      
                      // Force Update Switch
                      SwitchListTile(
                        title: const Text('Force Update'),
                        subtitle: const Text('Users must update to continue using the app'),
                        value: _forceUpdate,
                        onChanged: (value) {
                          setState(() {
                            _forceUpdate = value;
                          });
                        },
                      ),
                      const SizedBox(height: 16),
                      
                      // APK File Picker
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey[300]!),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          children: [
                            Icon(
                              Icons.android,
                              size: 48,
                              color: Colors.grey[600],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _selectedApkPath != null
                                  ? 'Selected: ${_selectedApkPath!.split('/').last}'
                                  : 'No APK file selected',
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 12),
                            ElevatedButton.icon(
                              onPressed: _pickApkFile,
                              icon: const Icon(Icons.file_upload),
                              label: const Text('Select APK File'),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      
                      // Upload Button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _isUploading ? null : _uploadNewVersion,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue[800],
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                          child: _isUploading
                              ? const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                      ),
                                    ),
                                    SizedBox(width: 12),
                                    Text('Uploading...'),
                                  ],
                                )
                              : const Text(
                                  'Upload New Version',
                                  style: TextStyle(fontSize: 16),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            child: Text(value),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _versionController.dispose();
    _buildNumberController.dispose();
    _messageController.dispose();
    _releaseNotesController.dispose();
    super.dispose();
  }
}
