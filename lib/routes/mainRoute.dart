import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../routePage1.dart';
import '../routePage2.dart';
import '../mainPage.dart';
import '../pages/profile/user_diary_calendar.dart';
import '../pages/profile/user_diary_cards.dart';
import '../pages/wardrobe/user_wardrobe_list.dart';
import '../pages/community/main_feed.dart';
import '../widgets/common/bottom_nav_bar.dart';

// ❗ main() 절대 두지 않는다!
// ❗ MyApp도 여기 두지 않는다
final GlobalKey<NavigatorState> _shellNavigatorKey =
GlobalKey<NavigatorState>();
final GoRouter router = GoRouter(
  initialLocation: '/', // ⭐ 명시 (중요)
  routes: [
    ShellRoute(
      navigatorKey: _shellNavigatorKey,
      builder: (context, state, child) {
        return RootLayout(child: child);
      },
      routes: [ // 페이지 추가할때마다 여기에 추가해야됨
        GoRoute(
          path: '/',
          builder: (context, state) => const RootPage(),
        ),
        GoRoute(
          path: '/page1',
          builder: (context, state) => const Page1(),
        ),
        GoRoute(
          path: '/page2',
          builder: (context, state) {
            final name =
                state.uri.queryParameters['name'] ?? '이름 없음';
            final age =
                state.uri.queryParameters['age'] ?? '나이 없음';
            return Page2(name: name, age: age);
          },
        ),
        GoRoute(
          path: '/closet',
          builder: (context, state) => const userWardrobeList(),
        ),
        GoRoute(
          path: '/calendar',
          builder: (context, state) => const CalendarPage(),
        ),
        GoRoute(
          path: '/diary',
          builder: (context, state) => const userDiaryCards(),
        ),
        GoRoute(
          path: '/community',
          builder: (context, state) => const communityFeed(),
        ),
      ],
    ),
  ],
);

class RootLayout extends StatelessWidget {
  final Widget child;

  const RootLayout({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final GoRouterState state = GoRouterState.of(context); // 네비 바 제외할거페이지는 이곳에 추가
    bool hideBottom = false;
    if(
    state.uri.path.startsWith('/page2')
    // || state.uri.path.startsWith('/page1')

    ){
      hideBottom = true;
    }
    /////////////////
    bool hideAppBar = false;

    if(
    state.uri.path.startsWith('/page1')
    // || state.uri.path.startsWith('/page2')

    ){
      hideAppBar = true;
    }

    return Scaffold(
      appBar: AppBar(
        // title: hideAppBar ? null : const Text('My App'),
      ),
      bottomNavigationBar: hideBottom ? null : const BottomNavBar(),
      body: child,
    );
  }
}