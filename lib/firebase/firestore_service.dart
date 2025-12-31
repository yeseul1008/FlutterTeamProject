import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  // ======================================================
  // 1) users (Auth UID = userId)
  // ======================================================
  Future<void> createUser({
    required String userId,
    required String email,
    required String phone,
    required String provider,
    required String nickname,
    required String loginId,
    String? profileImageUrl,
  }) async {
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

    final defaultCategories = [
      'outer',
      'top',
      'bottom',
      'dress',
      'shoes',
      'accessories',
    ];

    for (final name in defaultCategories) {
      await _db.collection('users').doc(userId).collection('categories').add({
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

  // ======================================================
  // 2) categories (users/{uid}/categories)
  // ======================================================
  Stream<QuerySnapshot<Map<String, dynamic>>> watchMyCategories(String userId) {
    return _db
        .collection('users')
        .doc(userId)
        .collection('categories')
        .orderBy('createdAt', descending: false)
        .snapshots();
  }

  Future<String> createMyCategory({
    required String userId,
    required String name,
    bool isDefault = false,
  }) async {
    final doc =
    await _db.collection('users').doc(userId).collection('categories').add({
      'name': name,
      'isDefault': isDefault,
      'createdAt': FieldValue.serverTimestamp(),
    });
    return doc.id;
  }

  Future<void> deleteMyCategory({
    required String userId,
    required String categoryId,
  }) {
    return _db
        .collection('users')
        .doc(userId)
        .collection('categories')
        .doc(categoryId)
        .delete();
  }

  // ======================================================
  // 3) wardrobe (users/{uid}/wardrobe)
  // ======================================================
  Future<String> createClothes({
    required String userId,
    required String imageUrl,
    required String categoryId,
    required List<String> season,
    String? productName,
    String? shop,
    String? material,
    String? comment,
    bool liked = false,
  }) async {
    final doc =
    await _db.collection('users').doc(userId).collection('wardrobe').add({
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
        .collection('users')
        .doc(userId)
        .collection('wardrobe')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> watchLikedClothes(String userId) {
    return _db
        .collection('users')
        .doc(userId)
        .collection('wardrobe')
        .where('liked', isEqualTo: true)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  Future<void> toggleClothesLiked({
    required String userId,
    required String clothesId,
    required bool liked,
  }) {
    return _db
        .collection('users')
        .doc(userId)
        .collection('wardrobe')
        .doc(clothesId)
        .update({
      'liked': liked,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteClothes({
    required String userId,
    required String clothesId,
  }) {
    return _db
        .collection('users')
        .doc(userId)
        .collection('wardrobe')
        .doc(clothesId)
        .delete();
  }

  Future<DocumentSnapshot<Map<String, dynamic>>> getClothesDoc({
    required String userId,
    required String clothesId,
  }) {
    return _db
        .collection('users')
        .doc(userId)
        .collection('wardrobe')
        .doc(clothesId)
        .get();
  }

  // ======================================================
  // 4) lookbooks (top-level)
  // ======================================================
  Future<String> createLookbook({
    required String userId,
    required String alias,
    required String resultImageUrl,
    required List<String> clothesIds,
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

  // ======================================================
  // canvas png -> Storage 업로드 -> URL 반환
  // ======================================================
  Future<String> uploadLookbookCanvasPng({
    required String userId,
    required Uint8List pngBytes,
  }) async {
    final String fileName = '${DateTime.now().millisecondsSinceEpoch}.png';
    final ref = _storage.ref().child('lookbooks/$userId/$fileName');

    await ref.putData(
      pngBytes,
      SettableMetadata(contentType: 'image/png'),
    );

    return await ref.getDownloadURL();
  }

  // ======================================================
  // lookbook 생성 (inLookbook 플래그 포함)
  // ======================================================
  Future<String> createLookbookWithFlag({
    required String userId,
    required String alias,
    required String resultImageUrl,
    required List<String> clothesIds,
    required bool inLookbook,
    bool publishToCommunity = false,
  }) async {
    final doc = await _db.collection('lookbooks').add({
      'userId': userId,
      'alias': alias,
      'resultImageUrl': resultImageUrl,
      'clothesIds': clothesIds,
      'inLookbook': inLookbook,
      'publishToCommunity': publishToCommunity,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    return doc.id;
  }

  // ======================================================
  // ✅ 핵심: schedules + calendar 생성 (완료 버튼 시점)
  // - schedules: users/{uid}/schedules (date: Timestamp)
  // - calendar : users/{uid}/calendar/{YYYY-MM-DD} (단일문서)
  // - calendar에 imageURL + inDiary(false) + edit용 필드 함께 저장
  // ======================================================
  Future<String> createScheduleAndCalendar({
    required String userId,
    required DateTime date,
    required String weather,
    required String destinationName,
    required double lat,
    required double lon,
    required String planText,
    required String lookbookId,
    required String imageURL, // ✅ 회색 썸네일 해결 핵심
  }) async {
    final DateTime day = DateTime(date.year, date.month, date.day);
    final dateKey =
        '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';

    // 1) schedules 생성
    final scheduleDoc =
    await _db.collection('users').doc(userId).collection('schedules').add({
      'date': Timestamp.fromDate(day),
      'weather': weather,
      'destinationName': destinationName,
      'destination': GeoPoint(lat, lon),
      'planText': planText,
      'lookbookId': lookbookId,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    // 2) calendar (날짜별 단일 문서)
    await _db
        .collection('users')
        .doc(userId)
        .collection('calendar')
        .doc(dateKey)
        .set({
      'date': Timestamp.fromDate(day),
      'lookbookId': lookbookId,

      // ✅ 썸네일/프리뷰
      'imageURL': imageURL,

      // ✅ 다이어리 미작성 기본
      'inDiary': false,

      // ✅ 7번(수정 진입 시 Add 자동 채움)용 필드
      'scheduleId': scheduleDoc.id,
      'destinationName': destinationName,
      'destination': GeoPoint(lat, lon),
      'planText': planText,

      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    return scheduleDoc.id;
  }

  // ======================================================
  // ✅ 핵심: schedules + calendar 수정 (7번)
  // ======================================================
  Future<void> updateScheduleAndCalendar({
    required String userId,
    required DateTime date,
    required String scheduleId,
    required String destinationName,
    required double lat,
    required double lon,
    required String planText,
    String? imageURL, // 프리뷰를 바꾸는 경우만
    String? lookbookId,
  }) async {
    final DateTime day = DateTime(date.year, date.month, date.day);
    final dateKey =
        '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';

    // schedules 업데이트
    await _db
        .collection('users')
        .doc(userId)
        .collection('schedules')
        .doc(scheduleId)
        .update({
      'destinationName': destinationName,
      'destination': GeoPoint(lat, lon),
      'planText': planText,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    // calendar 업데이트 (Add 자동 채움용 필드 같이 갱신)
    final calData = <String, dynamic>{
      'destinationName': destinationName,
      'destination': GeoPoint(lat, lon),
      'planText': planText,
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (imageURL != null && imageURL.trim().isNotEmpty) calData['imageURL'] = imageURL;
    if (lookbookId != null && lookbookId.trim().isNotEmpty) calData['lookbookId'] = lookbookId;

    await _db
        .collection('users')
        .doc(userId)
        .collection('calendar')
        .doc(dateKey)
        .set(calData, SetOptions(merge: true));
  }

  // ======================================================
  // 5) calendar (users/{uid}/calendar)
  // ======================================================
  Stream<QuerySnapshot<Map<String, dynamic>>> watchCalendar(String userId) {
    return _db
        .collection('users')
        .doc(userId)
        .collection('calendar')
        .orderBy('date', descending: true)
        .snapshots();
  }

  Future<void> deleteCalendar({
    required String userId,
    required String calendarId,
  }) {
    return _db
        .collection('users')
        .doc(userId)
        .collection('calendar')
        .doc(calendarId)
        .delete();
  }

  // ======================================================
  // 6) diaries (users/{uid}/diaries)
  // ======================================================
  Future<String> createDiary({
    required String userId,
    required DateTime date,
    required String lookbookId,
    required double lat,
    required double lng,
    required String locationText,
    required String weather,
    required String comment,
  }) async {
    final doc = await _db.collection('users').doc(userId).collection('diaries').add({
      'userId': userId,
      'date': Timestamp.fromDate(date),
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
        .collection('users')
        .doc(userId)
        .collection('diaries')
        .orderBy('date', descending: true)
        .snapshots();
  }

  Future<void> updateDiary({
    required String userId,
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

    return _db
        .collection('users')
        .doc(userId)
        .collection('diaries')
        .doc(diaryId)
        .update(data);
  }

  Future<void> deleteDiary({
    required String userId,
    required String diaryId,
  }) {
    return _db
        .collection('users')
        .doc(userId)
        .collection('diaries')
        .doc(diaryId)
        .delete();
  }

  // ======================================================
  // 7) community_feed (top-level)
  // ======================================================
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

  // ======================================================
  // 8) scraps (users/{uid}/scraps)
  // ======================================================
  Future<void> scrapFeed({
    required String userId,
    required String feedId,
  }) {
    return _db.collection('users').doc(userId).collection('scraps').doc(feedId).set({
      'feedId': feedId,
      'scrapedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> unscrapFeed({
    required String userId,
    required String feedId,
  }) {
    return _db.collection('users').doc(userId).collection('scraps').doc(feedId).delete();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> watchMyScraps(String userId) {
    return _db
        .collection('users')
        .doc(userId)
        .collection('scraps')
        .orderBy('scrapedAt', descending: true)
        .snapshots();
  }

  // ======================================================
  // 9) qna_posts (top-level)
  // ======================================================
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

  // ======================================================
  // 10) qna_comments (top-level)
  // ======================================================
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

  // ======================================================
  // 11) follows (users/{uid}/follows/meta)
  // ======================================================
  Future<void> initFollowDoc(String userId) {
    return _db.collection('users').doc(userId).collection('follows').doc('meta').set({
      'following': <String>[],
      'followers': <String>[],
    }, SetOptions(merge: true));
  }

  Future<void> follow({
    required String myUserId,
    required String targetUserId,
  }) async {
    final myRef = _db.collection('users').doc(myUserId).collection('follows').doc('meta');
    final targetRef =
    _db.collection('users').doc(targetUserId).collection('follows').doc('meta');

    await myRef.set({
      'following': FieldValue.arrayUnion([targetUserId]),
    }, SetOptions(merge: true));

    await targetRef.set({
      'followers': FieldValue.arrayUnion([myUserId]),
    }, SetOptions(merge: true));
  }

  Future<void> unfollow({
    required String myUserId,
    required String targetUserId,
  }) async {
    final myRef = _db.collection('users').doc(myUserId).collection('follows').doc('meta');
    final targetRef =
    _db.collection('users').doc(targetUserId).collection('follows').doc('meta');

    await myRef.set({
      'following': FieldValue.arrayRemove([targetUserId]),
    }, SetOptions(merge: true));

    await targetRef.set({
      'followers': FieldValue.arrayRemove([myUserId]),
    }, SetOptions(merge: true));
  }

  Future<DocumentSnapshot<Map<String, dynamic>>> getFollowDoc(String userId) {
    return _db.collection('users').doc(userId).collection('follows').doc('meta').get();
  }
}
