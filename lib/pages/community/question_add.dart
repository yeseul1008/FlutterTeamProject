import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class QuestionAdd extends StatelessWidget {
  const QuestionAdd({super.key});

  @override
  Widget build(BuildContext context) {
    final String currentPath =
        GoRouterState.of(context).uri.path;

    return SafeArea(
      child: Column(
        children: [
          /// ===== 상단 UI (기존 그대로) =====
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
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
                Expanded(
                  child: SizedBox(
                    height: 50,
                    child: ElevatedButton(
                      onPressed: () =>
                          context.go('/followList'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                        currentPath == '/followList'
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

          /// ===== Body (여기부터 새 UI) =====
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  /// ✅ 닫기 버튼
                  Align(
                    alignment: Alignment.centerRight,
                    child: IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => context.pop(),
                    ),
                  ),

                  const SizedBox(height: 8),

                  /// ✅ 타이틀
                  const Center(
                    child: Text(
                      'ASK A QUESTION',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  /// 질문 입력 박스
                  Container(
                    height: 120,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.black),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const TextField(
                      maxLines: null,
                      expands: true,
                      decoration: InputDecoration(
                        hintText: 'Write your question...',
                        border: InputBorder.none,
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  /// 이미지 추가 박스
                  Column(
                    children: [
                      Container(
                        width: 160,
                        height: 160,
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.black),
                        ),
                        child: const Center(
                          child: Icon(
                            Icons.add,
                            size: 48,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'add an image',
                        style: TextStyle(fontSize: 12),
                      ),
                    ],
                  ),

                  const Spacer(),

                  /// Post 버튼
                  SizedBox(
                    height: 50,
                    child: ElevatedButton(
                      onPressed: () {
                        /// TODO: Firestore 저장 로직
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFCAD83B),
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                      ),
                      child: const Text(
                        'post',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
