import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../data/services/client_type_service.dart';

class ClientTypesScreen extends StatefulWidget {
  const ClientTypesScreen({Key? key}) : super(key: key);

  @override
  _ClientTypesScreenState createState() => _ClientTypesScreenState();
}

class _ClientTypesScreenState extends State<ClientTypesScreen> {
  final _formKey = GlobalKey<FormState>();
  final _typeController = TextEditingController();
  final _descriptionController = TextEditingController();
  final ClientTypeService _clientTypeService = ClientTypeService();
  String? _editingId;
  bool _isLoading = false;
  
  @override
  void initState() {
    super.initState();
    // Initialize default client types when the screen loads
    _initializeDefaultClientTypes();
  }
  
  Future<void> _initializeDefaultClientTypes() async {
    try {
      await _clientTypeService.initializeDefaultClientTypes();
    } catch (e) {
      _showError('Error initializing default client types: $e');
    }
  }



  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  @override
  void dispose() {
    _typeController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _resetForm() {
    _typeController.clear();
    _descriptionController.clear();
    setState(() {
      _editingId = null;
    });
  }
  
  void _editClientType(QueryDocumentSnapshot type) {
    setState(() {
      _editingId = type.id;
      _typeController.text = type['name'] as String;
      _descriptionController.text = type['description'] as String? ?? '';
    });
  }
  
  void _cancelEdit() {
    _resetForm();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Client Types'),
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
                        // Removed icon upload functionality as per requirements
                        TextFormField(
                          controller: _typeController,
                          decoration: const InputDecoration(
                            labelText: 'Client Type',
                            hintText: 'e.g., Influencer, Corporate Executive',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.person),
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
                    onPressed: _saveClientType,
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
              stream: _clientTypeService.getClientTypes(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final types = snapshot.data?.docs ?? [];

                return ListView.builder(
                  itemCount: types.length,
                  itemBuilder: (context, index) {
                    final type = types[index];
                    final imageUrl = type['imageUrl'] as String?;
                    final name = type['name'] as String;
                    final description = type['description'] as String?;
                    
                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                      elevation: 2,
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(8),
                        leading: const Icon(Icons.person, size: 40, color: Colors.green),
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
                              onPressed: _isLoading ? null : () => _editClientType(type),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: _isLoading 
                                  ? null 
                                  : () => _deleteClientType(type.id, imageUrl),
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

  Future<void> _saveClientType() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _isLoading = true);

    try {
      final typeData = {
        'name': _typeController.text.trim(),
        'description': _descriptionController.text.trim(),
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (_editingId == null) {
        await _clientTypeService.addClientType(typeData);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Client type added successfully')),
        );
      } else {
        await _clientTypeService.updateClientType(_editingId!, typeData);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Client type updated successfully')),
        );
      }

      _resetForm();
    } catch (e) {
      _showError('Error saving client type: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _deleteClientType(String id, String? imageUrl) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Client Type'),
        content: const Text('Are you sure you want to delete this client type?'),
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
        // Delete the client type document
        await _clientTypeService.deleteClientType(id);
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Client type deleted successfully')),
          );
        }
      } catch (e) {
        if (mounted) {
          _showError('Error deleting client type: $e');
        }
      } finally {
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    }
  }


}
