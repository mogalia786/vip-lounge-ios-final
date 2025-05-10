import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// A bell icon with an unread notification badge for the bottom nav bar.
/// Usage: Place in your BottomNavigationBarItem or as a widget in your nav bar.
class NotificationBellBadge extends StatelessWidget {
  final String userId;
  final double iconSize;
  final Color? iconColor;
  final Color? badgeColor;
  final Color? badgeTextColor;

  const NotificationBellBadge({
    Key? key,
    required this.userId,
    this.iconSize = 28,
    this.iconColor,
    this.badgeColor = Colors.red,
    this.badgeTextColor = Colors.white,
  }) : super(key: key);

  Stream<int> _unreadCountStream(String userId) {
    return FirebaseFirestore.instance
        .collection('notifications')
        .where('assignedToId', isEqualTo: userId)
        .where('isRead', isEqualTo: false)
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<int>(
      stream: _unreadCountStream(userId),
      builder: (context, snapshot) {
        int unreadCount = snapshot.data ?? 0;
        return Stack(
          clipBehavior: Clip.none,
          children: [
            Icon(
              Icons.notifications,
              size: iconSize,
              color: iconColor ?? Colors.white,
            ),
            if (unreadCount > 0)
              Positioned(
                right: -2,
                top: -2,
                child: Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: badgeColor,
                    shape: BoxShape.circle,
                  ),
                  constraints: const BoxConstraints(
                    minWidth: 18,
                    minHeight: 18,
                  ),
                  child: Text(
                    unreadCount > 99 ? '99+' : unreadCount.toString(),
                    style: TextStyle(
                      color: badgeTextColor,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
