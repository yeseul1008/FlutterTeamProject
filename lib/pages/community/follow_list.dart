import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FollowList extends StatefulWidget {
  const FollowList({super.key});

  @override
  State<FollowList> createState() => _FollowListState();
}

class _FollowListState extends State<FollowList> with SingleTickerProviderStateMixin {
  final FirebaseFirestore fs = FirebaseFirestore.instance;

  String? userId;
  String? targetUserId; // For viewing other users' follow lists

  List<Map<String, dynamic>> followers = [];
  List<Map<String, dynamic>> following = [];

  bool isLoading = true;

  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    // Get current user ID
    userId = FirebaseAuth.instance.currentUser?.uid;

    _loadFollowData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // Get targetUserId from URL if viewing another user's follows
    final uri = GoRouterState.of(context).uri;
    final queryUserId = uri.queryParameters['userId'];

    if (queryUserId != null && queryUserId != targetUserId) {
      targetUserId = queryUserId;
      _loadFollowData();
    }
  }

  /// Load follow data
  Future<void> _loadFollowData() async {
    if (userId == null) return;

    // Use targetUserId if viewing someone else's follows, otherwise use current user
    final uid = targetUserId ?? userId!;

    try {
      // Get followers with their info
      final followersSnap = await fs
          .collection('users')
          .doc(uid)
          .collection('followers')
          .orderBy('followedAt', descending: true)
          .get();

      // Get following with their info
      final followingSnap = await fs
          .collection('users')
          .doc(uid)
          .collection('following')
          .orderBy('followedAt', descending: true)
          .get();

      setState(() {
        followers = followersSnap.docs.map((doc) {
          final data = doc.data();
          return {
            'userId': data['userId'] ?? doc.id,
            'loginId': data['loginId'] ?? 'Unknown',
            'nickname': data['nickname'] ?? 'Unknown',
            'profileImageUrl': data['profileImageUrl'],
          };
        }).toList();

        following = followingSnap.docs.map((doc) {
          final data = doc.data();
          return {
            'userId': data['userId'] ?? doc.id,
            'loginId': data['loginId'] ?? 'Unknown',
            'nickname': data['nickname'] ?? 'Unknown',
            'profileImageUrl': data['profileImageUrl'],
          };
        }).toList();

        isLoading = false;
      });

      print('Loaded ${followers.length} followers and ${following.length} following');
    } catch (e) {
      debugPrint('Follow load error: $e');
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final String currentPath = GoRouterState.of(context).uri.path;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            /// Top navigation buttons
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  _topButton(
                    text: 'Feed',
                    active: currentPath == '/communityMainFeed',
                    onTap: () => context.go('/communityMainFeed'),
                  ),
                  const SizedBox(width: 8),
                  _topButton(
                    text: 'QnA',
                    active: currentPath == '/questionFeed',
                    onTap: () => context.go('/questionFeed'),
                  ),
                  const SizedBox(width: 8),
                  _topButton(
                    text: 'Follow',
                    active: currentPath == '/followList',
                    onTap: () {},
                  ),
                ],
              ),
            ),

            /// TabBar for Followers/Following
            Container(
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: Colors.grey[300]!, width: 1),
                ),
              ),
              child: TabBar(
                controller: _tabController,
                labelColor: Colors.black,
                unselectedLabelColor: Colors.grey,
                indicatorColor: const Color(0xFFCAD83B),
                indicatorWeight: 3,
                labelStyle: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
                tabs: [
                  Tab(text: 'Followers (${followers.length})'),
                  Tab(text: 'Following (${following.length})'),
                ],
              ),
            ),

            /// TabBarView for sliding content
            Expanded(
              child: isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : TabBarView(
                controller: _tabController,
                children: [
                  // Followers Tab
                  followers.isEmpty
                      ? const Center(
                    child: Text(
                      'No followers yet',
                      style: TextStyle(color: Colors.grey),
                    ),
                  )
                      : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: followers.length,
                    itemBuilder: (context, index) {
                      return _userTile(followers[index]);
                    },
                  ),

                  // Following Tab
                  following.isEmpty
                      ? const Center(
                    child: Text(
                      'Not following anyone yet',
                      style: TextStyle(color: Colors.grey),
                    ),
                  )
                      : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: following.length,
                    itemBuilder: (context, index) {
                      return _userTile(following[index]);
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Top button widget
  Widget _topButton({
    required String text,
    required bool active,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: SizedBox(
        height: 50,
        child: ElevatedButton(
          onPressed: onTap,
          style: ElevatedButton.styleFrom(
            backgroundColor: active ? const Color(0xFFCAD83B) : Colors.white,
            foregroundColor: Colors.black,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(30),
              side: const BorderSide(color: Colors.black),
            ),
          ),
          child: Text(
            text,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
        ),
      ),
    );
  }

  /// User list tile
  Widget _userTile(Map<String, dynamic> user) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey[300]!),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          radius: 25,
          backgroundColor: Colors.grey[300],
          backgroundImage: user['profileImageUrl'] != null
              ? NetworkImage(user['profileImageUrl'])
              : null,
          child: user['profileImageUrl'] == null
              ? const Icon(Icons.person, color: Colors.grey)
              : null,
        ),
        title: Text(
          user['nickname'] ?? 'Unknown',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          '@${user['loginId'] ?? 'unknown'}',
          style: TextStyle(color: Colors.grey[600], fontSize: 14),
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () {
          // Navigate to user's profile
          context.go('/publicLookBook?userId=${user['userId']}');
        },
      ),
    );
  }
}