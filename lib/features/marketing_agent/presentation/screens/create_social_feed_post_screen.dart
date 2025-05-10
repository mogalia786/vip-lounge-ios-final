import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/social_feed_post_model.dart';
import '../../../../core/constants/colors.dart';

class CreateSocialFeedPostScreen extends StatefulWidget {
  final String agentId;
  final String agentName;
  const CreateSocialFeedPostScreen({required this.agentId, required this.agentName, Key? key}) : super(key: key);

  @override
  State<CreateSocialFeedPostScreen> createState() => _CreateSocialFeedPostScreenState();
}

class _CreateSocialFeedPostScreenState extends State<CreateSocialFeedPostScreen> {
  final _formKey = GlobalKey<FormState>();
  String? _selectedType;
  DateTime? _beginDate;
  DateTime? _expirationDate;
  String _details = '';
  String _telephoneNumber = '';
  String _terms = '';
  List<XFile> _images = [];
  bool _isSubmitting = false;

  final List<String> _types = [
    'Service Promotions',
    'Upcoming Events',
    'New Services',
    'Announcements',
    'Partner Offers',
    'General Notices',
  ];

  final Map<String, Color> _typeColors = {
    'Service Promotions': Color(0xFF00C9A7),
    'Upcoming Events': Color(0xFF1E90FF),
    'New Services': Color(0xFFFFA500),
    'Announcements': Color(0xFF8A2BE2),
    'Partner Offers': Color(0xFF43A047),
    'General Notices': Color(0xFFFB3C62),
  };

  Color getContrastTextColor(Color bg) {
    return bg.computeLuminance() > 0.5 ? Colors.black : Colors.white;
  }

  Future<void> _pickImages() async {
    final ImagePicker picker = ImagePicker();
    final List<XFile>? picked = await picker.pickMultiImage();
    if (picked != null) {
      setState(() {
        _images = picked;
      });
    }
  }

