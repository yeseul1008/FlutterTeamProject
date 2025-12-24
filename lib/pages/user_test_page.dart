import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import '../firebase/firebase_options.dart';
import '../firebase/firestore_service.dart';

///  테스트용 main 함수
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const UserTestApp());
}

/// 테스트용 앱 껍데기
class UserTestApp extends StatelessWidget {
  const UserTestApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: UserTestPage(),
    );
  }
}

/// 실제 테스트 페이지
class UserTestPage extends StatefulWidget {
  const UserTestPage({super.key});

  @override
  State<UserTestPage> createState() => _UserTestPageState();
}

class _UserTestPageState extends State<UserTestPage> {
  final _service = FirestoreService();

  final _userIdCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();

  bool _loading = false;

  @override
  void dispose() {
    _userIdCtrl.dispose();
    _emailCtrl.dispose();
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_userIdCtrl.text.isEmpty ||
        _emailCtrl.text.isEmpty ||
        _nameCtrl.text.isEmpty ||
        _phoneCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('모든 값을 입력해주세요')),
      );
      return;
    }

    setState(() => _loading = true);
    try {
      await _service.createUser(
        userId: _userIdCtrl.text.trim(),
        email: _emailCtrl.text.trim(),
        name: _nameCtrl.text.trim(),
        phone: _phoneCtrl.text.trim(),
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ Firestore 저장 성공')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ 저장 실패: $e')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  InputDecoration _dec(String label) => InputDecoration(
    labelText: label,
    border: const OutlineInputBorder(),
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('User 컬렉션 테스트')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(controller: _userIdCtrl, decoration: _dec('userId (문서 ID)')),
            const SizedBox(height: 12),
            TextField(controller: _emailCtrl, decoration: _dec('email')),
            const SizedBox(height: 12),
            TextField(controller: _nameCtrl, decoration: _dec('name')),
            const SizedBox(height: 12),
            TextField(controller: _phoneCtrl, decoration: _dec('phone')),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _loading ? null : _save,
                child: _loading
                    ? const CircularProgressIndicator()
                    : const Text('Firestore에 저장'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
