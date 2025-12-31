import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'routes/mainRoute.dart'; // ⬅️ router 가져오기
import 'pages/wardrobe/user_wardrobe_list.dart';
import 'firebase/firebase_options.dart';
import 'package:kakao_flutter_sdk_share/kakao_flutter_sdk_share.dart'; // kakao api 공유


void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // .env 로드 (파일이 루트에 있고 pubspec.yaml assets에 등록돼 있어야 함)
  await dotenv.load(fileName: ".env");

  // Firebase 초기화 (반드시 runApp 전에)
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // ⭐ Kakao SDK 초기화
  KakaoSdk.init(
    nativeAppKey: 'd965237ababfd11fc09f8f3314a782cc',
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      routerConfig: router,
    );
  }
}
