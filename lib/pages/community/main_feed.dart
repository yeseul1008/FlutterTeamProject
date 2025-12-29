import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart'; // 🔧

class CommunityMainFeed extends StatefulWidget {
  const CommunityMainFeed({super.key});

  @override
  State<CommunityMainFeed> createState() => _CommunityMainFeedState();
}

class _CommunityMainFeedState extends State<CommunityMainFeed> {
  final FirebaseFirestore fs = FirebaseFirestore.instance;
  final FirebaseAuth auth = FirebaseAuth.instance; // 🔧

  // 🔧 하드코딩 제거 → 리스트
  List<Map<String, dynamic>> qnaPosts = [];
  List<String> postIds = [];

  bool isLoading = true;
  String errorMessage = '';

  String selectedPostId = '';
  bool isLiked = false;
  int likeCount = 0;
  List<String> likedUserNicknames = [];

  // 🔧 Firestore 리스트 로딩
  Future<void> _getQnaPosts() async {
    try {
      final snapshot = await fs
          .collection('qna_posts')
          .orderBy('createdAt', descending: true)
          .get();

      setState(() {
        qnaPosts = snapshot.docs.map((e) => e.data()).toList();
        postIds = snapshot.docs.map((e) => e.id).toList();
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        errorMessage = '게시글을 불러올 수 없습니다';
        isLoading = false;
      });
    }
  }

  // 🔧 좋아요 (현재 로그인 유저 기준)
  Future<void> _toggleLike() async {
    final user = auth.currentUser;
    if (user == null || selectedPostId.isEmpty) return;

    final ref = fs.collection('qna_posts').doc(selectedPostId);

    await fs.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists) return;

      final data = snap.data()!;
      List likedUsers = List.from(data['likedUsers'] ?? []);
      int count = data['likeCount'] ?? 0;

      final index =
      likedUsers.indexWhere((u) => u['userId'] == user.uid);

      if (index >= 0) {
        likedUsers.removeAt(index);
        count--;
      } else {
        likedUsers.add({
          'userId': user.uid,
          'nickname': user.displayName ?? 'unknown',
        });
        count++;
      }

      tx.update(ref, {
        'likedUsers': likedUsers,
        'likeCount': count,
      });
    });

    _getQnaPosts();
  }

  @override
  void initState() {
    super.initState();
    _getQnaPosts();
  }

  @override
  Widget build(BuildContext context) {
    final currentPath = GoRouterState.of(context).uri.path;

    return SafeArea(
      child: Column(
        children: [
          /// ===== 상단 UI (절대 수정 없음) =====
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
                  onTap: () => context.go('/followList'),
                ),
              ],
            ),
          ),

          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
              padding:
              const EdgeInsets.fromLTRB(16, 0, 16, 100),
              itemCount: qnaPosts.length,
              itemBuilder: (context, index) {
                final post = qnaPosts[index];
                final likedUsers = post['likedUsers'] ?? [];
                final user = auth.currentUser;

                isLiked = user != null &&
                    likedUsers.any((u) => u['userId'] == user.uid);
                likeCount = post['likeCount'] ?? 0;

                return GestureDetector(
                  onTap: () {
                    selectedPostId = postIds[index];
                    likedUserNicknames = likedUsers
                        .map<String>((u) => u['nickname'])
                        .toList();
                  },
                  child: _qnaItem(
                    nickname: post['nickname'],
                    authorId: post['authorId'],
                    imageUrl: post['imageUrl'],
                    commentCount: post['commentCount'] ?? 0,
                    content: post['content'] ?? '',
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  /// ===== 이하 UI 코드 전부 기존 그대로 =====

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
            backgroundColor:
            active ? const Color(0xFFCAD83B) : Colors.white,
            foregroundColor: Colors.black,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(30),
              side: const BorderSide(color: Colors.black),
            ),
          ),
          child: Text(
            text,
            style:
            const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
        ),
      ),
    );
  }

  Widget _qnaItem({
    required String nickname,
    required String authorId,
    required String imageUrl,
    required int commentCount,
    required String content,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ListTile(
            leading: const CircleAvatar(child: Icon(Icons.person)),
            title: Text(nickname,
                style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text('@$authorId'),
            trailing:
            IconButton(icon: const Icon(Icons.more_horiz), onPressed: () {}),
          ),
          if (content.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(content),
            ),
          const SizedBox(height: 12),
          Container(
            height: 280,
            margin: const EdgeInsets.symmetric(horizontal: 16),
            child: Image.network(
              imageUrl,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) =>
              const Icon(Icons.image_not_supported),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                InkWell(
                  onTap: _toggleLike,
                  child: Icon(
                    isLiked ? Icons.favorite : Icons.favorite_border,
                    color: isLiked ? Colors.red : Colors.grey,
                  ),
                ),
                const SizedBox(width: 6),
                Text(likeCount.toString()),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
