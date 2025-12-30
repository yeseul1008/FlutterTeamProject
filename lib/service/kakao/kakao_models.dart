/// 카카오 로컬(키워드 검색) 결과 모델
/// - KakaoPlace: 우리 앱에서 쓰기 좋은 형태(이름/위경도)
/// - KakaoKeywordSearchResponse: API 응답 파싱용(필요 시 확장)
class KakaoPlace {
  final String name;
  final double lat; // y (위도)
  final double lon; // x (경도)
  final String? address;
  final String? roadAddress;

  const KakaoPlace({
    required this.name,
    required this.lat,
    required this.lon,
    this.address,
    this.roadAddress,
  });

  /// 카카오 API documents 1개를 KakaoPlace로 변환
  factory KakaoPlace.fromKakaoDocument(Map<String, dynamic> doc) {
    final name = (doc['place_name'] as String?) ?? '';
    final x = (doc['x'] as String?) ?? '0'; // 경도
    final y = (doc['y'] as String?) ?? '0'; // 위도

    return KakaoPlace(
      name: name,
      lat: double.tryParse(y) ?? 0.0,
      lon: double.tryParse(x) ?? 0.0,
      address: doc['address_name'] as String?,
      roadAddress: doc['road_address_name'] as String?,
    );
  }
}

class KakaoKeywordSearchResponse {
  final List<KakaoPlace> places;

  const KakaoKeywordSearchResponse({required this.places});

  factory KakaoKeywordSearchResponse.fromJson(Map<String, dynamic> json) {
    final rawDocs = json['documents'];
    if (rawDocs is! List) {
      return const KakaoKeywordSearchResponse(places: []);
    }

    final docs = rawDocs.cast<Map<String, dynamic>>();
    final places = docs.map(KakaoPlace.fromKakaoDocument).toList();

    return KakaoKeywordSearchResponse(places: places);
  }
}
