import 'package:cloud_firestore/cloud_firestore.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // =========================
  // 1) users (Auth UID = userId)
  // =========================
  Future<void> createUser({
    required String userId, // Firebase Auth UID
    required String email,
    required String phone,
    required String provider, // "email" | "google"
    required String nickname,
    required String loginId, // uid와 다른 로그인용 아이디
    String? profileImageUrl,
  }) async {
    // 1️⃣ users/{uid} 문서 생성
    await _db.collection('users').doc(userId).set({
      'userId': userId,
      'loginId': loginId,
      'email': email,
      'phone': phone,
      'provider': provider,
      'nickname': nickname,
      'profileImageUrl': profileImageUrl,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    // 2️⃣ 기본 카테고리 자동 생성 (서브컬렉션 users/{uid}/categories)
    final defaultCategories = [
      'outer',
      'top',
      'bottom',
      'dress',
      'shoes',
      'accessories',
    ];

    for (final name in defaultCategories) {
      await _db
          .collection('users')
          .doc(userId)
          .collection('categories')
          .add({
        'name': name,
        'isDefault': true,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
  }


  Future<void> updateUserProfile({
    required String userId,
    String? phone,
    String? nickname,
    String? profileImageUrl,
  }) {
    final data = <String, dynamic>{
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (phone != null) data['phone'] = phone;
    if (nickname != null) data['nickname'] = nickname;
    if (profileImageUrl != null) data['profileImageUrl'] = profileImageUrl;

    return _db.collection('users').doc(userId).update(data);
  }

  Future<DocumentSnapshot<Map<String, dynamic>>> getUser(String userId) {
    return _db.collection('users').doc(userId).get();
  }

  // =========================
  // 2) categories (default + user custom)
  // - 기본 6개: isDefault=true, ownerId=null
  // - 유저 추가: isDefault=false, ownerId=userId
  // =========================
  Future<String> createCategory({
    required String name,
    required bool isDefault,
    String? ownerId, // 유저 추가면 userId 넣기
  }) async {
    final doc = await _db.collection('categories').add({
      'name': name,
      'isDefault': isDefault,
      'ownerId': ownerId, // default면 null
      'createdAt': FieldValue.serverTimestamp(),
    });
    return doc.id;
  }

  /// 유저가 볼 수 있는 카테고리: (기본) + (내가 만든 것)
  /// 주의: OR 쿼리는 2번 조회 후 합칩니다.
  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>> getCategoriesForUser(
      String userId) async {
    final defaults = await _db
        .collection('categories')
        .where('isDefault', isEqualTo: true)
        .get();

    final customs = await _db
        .collection('categories')
        .where('isDefault', isEqualTo: false)
        .where('ownerId', isEqualTo: userId)
        .get();

    return [...defaults.docs, ...customs.docs];
  }

  Future<void> deleteCategory(String categoryId) {
    return _db.collection('categories').doc(categoryId).delete();
  }

  // =========================
  // 3) wardrobe (top-level, clothesId auto, userId 필드로 소유자 구분)
  // =========================
  Future<String> createClothes({
    required String userId,
    required String imageUrl,
    required String categoryId,
    required List<String> season, // ["spring","summer"]
    String? productName,
    String? shop,
    String? material,
    String? comment,
    bool liked = false,
  }) async {
    final doc = await _db.collection('wardrobe').add({
      'userId': userId,
      'imageUrl': imageUrl,
      'categoryId': categoryId,
      'season': season,
      'productName': productName,
      'shop': shop,
      'material': material,
      'comment': comment,
      'liked': liked,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    return doc.id;
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> watchWardrobe(String userId) {
    return _db
        .collection('wardrobe')
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> watchLikedClothes(String userId) {
    return _db
        .collection('wardrobe')
        .where('userId', isEqualTo: userId)
        .where('liked', isEqualTo: true)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  Future<void> toggleClothesLiked({
    required String clothesId,
    required bool liked,
  }) {
    return _db.collection('wardrobe').doc(clothesId).update({
      'liked': liked,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteClothes(String clothesId) {
    return _db.collection('wardrobe').doc(clothesId).delete();
  }

  // =========================
  // 4) lookbooks (top-level)
  // =========================
  Future<String> createLookbook({
    required String userId,
    required String alias,
    required String resultImageUrl,
    required List<String> clothesIds, // 2개 이상
    required bool publishToCommunity,
  }) async {
    final doc = await _db.collection('lookbooks').add({
      'userId': userId,
      'alias': alias,
      'resultImageUrl': resultImageUrl,
      'clothesIds': clothesIds,
      'publishToCommunity': publishToCommunity,
      'createdAt': FieldValue.serverTimestamp(),
    });
    return doc.id;
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> watchLookbooks(String userId) {
    return _db
        .collection('lookbooks')
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  Future<void> deleteLookbook(String lookbookId) {
    return _db.collection('lookbooks').doc(lookbookId).delete();
  }

  // =========================
  // 5) calendar (top-level)  date(YYYY-MM-DD) + lookbookId
  // =========================
  Future<String> createCalendar({
    required String userId,
    required String date, // "2025-01-10"
    required String lookbookId,
  }) async {
    final doc = await _db.collection('calendar').add({
      'userId': userId,
      'date': date,
      'lookbookId': lookbookId,
      'createdAt': FieldValue.serverTimestamp(),
    });
    return doc.id;
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> watchCalendar(String userId) {
    return _db
        .collection('calendar')
        .where('userId', isEqualTo: userId)
        .orderBy('date', descending: true)
        .snapshots();
  }

  Future<void> deleteCalendar(String calendarId) {
    return _db.collection('calendar').doc(calendarId).delete();
  }

  // =========================
  // 6) diaries (top-level)
  // =========================
  Future<String> createDiary({
    required String userId,
    required String date, // "2025-01-10"
    required String lookbookId,
    required double lat,
    required double lng,
    required String locationText,
    required String weather, // "sunny"
    required String comment,
  }) async {
    final doc = await _db.collection('diaries').add({
      'userId': userId,
      'date': date,
      'lookbookId': lookbookId,
      'location': {'lat': lat, 'lng': lng},
      'locationText': locationText,
      'weather': weather,
      'comment': comment,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    return doc.id;
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> watchDiaries(String userId) {
    return _db
        .collection('diaries')
        .where('userId', isEqualTo: userId)
        .orderBy('date', descending: true)
        .snapshots();
  }

  Future<void> updateDiary({
    required String diaryId,
    String? weather,
    String? comment,
    double? lat,
    double? lng,
    String? locationText,
    String? lookbookId,
  }) {
    final data = <String, dynamic>{
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (weather != null) data['weather'] = weather;
    if (comment != null) data['comment'] = comment;
    if (lookbookId != null) data['lookbookId'] = lookbookId;
    if (locationText != null) data['locationText'] = locationText;
    if (lat != null && lng != null) data['location'] = {'lat': lat, 'lng': lng};

    return _db.collection('diaries').doc(diaryId).update(data);
  }

  Future<void> deleteDiary(String diaryId) {
    return _db.collection('diaries').doc(diaryId).delete();
  }

  // =========================
  // 7) community_feed (top-level)
  // =========================
  Future<String> createCommunityFeed({
    required String lookbookId,
    required String authorId,
    required String authorNickname,
    String? authorProfileImage,
    required String imageUrl,
  }) async {
    final doc = await _db.collection('community_feed').add({
      'lookbookId': lookbookId,
      'authorId': authorId,
      'authorNickname': authorNickname,
      'authorProfileImage': authorProfileImage,
      'imageUrl': imageUrl,
      'scrapCount': 0,
      'createdAt': FieldValue.serverTimestamp(),
    });
    return doc.id;
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> watchCommunityFeed() {
    return _db
        .collection('community_feed')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  Future<void> updateFeedScrapCount({
    required String feedId,
    required int newCount,
  }) {
    return _db.collection('community_feed').doc(feedId).update({
      'scrapCount': newCount,
    });
  }

  // =========================
  // 8) scraps (AI안: scraps/{userId}/items/{feedId})
  // - items는 "목록" 의미의 임의 서브컬렉션 이름입니다.
  // =========================
  Future<void> scrapFeed({
    required String userId,
    required String feedId,
  }) {
    return _db
        .collection('scraps')
        .doc(userId)
        .collection('items')
        .doc(feedId) // feedId로 문서ID 고정 => 중복 스크랩 방지
        .set({
      'feedId': feedId,
      'scrapedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> unscrapFeed({
    required String userId,
    required String feedId,
  }) {
    return _db
        .collection('scraps')
        .doc(userId)
        .collection('items')
        .doc(feedId)
        .delete();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> watchMyScraps(String userId) {
    return _db
        .collection('scraps')
        .doc(userId)
        .collection('items')
        .orderBy('scrapedAt', descending: true)
        .snapshots();
  }

  // =========================
  // 9) qna_posts (top-level)
  // =========================
  Future<String> createQnaPost({
    required String authorId,
    required List<String> images,
    required String comment,
  }) async {
    final doc = await _db.collection('qna_posts').add({
      'authorId': authorId,
      'images': images,
      'comment': comment,
      'commentCount': 0,
      'createdAt': FieldValue.serverTimestamp(),
    });
    return doc.id;
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> watchQnaPosts() {
    return _db.collection('qna_posts').orderBy('createdAt', descending: true).snapshots();
  }

  // =========================
  // 10) qna_comments (top-level)
  // =========================
  Future<String> createQnaComment({
    required String qnaId,
    required String authorId,
    required String comment,
  }) async {
    final doc = await _db.collection('qna_comments').add({
      'qnaId': qnaId,
      'authorId': authorId,
      'comment': comment,
      'createdAt': FieldValue.serverTimestamp(),
    });
    return doc.id;
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> watchQnaComments(String qnaId) {
    return _db
        .collection('qna_comments')
        .where('qnaId', isEqualTo: qnaId)
        .orderBy('createdAt', descending: false)
        .snapshots();
  }

  Future<void> updateQnaPostCommentCount({
    required String qnaId,
    required int newCount,
  }) {
    return _db.collection('qna_posts').doc(qnaId).update({'commentCount': newCount});
  }

  // =========================
  // 11) follows (AI안: follows/{userId}에 배열 저장) - 비추천이지만 그대로 구현
  // =========================
  Future<void> initFollowDoc(String userId) {
    return _db.collection('follows').doc(userId).set({
      'following': <String>[],
      'followers': <String>[],
    }, SetOptions(merge: true));
  }

  Future<void> follow({
    required String myUserId,
    required String targetUserId,
  }) async {
    // 내 following에 추가
    await _db.collection('follows').doc(myUserId).set({
      'following': FieldValue.arrayUnion([targetUserId]),
    }, SetOptions(merge: true));

    // 상대 followers에 추가
    await _db.collection('follows').doc(targetUserId).set({
      'followers': FieldValue.arrayUnion([myUserId]),
    }, SetOptions(merge: true));
  }

  Future<void> unfollow({
    required String myUserId,
    required String targetUserId,
  }) async {
    await _db.collection('follows').doc(myUserId).set({
      'following': FieldValue.arrayRemove([targetUserId]),
    }, SetOptions(merge: true));

    await _db.collection('follows').doc(targetUserId).set({
      'followers': FieldValue.arrayRemove([myUserId]),
    }, SetOptions(merge: true));
  }

  Future<DocumentSnapshot<Map<String, dynamic>>> getFollowDoc(String userId) {
    return _db.collection('follows').doc(userId).get();
  }
}
