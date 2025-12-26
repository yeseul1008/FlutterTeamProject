import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class FollowList extends StatelessWidget {
  const FollowList({super.key});

  @override
  Widget build(BuildContext context) {
    final String currentPath =
        GoRouterState.of(context).uri.path;

    return SafeArea(
      child: Column(
        children: [
          /// ===== 상단 UI =====
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                /// ===== Feed =====
                Expanded(
                  child: SizedBox(
                    height: 50,
                    child: ElevatedButton(
                      onPressed: () =>
                          context.go('/communityMainFeed'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                        currentPath == '/communityMainFeed'
                            ? const Color(0xFFCAD83B)
                            : Colors.white,
                        foregroundColor: Colors.black,
                        elevation: 0,
                        padding: EdgeInsets.zero,
                        shape: RoundedRectangleBorder(
                          borderRadius:
                          BorderRadius.circular(30),
                          side: const BorderSide(
                              color: Colors.black),
                        ),
                      ),
                      child: const Text(
                        'Feed',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 20,
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(width: 8),

                /// ===== QnA =====
                Expanded(
                  child: SizedBox(
                    height: 50,
                    child: ElevatedButton(
                      onPressed: () =>
                          context.go('/questionFeed'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                        currentPath == '/questionFeed'
                            ? const Color(0xFFCAD83B)
                            : Colors.white,
                        foregroundColor: Colors.black,
                        elevation: 0,
                        padding: EdgeInsets.zero,
                        shape: RoundedRectangleBorder(
                          borderRadius:
                          BorderRadius.circular(30),
                          side: const BorderSide(
                              color: Colors.black),
                        ),
                      ),
                      child: const Text(
                        'QnA',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(width: 8),

                /// ===== Follow (현재 페이지) =====
                Expanded(
                  child: SizedBox(
                    height: 50,
                    child: ElevatedButton(
                      onPressed: () =>
                          context.go('/followList'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                        currentPath == '/followList'
                            ? const Color(0xFFCAD83B) // 활성화
                            : Colors.white,
                        foregroundColor: Colors.black,
                        elevation: 0,
                        padding: EdgeInsets.zero,
                        shape: RoundedRectangleBorder(
                          borderRadius:
                          BorderRadius.circular(30),
                          side: const BorderSide(
                              color: Colors.black),
                        ),
                      ),
                      child: const Text(
                        'Follow',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 20,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          /// ===== Follow 내용 =====
          const Expanded(
            child: Center(
              child: Text('Follow 페이지'),
            ),
          ),
        ],
      ),
    );
  }
}
