import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class FollowList extends StatefulWidget {
  const FollowList({super.key});

  @override
  State<FollowList> createState() => _FollowListState();
}

class _FollowListState extends State<FollowList> {
  final FirebaseFirestore fs = FirebaseFirestore.instance;

  final String userId = 'xfGlQhS2KxVCZwihVTKQpruR2CX2';

  List<String> followers = [];
  List<String> following = [];

  bool isLoading = true;


  /// Follow 데이터 불러오기
  Future<void> _loadFollowData() async {
    try {
      final followersSnap = await fs
          .collection('follows')
          .doc(userId)
          .collection('followers')
          .get();

      final followingSnap = await fs
          .collection('follows')
          .doc(userId)
          .collection('following')
          .get();

      setState(() {
        followers = followersSnap.docs.map((e) => e.id).toList();
        following = followingSnap.docs.map((e) => e.id).toList();
        isLoading = false;
      });
    } catch (e) {
      debugPrint('Follow load error: $e');
      setState(() => isLoading = false);
    }
  }

  @override
  void initState() {
    super.initState();
    _loadFollowData();
  }

  @override
  Widget build(BuildContext context) {
    final String currentPath = GoRouterState.of(context).uri.path;

    return SafeArea(
      child: Column(
        children: [
          /// ===== 상단 UI (변경 없음) =====
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

          /// ===== Follow 리스트 =====
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _sectionTitle('Followers'),
                ...followers.map(
                      (id) => _userTile(id),
                ),

                const SizedBox(height: 24),

                _sectionTitle('Following'),
                ...following.map(
                      (id) => _userTile(id),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// ===== 상단 버튼 =====
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
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
        ),
      ),
    );
  }

  ///  섹션 타이틀
  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  /// 유저 리스트 타일
  Widget _userTile(String userId) {
    return ListTile(
      leading: const CircleAvatar(child: Icon(Icons.person)),
      title: Text(userId),
    );
  }
}
