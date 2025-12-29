import 'dart:convert';
import 'package:http/http.dart' as http;

import 'kakao_models.dart';

class KakaoService {
  /// ⚠️ 주의: 깃허브에 올릴 땐 키를 코드에 박아두면 안 됩니다.
  /// 일단 국비/개발 단계에서는 빠르게 이렇게 쓰고,
  /// 나중에 .env로 빼는 걸 추천드립니다.
  static const String _kakaoRestApiKey = '4237974c32003dddeee74c0a77eb05cf';

  /// 키워드로 장소 검색 -> KakaoPlace 리스트 반환
  /// 예) "강남역", "성수", "홍대입구"
  Future<List<KakaoPlace>> searchKeyword({
    required String query,
    int size = 10,
    int page = 1,
  }) async {
    final q = query.trim();
    if (q.isEmpty) return [];

    final uri = Uri.https(
      'dapi.kakao.com',
      '/v2/local/search/keyword.json',
      {
        'query': q,
        'size': size.toString(),
        'page': page.toString(),
      },
    );

    final res = await http.get(
      uri,
      headers: {
        'Authorization': 'KakaoAK $_kakaoRestApiKey',
      },
    );

    if (res.statusCode != 200) {
      // 디버깅용으로 응답 일부를 함께 던짐
      throw Exception('Kakao API error: ${res.statusCode} ${res.body}');
    }

    final Map<String, dynamic> jsonMap = jsonDecode(res.body) as Map<String, dynamic>;
    final parsed = KakaoKeywordSearchResponse.fromJson(jsonMap);

    return parsed.places;
  }
}
