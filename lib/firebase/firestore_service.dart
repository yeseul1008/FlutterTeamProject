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




}