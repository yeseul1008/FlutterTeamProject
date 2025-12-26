import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../routePage1.dart';
import '../routePage2.dart';

import '../mainPage.dart';
import '../pages/admin/admin_page.dart';
import '../pages/auth/user_google_login.dart';
import '../pages/auth/user_join.dart';
import '../pages/auth/user_login.dart';
import '../pages/community/follow_list.dart';
import '../pages/community/main_feed.dart';
import '../pages/community/question_add.dart';
import '../pages/community/question_comment.dart';
import '../pages/community/question_feed.dart';
import '../pages/profile/user_diary_calendar.dart';
import '../pages/profile/user_diary_cards.dart';
import '../pages/profile/user_diary_map.dart';
import '../pages/profile/user_profile_edit.dart';
import '../pages/profile/user_public_lookbook.dart';
import '../pages/profile/user_public_wardrobe.dart';
import '../pages/wardrobe/outfit_maker.dart';
import '../pages/wardrobe/user_lookbook.dart';
import '../pages/wardrobe/user_lookbook_add.dart';
import '../pages/wardrobe/user_scrap.dart';
import '../pages/wardrobe/user_scrap_view.dart';
import '../pages/wardrobe/user_wardrobe_add.dart';
import '../pages/wardrobe/user_wardrobe_category.dart';
import '../pages/wardrobe/user_wardrobe_list.dart';

import '../widgets/common/bottom_nav_bar.dart';

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
      routes: [
        // 밑에 GoRoute 2개는 샘플임. 페이지 이동할때 방식만 참고하세요
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
        // 메인(mainPage.dart) 페이지!!!! 앱 첫 실행시 이 페이지가 뜸!! (나중에 옷장이 메인페이지가 되도록 바꿀것임. 지금은 ㄴㄴ)
        GoRoute(
          path: '/',
          builder: (context, state) => const RootPage(),
        ),
        // auth 폴더 속 파일 이동
        // GoRoute(
        //   path: '/findIdPwd',
        //   builder: (context, state) => const FindIdPwd(),
        // ),
        GoRoute(
          path: '/googleLogin',
          builder: (context, state) => const GoogleLogin(),
        ),
        // GoRoute(
        //   path: '/userJoin',
        //   builder: (context, state) => const UserJoin(),
        // ),
        // GoRoute(
        //   path: '/userLogin',
        //   builder: (context, state) => const UserLogin(),
        // ),
        // community 폴더 속 파일 이동
        GoRoute(
          path: '/followList',
          builder: (context, state) => const FollowList(),
        ),
        GoRoute(
          path: '/communityMainFeed',
          builder: (context, state) => const CommunityMainFeed(),
        ),
        GoRoute(
          path: '/questionAdd',
          builder: (context, state) => const QuestionAdd(),
        ),
        GoRoute(
          path: '/questionComment',
          builder: (context, state) => const QuestionComment(),
        ),
        GoRoute(
          path: '/questionFeed',
          builder: (context, state) => const QuestionFeed(),
        ),

        // profile 폴더 속 파일이름
        GoRoute(
          path: '/calendarPage',
          builder: (context, state) => const CalendarPage(),
        ),
        GoRoute(
          path: '/userDiaryCards',
          builder: (context, state) => const UserDiaryCards(),
        ),
        GoRoute(
          path: '/diaryMap',
          builder: (context, state) => const DiaryMap(),
        ),
        GoRoute(
          path: '/profileEdit',
          builder: (context, state) => const ProfileEdit(),
        ),
        GoRoute(
          path: '/publicLookBook',
          builder: (context, state) => const PublicLookBook(),
        ),
        GoRoute(
          path: '/publicWardrobe',
          builder: (context, state) => const PublicWardrobe(),
        ),

        // wardrobe 폴더 속 파일 이동
        GoRoute(
          path: '/aiOutfitMaker',
          builder: (context, state) => const AiOutfitMaker(),
        ),
        GoRoute(
          path: '/userLookbook',
          builder: (context, state) => const UserLookbook(),
        ),
        GoRoute(
          path: '/userLookbookAdd',
          builder: (context, state) => const UserLookbookAdd(),
        ),
        GoRoute(
          path: '/userScrap',
          builder: (context, state) => const UserScrap(),
        ),
        GoRoute(
          path: '/userScrapView',
          builder: (context, state) => const UserScrapView(),
        ),
        GoRoute(
          path: '/userWardrobeAdd',
          builder: (context, state) => const UserWardrobeAdd(),
        ),
        GoRoute(
          path: '/userWardrobeCategory',
          builder: (context, state) => const UserWardrobeCategory(),
        ),
        GoRoute(
          path: '/userWardrobeList',
          builder: (context, state) => const UserWardrobeList(),
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
    final GoRouterState state = GoRouterState.of(context);
    // 네비게이션 바를 제외할 페이지가 있다면 아래 코드처럼 사용하면됩니다
    // 만약 page1에도 네비게이션 바를 없애고싶으면
    // || state.uri.path.startsWith('/page1') 이 코드를 추가하면 됨
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