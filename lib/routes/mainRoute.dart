import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:team_project_flutter/pages/community/question_closet.dart';
import 'package:team_project_flutter/pages/community/question_closet_result.dart';
import 'package:team_project_flutter/pages/schedule/schedule_add_Lookbook.dart';
import 'package:team_project_flutter/pages/schedule/schedule_lookbook.dart';
import 'package:team_project_flutter/pages/wardrobe/user_wardrobe_edit.dart';

// import '../pages/profile/user_schedule_edit.dart';
import '../routePage1.dart';
import '../routePage2.dart';

import '../mainPage.dart';
import '../pages/admin/admin_page.dart';
import '../pages/auth/user_google_login.dart';
import '../pages/auth/user_join.dart';
import '../pages/auth/user_login.dart';
import '../pages/auth/SplashScreen.dart';
import '../pages/auth/find_id.dart';
import '../pages/auth/find_pwd.dart';
import '../pages/community/follow_list.dart';
import '../pages/community/main_feed.dart';
import '../pages/community/question_add.dart';
import '../pages/community/question_comment.dart';
import '../pages/community/question_feed.dart';
import '../pages/profile/user_diary_calendar.dart';
import '../pages/profile/user_diary_cards.dart';
import '../pages/schedule/schedule_calendar.dart';
import '../pages/profile/user_diary_map.dart';
import '../pages/profile/user_profile_edit.dart';
import '../pages/profile/user_public_lookbook.dart';
import '../pages/profile/user_public_wardrobe.dart';
import '../pages/profile/user_diary_add.dart';
import '../pages/wardrobe/outfit_maker.dart';
import '../pages/wardrobe/user_lookbook.dart';
import '../pages/wardrobe/user_lookbook_add.dart';
import '../pages/wardrobe/user_scrap.dart';
import '../pages/wardrobe/user_lookbook_create.dart';
import '../pages/wardrobe/user_scrap_view.dart';
import '../pages/wardrobe/user_wardrobe_add.dart';
import '../pages/wardrobe/outfit_maker_result.dart';
import '../pages/wardrobe/user_wardrobe_list.dart';
import '../pages/wardrobe/user_wardrobe_detail.dart';
import '../widgets/common/bottom_nav_bar.dart';
import '../pages/schedule/schedule_add.dart';
import '../pages/map/PlaceSearchPage.dart';
import '../pages/schedule/schedule_wardrobe.dart';
import '../pages/schedule/schedule_combine.dart';
// import '../pages/schedule/schedule_add_Lookbook.dart';

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
        // 메인(mainPage.dart) 페이지!!!! 앱 첫 실행시 이 페이지가 뜸!! (나중에 옷장이 메인페이지가 되도록 바꿀것임. 지금은 ㄴㄴ)
        GoRoute(
          path: '/',
          builder: (context, state) => const SplashScreen(),
        ),
        // auth 폴더 속 파일 이동
        GoRoute(
          path: '/findId',
          builder: (context, state) => const FindId(),
        ),
        GoRoute(
          path: '/findPwd',
          builder: (context, state) => const FindPwd(),
        ),
        GoRoute(
          path: '/googleLogin',
          builder: (context, state) => const GoogleLogin(),
        ),
        GoRoute(
          path: '/userJoin',
          builder: (context, state) => const UserJoin(),
        ),
        GoRoute(
          path: '/userLogin',
          builder: (context, state) => const UserLogin(),
        ),
        // community 폴더 속 파일 이동
        GoRoute(
          path: '/questionCloset',
          builder: (context, state) => const QuestionCloset(),
        ),
        GoRoute(
          path: '/questionClosetResult',
          builder: (context, state) {
            return QuestionClosetResult(extra: state.extra);
          },
        ),
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

        //카카오 지도
        GoRoute(
          path: '/placeSearch',
          builder: (context, state) => const PlaceSearchPage(),
        ),


        //Schedule전용 라우터
        //일정 추가
        GoRoute(
          path: '/AddSchedule',
          builder: (context, state) => const UserScheduleAdd(),
        ),
        //스케줄 옷 리스트 호출
        GoRoute(
          path: '/scheduleWardrobe',
          builder : (context, state) => const ScheduleWardrobe(),
        ),
        //스케줄 룩북
        GoRoute(
            path: '/scheduleLookbook',
            builder: (context, state) => const ScheduleLookbook()
        ),
        //스케줄 옷 조합
        GoRoute(
          path: '/scheduleCombine',
          builder: (context, state) =>
              ScheduleCombine(extra: state.extra),
        ),
        //조합하기에서 룩북에 저장하기
        // GoRoute(
        //     path: '/scheduleAddLookbook',
        //   builder: (context,state) => const ScheduleAddLookbook()
        // ),


        GoRoute(
          path: '/userScheduleCalendar',
          builder: (context, state) => const UserScheduleCalendar(),
        ),
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
        GoRoute(
          path: '/userDiaryAdd',
          builder: (context, state) => const UserDiaryAdd (),
        ),
        // wardrobe 폴더 속 파일 이동
        GoRoute(
          path: '/aiOutfitMaker',
          builder: (context, state) => const AiOutfitMaker(),
        ),
        GoRoute(
          path: '/userLookbook',
          pageBuilder: (context, state) {
            return NoTransitionPage(
              key: state.pageKey, // optional: 페이지 키를 state에서 가져옴
              child: UserLookbook(), // const 제거
            );
          },
        ),
        GoRoute(
          path: '/userLookbookAdd',
          pageBuilder: (context, state) {
            return CustomTransitionPage(
              key: state.pageKey,
              child: const UserLookbookAdd(),
              transitionsBuilder: (context, animation, secondaryAnimation, child) {
                final tween = Tween<Offset>(
                  begin: const Offset(0, 1), // 아래에서 시작
                  end: Offset.zero,
                ).chain(CurveTween(curve: Curves.easeOutCubic));

                return SlideTransition(
                  position: animation.drive(tween),
                  child: child,
                );
              },
            );
          },
        ),
        GoRoute(
          path: '/userScrap',
          pageBuilder: (context, state) {
            return const NoTransitionPage(
              child: UserScrap(),
            );
          },
        ),
        GoRoute(
          path: '/lookbookCombine',
          builder: (context, state) {
            return lookbookCombine(extra: state.extra);
          },
        ),

        GoRoute(
          path: '/userScrapView',
          builder: (context, state) {
            final lookbookId = state.extra as String; // null 아님
            return UserScrapView(lookbookId: lookbookId);
          },
        ),



        GoRoute(
          path: '/userWardrobeDetail',
          pageBuilder: (context, state) {
            final id = state.extra as String; // ❗ null 허용 제거

            return CustomTransitionPage(
              key: state.pageKey,
              child: UserWardrobeDetail(docId: id),
              transitionsBuilder: (context, animation, secondaryAnimation, child) {
                final tween = Tween<Offset>(
                  begin: const Offset(0, 1),
                  end: Offset.zero,
                ).chain(CurveTween(curve: Curves.easeOutCubic));

                return SlideTransition(
                  position: animation.drive(tween),
                  child: child,
                );
              },
            );
          },
        ),

        GoRoute(
          path: '/userWardrobeEdit',
          pageBuilder: (context, state) {
            final id = state.extra as String; // ❗ null 허용 제거

            return CustomTransitionPage(
              key: state.pageKey,
              child: UserWardrobeEdit(docId: id),
              transitionsBuilder: (context, animation, secondaryAnimation, child) {
                final tween = Tween<Offset>(
                  begin: const Offset(0, 1),
                  end: Offset.zero,
                ).chain(CurveTween(curve: Curves.easeOutCubic));

                return SlideTransition(
                  position: animation.drive(tween),
                  child: child,
                );
              },
            );
          },
        ),

        GoRoute(
          path: '/userWardrobeAdd',
          pageBuilder: (context, state) {
            return CustomTransitionPage(
              key: state.pageKey,
              child: const UserWardrobeAdd(),
              transitionsBuilder: (context, animation, secondaryAnimation, child) {
                final tween = Tween<Offset>(
                  begin: const Offset(0, 1), // 아래에서 시작
                  end: Offset.zero,
                ).chain(CurveTween(curve: Curves.easeOutCubic));

                return SlideTransition(
                  position: animation.drive(tween),
                  child: child,
                );
              },
            );
          },
        ),
        GoRoute(
          path: '/userWardrobeList',
          pageBuilder: (context, state) {
            return const NoTransitionPage(
              child: UserWardrobeList(),
            );
          },
        ),
        GoRoute(
          path: '/aiOutfitMakerScreen',
          builder: (context, state) {
            // state.extra를 List<String>으로 형변환
            final List<String>? extra = state.extra as List<String>?;

            if (extra != null) {
              return AiOutfitMakerScreen(selectedImageUrls: extra);
            } else {
              return const Scaffold(
                body: Center(child: Text('선택된 옷이 없습니다.')),
              );
            }
          },
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
    || state.uri.path.startsWith('/userLogin')
    || state.uri.path.startsWith('/findId') || state.uri.path.startsWith('/findPwd')
    || state.uri.path.startsWith('/googleLogin') || state.uri.path.startsWith('/userJoin')

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
      // appBar: AppBar(
      //   // title: hideAppBar ? null : const Text('My App'),
      // ),
      extendBody: true,
      bottomNavigationBar: hideBottom ? null : const BottomNavBar(),
      body: child,
    );
  }
}