import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

/// 5일 예보(3시간 단위) 기반 WeatherWidget
/// - date: 선택한 날짜
/// - lat/lon: 좌표
/// - apiKey: 외부에서 주입
///
/// ✅ 변경점(정렬):
/// - 모든 Row를 mainAxisAlignment.start 로 통일해서
///   어디서 쓰든 "왼쪽 정렬" 유지
class WeatherWidget extends StatefulWidget {
  final DateTime date;
  final double lat;
  final double lon;
  final String? apiKey;

  const WeatherWidget({
    super.key,
    required this.date,
    required this.lat,
    required this.lon,
    this.apiKey,
  });

  @override
  State<WeatherWidget> createState() => _WeatherWidgetState();
}

class _WeatherWidgetState extends State<WeatherWidget> {
  Future<_ForecastPick> _fetchForecastPick({
    required DateTime targetDate,
    required double lat,
    required double lon,
    required String apiKey,
  }) async {
    final uri = Uri.https('api.openweathermap.org', '/data/2.5/forecast', {
      'lat': lat.toString(),
      'lon': lon.toString(),
      'units': 'metric',
      'appid': apiKey,
    });

    debugPrint('OW request: $uri');

    final res = await http.get(uri);

    debugPrint('OW status: ${res.statusCode}');
    final body = res.body;
    final head =
    body.isEmpty ? '' : body.substring(0, body.length > 300 ? 300 : body.length);
    debugPrint('OW body(head300): $head');

    if (res.statusCode != 200) {
      throw Exception('Forecast API error: ${res.statusCode} ${res.body}');
    }

    final json = jsonDecode(res.body) as Map<String, dynamic>;
    final rawList = json['list'];

    if (rawList is! List) {
      throw Exception('Forecast API malformed: list is not List');
    }

    final list = rawList.cast<Map<String, dynamic>>();

    // 선택 날짜(yyyy-mm-dd)로 매칭되는 항목만 필터
    final targetYmd = DateTime(targetDate.year, targetDate.month, targetDate.day);

    final candidates = <_ForecastItem>[];
    for (final item in list) {
      final dtTxt = item['dt_txt'] as String?;
      if (dtTxt == null) continue;

      final dt = DateTime.tryParse(dtTxt.replaceFirst(' ', 'T'));
      if (dt == null) continue;

      final ymd = DateTime(dt.year, dt.month, dt.day);
      if (ymd == targetYmd) {
        candidates.add(_ForecastItem.fromJson(item, dt));
      }
    }

    if (candidates.isEmpty) {
      throw _NoForecastForDate();
    }

    // 같은 날짜 내에서 정오(12:00)에 가장 가까운 값 선택
    final noon = DateTime(targetYmd.year, targetYmd.month, targetYmd.day, 12);
    candidates.sort((a, b) =>
    (a.dt.difference(noon).inMinutes).abs() - (b.dt.difference(noon).inMinutes).abs());

    final pick = candidates.first;

    return _ForecastPick(
      dt: pick.dt,
      temp: pick.temp,
      description: pick.description,
      icon: pick.icon,
    );
  }

  @override
  Widget build(BuildContext context) {
    final String apiKey = (widget.apiKey != null && widget.apiKey!.trim().isNotEmpty)
        ? widget.apiKey!.trim()
        : '';

    if (apiKey.isEmpty) {
      return const Row(
        mainAxisAlignment: MainAxisAlignment.start, // ✅ 왼쪽 정렬
        children: [
          Icon(Icons.key_off, size: 18),
          SizedBox(width: 8),
          Text(
            'OpenWeather API 키를 설정하세요',
            style: TextStyle(fontSize: 12),
          ),
        ],
      );
    }

    return FutureBuilder<_ForecastPick>(
      future: _fetchForecastPick(
        targetDate: widget.date,
        lat: widget.lat,
        lon: widget.lon,
        apiKey: apiKey,
      ),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Row(
            mainAxisAlignment: MainAxisAlignment.start, // ✅ 왼쪽 정렬
            children: [
              SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              SizedBox(width: 8),
              Text('날씨 불러오는 중...', style: TextStyle(fontSize: 12)),
            ],
          );
        }

        if (snap.hasError) {
          debugPrint('OW error: ${snap.error}');

          if (snap.error is _NoForecastForDate) {
            return const Row(
              mainAxisAlignment: MainAxisAlignment.start, // ✅ 왼쪽 정렬
              children: [
                Icon(Icons.info_outline, size: 18),
                SizedBox(width: 8),
                Text(
                  '선택한 날짜는 5일 예보 범위가 아닙니다',
                  style: TextStyle(fontSize: 12),
                ),
              ],
            );
          }

          return const Row(
            mainAxisAlignment: MainAxisAlignment.start, // ✅ 왼쪽 정렬
            children: [
              Icon(Icons.cloud_off, size: 18),
              SizedBox(width: 8),
              Text('날씨 로드 실패', style: TextStyle(fontSize: 12)),
            ],
          );
        }

        final data = snap.data!;
        final iconUrl = 'https://openweathermap.org/img/wn/${data.icon}@2x.png';

        return Row(
          mainAxisAlignment: MainAxisAlignment.start, // ✅ 왼쪽 정렬
          children: [
            Image.network(
              iconUrl,
              width: 34,
              height: 34,
              errorBuilder: (_, __, ___) =>
              const Icon(Icons.wb_sunny_outlined, size: 20),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                '${data.temp.toStringAsFixed(0)}°  ${data.description}',
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _NoForecastForDate implements Exception {}

class _ForecastPick {
  final DateTime dt;
  final double temp;
  final String description;
  final String icon;

  _ForecastPick({
    required this.dt,
    required this.temp,
    required this.description,
    required this.icon,
  });
}

class _ForecastItem {
  final DateTime dt;
  final double temp;
  final String description;
  final String icon;

  _ForecastItem({
    required this.dt,
    required this.temp,
    required this.description,
    required this.icon,
  });

  factory _ForecastItem.fromJson(Map<String, dynamic> json, DateTime dt) {
    final main = (json['main'] as Map<String, dynamic>?) ?? {};
    final weatherList = (json['weather'] as List?) ?? [];
    final weather = weatherList.isNotEmpty
        ? (weatherList.first as Map<String, dynamic>)
        : <String, dynamic>{};

    final temp = (main['temp'] is num) ? (main['temp'] as num).toDouble() : 0.0;
    final desc = (weather['description'] as String?) ?? '';
    final icon = (weather['icon'] as String?) ?? '01d';

    return _ForecastItem(
      dt: dt,
      temp: temp,
      description: desc,
      icon: icon,
    );
  }
}
