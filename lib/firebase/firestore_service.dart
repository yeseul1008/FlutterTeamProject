import 'package:cloud_firestore/cloud_firestore.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  //user컬렉션
  Future<void> createUser({
    required String userId,
    required String email,
    required String name,
    required String phone,
  }){
    return _db.collection('users').doc(userId).set({ //set인경우는 지정한 문서ID, add인 경우는 자동생성이에요.
      'email' : email,
      'name' : name,
      'phone' : phone,
      'createdAt' : FieldValue.serverTimestamp(),
    });
  }

  // users 컬렉션 (자동 문서 ID 사용)
  Future<String> createUsers({
  required String email,
  required String name,
  required String phone,
  }) async {
  final docRef = await _db.collection('users').add({
  'email': email,
  'name': name,
  'phone': phone,
  'createdAt': FieldValue.serverTimestamp(),
  });

  // 자동 생성된 문서 ID를 userId로 반환
  return docRef.id;
  }
}




