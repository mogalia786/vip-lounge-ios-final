import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as path;

class PickupLocationsScreen extends StatefulWidget {
  const PickupLocationsScreen({Key? key}) : super(key: key);

  @override
  _PickupLocationsScreenState createState() => _PickupLocationsScreenState();
}

class _PickupLocationsScreenState extends State<PickupLocationsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _locationController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _firestore = FirebaseFirestore.instance;
  final _storage = FirebaseStorage.instance;
  final _picker = ImagePicker();
  
  String? _editingId;
  File? _imageFile;
  String? _imageUrl;
  bool _isLoading = false;

  Future<void> _pickImage() async {
    try {
      final pickedFile = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );
      
      if (pickedFile != null) {
        setState(() {
          _imageFile = File(pickedFile.path);
        });
      }
    } catch (e) {
      _showError('Failed to pick image: $e');
    }
  }

  Future<String?> _uploadImage() async {
    if (_imageFile == null) return null;
    
    try {
      final fileName = 'pickup_locations/${DateTime.now().millisecondsSinceEpoch}${path.extension(_imageFile!.path)}';
      final ref = _storage.ref().child(fileName);
      final uploadTask = ref.putFile(_imageFile!);
      final snapshot = await uploadTask.whenComplete(() {});
      final downloadUrl = await snapshot.ref.getDownloadURL();
      return downloadUrl.toString();
    } catch (e) {
      _showError('Failed to upload image: $e');
      return null;
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }



  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Pickup Locations'),
        backgroundColor: Colors.black,
        actions: [
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.only(right: 16.0),
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Form(
              key: _formKey,
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      children: [
                        GestureDetector(
                          onTap: _pickImage,
                          child: Container(
                            width: 120,
                            height: 120,
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey.shade400),
                              borderRadius: BorderRadius.circular(8),
                              image: _imageFile != null
                                  ? DecorationImage(
                                      image: FileImage(_imageFile!),
                                      fit: BoxFit.cover,
                                    )
                                  : _imageUrl != null
                                      ? DecorationImage(
                                          image: NetworkImage(_imageUrl!),
                                          fit: BoxFit.cover,
                                        )
                                      : null,
                            ),
                            child: _imageFile == null && _imageUrl == null
                                ? const Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.add_photo_alternate, size: 40, color: Colors.grey),
                                      SizedBox(height: 8),
                                      Text('Add Image', style: TextStyle(color: Colors.grey)),
                                    ],
                                  )
                                : null,
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _locationController,
                          decoration: const InputDecoration(
                            labelText: 'Location Name',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.location_on),
                          ),
                          validator: (value) =>
                              value?.isEmpty ?? true ? 'Required field' : null,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _descriptionController,
                          decoration: const InputDecoration(
                            labelText: 'Description (Optional)',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.description),
                          ),
                          maxLines: 2,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton(
                    onPressed: _saveLocation,
                    child: Text(_editingId == null ? 'Add' : 'Update'),
                  ),
                  if (_editingId != null) ...[
                    const SizedBox(width: 10),
                    TextButton(
                      onPressed: _cancelEdit,
                      child: const Text('Cancel'),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const Divider(),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _firestore.collection('pickup_locations').snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final locations = snapshot.data?.docs ?? [];

                return ListView.builder(
                  itemCount: locations.length,
                  itemBuilder: (context, index) {
                    final location = locations[index];
                    final imageUrl = location['imageUrl'] as String?;
                    final name = location['name'] as String;
                    final description = location['description'] as String?;
                    
                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                      elevation: 2,
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(8),
                        leading: imageUrl != null && imageUrl.isNotEmpty
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.network(
                                  imageUrl,
                                  width: 60,
                                  height: 60,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) => 
                                      const Icon(Icons.broken_image, size: 40),
                                ),
                              )
                            : const Icon(Icons.location_on, size: 40, color: Colors.blue),
                        title: Text(
                          name,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: description?.isNotEmpty == true
                            ? Text(description!)
                            : null,
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit, color: Colors.blue),
                              onPressed: _isLoading ? null : () => _editLocation(location),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: _isLoading 
                                  ? null 
                                  : () => _deleteLocation(location.id, imageUrl),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _saveLocation() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _isLoading = true);

    try {
      String? imageUrl = _imageUrl;
      
      // Upload new image if selected
      if (_imageFile != null) {
        final uploadedUrl = await _uploadImage();
        if (uploadedUrl != null) {
          imageUrl = uploadedUrl;
        }
      }
      
      final locationData = {
        'name': _locationController.text.trim(),
        'description': _descriptionController.text.trim(),
        'imageUrl': imageUrl,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (_editingId == null) {
        await _firestore.collection('pickup_locations').add(locationData);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location added successfully')),
        );
      } else {
        await _firestore
            .collection('pickup_locations')
            .doc(_editingId)
            .update(locationData);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location updated successfully')),
        );
      }

      _resetForm();
    } catch (e) {
      _showError('Error saving location: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
  
  void _resetForm() {
    _locationController.clear();
    _descriptionController.clear();
    setState(() {
      _editingId = null;
      _imageFile = null;
      _imageUrl = null;
    });
  }

  void _editLocation(QueryDocumentSnapshot location) {
    setState(() {
      _editingId = location.id;
      _locationController.text = location['name'];
      _descriptionController.text = location['description'] ?? '';
      _imageUrl = location['imageUrl'];
    });
  }

  Future<void> _deleteLocation(String id, String? imageUrl) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Delete'),
        content: const Text('Are you sure you want to delete this location? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() => _isLoading = true);
      
      try {
        // Delete the location document
        await _firestore.collection('pickup_locations').doc(id).delete();
        
        // If there's an associated image, delete it from storage
        if (imageUrl != null && imageUrl.isNotEmpty) {
          try {
            await _storage.refFromURL(imageUrl).delete();
          } catch (e) {
            // Log the error but don't fail the operation
            debugPrint('Error deleting image: $e');
          }
        }
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Location deleted successfully')),
          );
        }
      } catch (e) {
        if (mounted) {
          _showError('Error deleting location: $e');
        }
      } finally {
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    }
  }

  void _cancelEdit() {
    _locationController.clear();
    setState(() => _editingId = null);
  }

}
