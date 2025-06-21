import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:vip_lounge/features/marketing_agent/models/social_feed_post_model.dart';
import 'package:vip_lounge/core/constants/colors.dart';
import 'package:provider/provider.dart';
import 'package:vip_lounge/core/providers/app_auth_provider.dart';

class MarketingTabSocialFeed extends StatelessWidget {
  const MarketingTabSocialFeed({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.black,
      appBar: AppBar(
        backgroundColor: AppColors.black,
        foregroundColor: Colors.blue,
        title: Text(
          'VIP DEALS',
          style: const TextStyle(
            color: AppColors.richGold,
            fontWeight: FontWeight.bold,
            decoration: TextDecoration.underline,
            fontSize: 20,
          ),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('marketing_posts')
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: AppColors.gold));
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('No posts yet.', style: TextStyle(color: Colors.white70)));
          }
          final posts = snapshot.data!.docs
              .map((doc) => SocialFeedPostModel.fromMap(doc.data() as Map<String, dynamic>))
              .toList();
          return ListView.builder(
            itemCount: posts.length,
            itemBuilder: (context, i) => _SocialFeedPostCard(post: posts[i]),
          );
        },
      ),
    );
  }
}

class _SocialFeedPostCard extends StatelessWidget {
  final SocialFeedPostModel post;
  static final Map<String, Color> _typeColors = {
    'Specials': Color(0xFF00C9A7),
    'Data Bundle Special': Color(0xFF1E90FF),
    'Device Specials': Color(0xFFFFA500),
    'Upgrade Specials': Color(0xFF8A2BE2),
    'New Contract Specials': Color(0xFF43A047),
    'Accessories Specials': Color(0xFFFB3C62),
  };
  const _SocialFeedPostCard({required this.post});

  @override
  Widget build(BuildContext context) {
    final Color typeColor = _typeColors[post.type] ?? AppColors.gold;
    final user = FirebaseAuth.instance.currentUser;
    final ministerData = Provider.of<AppAuthProvider>(context, listen: false).ministerData;
    final String ministerName = ministerData != null ? (ministerData['fullName'] ?? 'Minister') : (user?.displayName ?? 'Anonymous');
    final bool isExpired = DateTime.now().isAfter(post.expirationDate);
    return Card(
      elevation: 14,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: const BorderSide(color: AppColors.gold, width: 2),
      ),
      color: AppColors.black.withOpacity(0.97),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            decoration: BoxDecoration(
              color: typeColor.withOpacity(0.11),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
              border: Border.all(color: typeColor, width: 2),
              boxShadow: [
                BoxShadow(
                  color: typeColor.withOpacity(0.18),
                  blurRadius: 18,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
            child: Row(
              children: [
                Icon(Icons.campaign, color: typeColor, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    post.type,
                    style: TextStyle(
                      color: typeColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ),
                Text(
                  DateFormat('MMM d, yyyy').format(post.beginDate),
                  style: const TextStyle(color: Colors.white60, fontSize: 13),
                ),
              ],
            ),
          ),
          if (post.imageUrls.isNotEmpty)
            SizedBox(
              height: 220,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: post.imageUrls.map((url) => Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Image.network(url, width: 220, height: 220, fit: BoxFit.cover),
                )).toList(),
              ),
            ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(post.details, style: const TextStyle(color: Colors.white, fontSize: 16)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.phone, color: AppColors.gold, size: 20),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () async {
                        final uri = Uri(scheme: 'tel', path: post.telephoneNumber);
                        if (await canLaunchUrl(uri)) {
                          launchUrl(uri);
                        }
                      },
                      child: Text(
                        post.telephoneNumber,
                        style: const TextStyle(
                          color: AppColors.gold,
                          decoration: TextDecoration.underline,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const Spacer(),
                    Icon(Icons.timer_off, color: Colors.white54, size: 18),
                    const SizedBox(width: 4),
                    Text(
                      'Ends: ' + DateFormat('MMM d').format(post.expirationDate),
                      style: const TextStyle(color: Colors.white54, fontSize: 12),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                if (post.termsAndConditions.isNotEmpty)
                  Text('Terms: ${post.termsAndConditions}', style: const TextStyle(color: Colors.white38, fontSize: 12)),
                const SizedBox(height: 10),
                if (user != null)
                  _LikeButton(postId: post.id, userId: user.uid, typeColor: typeColor),
                if (isExpired) ...[
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Icon(Icons.timer_off, color: Colors.white54, size: 18),
                      const SizedBox(width: 4),
                      Text(
                        'Ends: ' + DateFormat('MMM d').format(post.expirationDate),
                        style: const TextStyle(color: Colors.white54, fontSize: 12),
                      ),
                    ],
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 8, bottom: 2),
                    child: Row(
                      children: [
                        Icon(Icons.error_outline, color: Colors.red, size: 18),
                        const SizedBox(width: 8),
                        Text(
                          'EXPIRED',
                          style: const TextStyle(
                            color: Colors.red,
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          // TODO: Add comments UI here
        ],
      ),
    );
  }
}

class _LikeButton extends StatelessWidget {
  final String postId;
  final String userId;
  final Color typeColor;
  const _LikeButton({required this.postId, required this.userId, required this.typeColor});

  @override
  Widget build(BuildContext context) {
    final likesRef = FirebaseFirestore.instance.collection('marketing_posts').doc(postId).collection('likes');
    return StreamBuilder<QuerySnapshot>(
      stream: likesRef.snapshots(),
      builder: (context, snapshot) {
        final docs = snapshot.data?.docs ?? [];
        final likeCount = docs.length;
        final isLiked = docs.any((doc) => doc.id == userId);
        return Row(
          children: [
            IconButton(
              icon: AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                transitionBuilder: (child, anim) => ScaleTransition(scale: anim, child: child),
                child: Icon(
                  isLiked ? Icons.favorite : Icons.favorite_border,
                  key: ValueKey(isLiked),
                  color: isLiked ? typeColor : Colors.white38,
                  size: 28,
                ),
              ),
              onPressed: () {
                if (isLiked) {
                  likesRef.doc(userId).delete();
                } else {
                  likesRef.doc(userId).set({'likedAt': FieldValue.serverTimestamp()});
                }
              },
              tooltip: isLiked ? 'Unlike' : 'Like',
            ),
            Text('$likeCount', style: TextStyle(color: typeColor, fontWeight: FontWeight.bold)),
            const SizedBox(width: 6),
            Text('Like${likeCount == 1 ? '' : 's'}', style: const TextStyle(color: Colors.white54)),
          ],
        );
      },
    );
  }
}