  Future<List<String>> _uploadImages(String postId) async {
    final storage = FirebaseStorage.instance;
    List<String> urls = [];
    for (var i = 0; i < _images.length; i++) {
      final ref = storage.ref('marketing_posts/$postId/img_$i.jpg');
      await ref.putFile(File(_images[i].path));
      final url = await ref.getDownloadURL();
      urls.add(url);
    }
    return urls;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() || _beginDate == null || _expirationDate == null || _selectedType == null) return;
    setState(() { _isSubmitting = true; });
    _formKey.currentState!.save();
    try {
      final postId = FirebaseFirestore.instance.collection('marketing_posts').doc().id;
      final imageUrls = await _uploadImages(postId);
      final post = SocialFeedPostModel(
        id: postId,
        agentId: widget.agentId,
        agentName: widget.agentName,
        type: _selectedType!,
        beginDate: _beginDate!,
        expirationDate: _expirationDate!,
        details: _details,
        telephoneNumber: _telephoneNumber,
        termsAndConditions: _terms,
        imageUrls: imageUrls,
        createdAt: Timestamp.now(),
        likeCount: 0,
      );
      await FirebaseFirestore.instance.collection('marketing_posts').doc(postId).set(post.toMap());
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to post: $e')));
    } finally {
      setState(() { _isSubmitting = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final Color glareColor = _selectedType != null ? _typeColors[_selectedType!]!.withOpacity(0.15) : Colors.white10;
    final Color safeShadowColor = (_selectedType != null)
      ? (_typeColors[_selectedType!] ?? AppColors.gold)
      : AppColors.gold;
    return Scaffold(
      backgroundColor: AppColors.black,
      appBar: AppBar(
        backgroundColor: AppColors.black,
        foregroundColor: AppColors.gold,
        title: const Text('Create Social Feed Post'),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [AppColors.black, glareColor, AppColors.gold.withOpacity(0.05)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            child: Card(
              elevation: 16,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              color: AppColors.black.withOpacity(0.95),
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                        decoration: BoxDecoration(
                          color: _selectedType != null ? _typeColors[_selectedType!] : Colors.white12,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: (_selectedType != null ? _typeColors[_selectedType!]! : Colors.white12).withOpacity(0.3),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: DropdownButtonFormField<String>(
                          value: _selectedType,
                          decoration: InputDecoration(
                            labelText: 'Type',
                            labelStyle: TextStyle(color: _selectedType != null ? getContrastTextColor(_typeColors[_selectedType!] ?? AppColors.gold) : AppColors.gold),
                          ),
                          style: TextStyle(color: _selectedType != null ? getContrastTextColor(_typeColors[_selectedType!] ?? AppColors.gold) : AppColors.gold),
                          dropdownColor: _selectedType != null ? _typeColors[_selectedType!] ?? AppColors.gold : Colors.black,
                          items: _types.map((type) {
                            return DropdownMenuItem<String>(
                              value: type,
                              child: Text(
                                type,
                                style: TextStyle(
                                  color: getContrastTextColor(_typeColors[type] ?? AppColors.gold),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            );
                          }).toList(),
                          onChanged: (value) {
                            setState(() {
                              _selectedType = value;
                            });
                          },
                          validator: (value) => value == null ? 'Please select a type' : null,
                        ),
                      ),
                      const SizedBox(height: 18),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            Expanded(
                              child: GestureDetector(
                                onTap: () async {
                                  final picked = await showDatePicker(
                                    context: context,
                                    initialDate: DateTime.now(),
                                    firstDate: DateTime.now().subtract(const Duration(days: 1)),
                                    lastDate: DateTime.now().add(const Duration(days: 365)),
                                  );
                                  if (picked != null) setState(() => _beginDate = picked);
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                                  decoration: BoxDecoration(
                                    color: Colors.white12,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(Icons.date_range, color: AppColors.gold),
                                      const SizedBox(width: 8),
                                      Text(
                                        _beginDate != null ? DateFormat('yyyy-MM-dd').format(_beginDate!) : 'Begin Date',
                                        style: TextStyle(color: AppColors.gold),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: GestureDetector(
                                onTap: () async {
                                  final picked = await showDatePicker(
                                    context: context,
                                    initialDate: DateTime.now(),
                                    firstDate: DateTime.now(),
                                    lastDate: DateTime.now().add(const Duration(days: 730)),
                                  );
                                  if (picked != null) setState(() => _expirationDate = picked);
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                                  decoration: BoxDecoration(
                                    color: Colors.white12,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(Icons.timer_off, color: AppColors.gold),
                                      const SizedBox(width: 8),
                                      Text(
                                        _expirationDate != null ? DateFormat('yyyy-MM-dd').format(_expirationDate!) : 'Expiration Date',
                                        style: TextStyle(color: AppColors.gold),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),
                      TextFormField(
                        decoration: const InputDecoration(
                          labelText: 'Details',
                          labelStyle: TextStyle(color: AppColors.gold),
                          filled: true,
                          fillColor: Colors.white12,
                          border: OutlineInputBorder(),
                        ),
                        minLines: 2,
                        maxLines: 5,
                        style: const TextStyle(color: Colors.white),
                        onSaved: (val) => _details = val ?? '',
                        validator: (val) => val == null || val.isEmpty ? 'Enter details' : null,
                      ),
                      const SizedBox(height: 18),
                      TextFormField(
                        decoration: const InputDecoration(
                          labelText: 'Telephone Number',
                          labelStyle: TextStyle(color: AppColors.gold),
                          filled: true,
                          fillColor: Colors.white12,
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.phone,
                        style: const TextStyle(color: Colors.white),
                        onSaved: (val) => _telephoneNumber = val ?? '',
                        validator: (val) => val == null || val.isEmpty ? 'Enter telephone number' : null,
                      ),
                      const SizedBox(height: 18),
                      TextFormField(
                        decoration: const InputDecoration(
                          labelText: 'Terms and Conditions',
                          labelStyle: TextStyle(color: AppColors.gold),
                          filled: true,
                          fillColor: Colors.white12,
                          border: OutlineInputBorder(),
                        ),
                        minLines: 2,
                        maxLines: 5,
                        style: const TextStyle(color: Colors.white70, fontSize: 13),
                        onSaved: (val) => _terms = val ?? '',
                        validator: (val) => val == null || val.isEmpty ? 'Enter terms and conditions' : null,
                      ),
                      const SizedBox(height: 18),
                      Text(
                        'Images',
                        style: TextStyle(color: AppColors.gold, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          ..._images.map((img) => ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Image.file(
                                  File(img.path),
                                  width: 80,
                                  height: 80,
                                  fit: BoxFit.cover,
                                ),
                              )),
                          GestureDetector(
                            onTap: _pickImages,
                            child: Container(
                              width: 80,
                              height: 80,
                              decoration: BoxDecoration(
                                color: Colors.white12,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: AppColors.gold, width: 2),
                              ),
                              child: const Icon(Icons.add_a_photo, color: AppColors.gold, size: 32),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 28),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _selectedType != null ? _typeColors[_selectedType!] : AppColors.gold,
                          padding: const EdgeInsets.symmetric(vertical: 18),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          elevation: 10,
                          shadowColor: safeShadowColor.withOpacity(0.4),
                        ),
                        onPressed: _isSubmitting ? null : _submit,
                        child: _isSubmitting
                            ? const CircularProgressIndicator(color: Colors.white)
                            : const Text('Post', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
