import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../../../../core/providers/app_auth_provider.dart';
import '../../../../core/constants/colors.dart';
import '../screens/floor_manager_chat_list_screen.dart';

class MessageIconWidget extends StatefulWidget {
  final VoidCallback? onPressed;
  
  const MessageIconWidget({Key? key, this.onPressed}) : super(key: key);

  @override
  State<MessageIconWidget> createState() => _MessageIconWidgetState();
}

class _MessageIconWidgetState extends State<MessageIconWidget> {
  int _unreadMessageCount = 0;
  String _floorManagerId = '';

  @override
  void initState() {
    super.initState();
    _setupMessageListener();
  }

  void _setupMessageListener() {
    final user = Provider.of<AppAuthProvider>(context, listen: false).appUser;
    if (user != null) {
      setState(() {
        _floorManagerId = user.uid;
      });

      // Listen for unread messages sent directly to this floor manager
      FirebaseFirestore.instance
          .collection('chat_messages')
          .where('recipientId', isEqualTo: _floorManagerId)
          .where('isRead', isEqualTo: false)
          .snapshots()
          .listen((snapshot) {
        if (mounted) {
          _updateUnreadCount();
        }
      });
      
      // Also listen for messages where recipientId is the generic 'floor_manager'
      FirebaseFirestore.instance
          .collection('chat_messages')
          .where('recipientId', isEqualTo: 'floor_manager')
          .where('isRead', isEqualTo: false)
          .snapshots()
          .listen((snapshot) {
        if (mounted) {
          _updateUnreadCount();
        }
      });
    }
  }
  
  // Calculate total unread count from both queries
  Future<void> _updateUnreadCount() async {
    if (_floorManagerId.isEmpty) return;
    
    // Count direct messages
    final directMessages = await FirebaseFirestore.instance
        .collection('chat_messages')
        .where('recipientId', isEqualTo: _floorManagerId)
        .where('isRead', isEqualTo: false)
        .get();
        
    // Count generic floor manager messages
    final genericMessages = await FirebaseFirestore.instance
        .collection('chat_messages')
        .where('recipientId', isEqualTo: 'floor_manager')
        .where('isRead', isEqualTo: false)
        .get();
    
    if (mounted) {
      setState(() {
        _unreadMessageCount = directMessages.docs.length + genericMessages.docs.length;
        print('DEBUG: Updated unread message count: $_unreadMessageCount');
      });
    }
  }

  void _showMessagesDialog(BuildContext context) {
    if (widget.onPressed != null) {
      widget.onPressed!();
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => FloorManagerChatListScreen(),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        IconButton(
          icon: Icon(Icons.message),
          tooltip: 'Messages',
          onPressed: () {
            _showMessagesDialog(context);
          },
        ),
        if (_unreadMessageCount > 0)
          Positioned(
            right: 5,
            top: 5,
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.circular(10),
              ),
              constraints: const BoxConstraints(
                minWidth: 14,
                minHeight: 14,
              ),
              child: Text(
                _unreadMessageCount.toString(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 8,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
      ],
    );
  }
}
