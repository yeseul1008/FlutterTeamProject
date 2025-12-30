import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'weather_models.dart';

class WeatherService {
  String _readKey() {
    final key = dotenv.env['WEATHER_API_KEY'];
    if (key == null || key.trim().isEmpty) {
      throw Exception('WEATHER_API_KEY가 없거나 dotenv가 로드되지 않았습니다.');
    }
    return key.trim();
  }

  Future<WeatherResult> fetchDailyWeather({
    required DateTime date,
    required double lat,
    required double lon,
  }) async {
    final apiKey = _readKey();

    final url =
        'https://api.openweathermap.org/data/3.0/onecall'
        '?lat=$lat'
        '&lon=$lon'
        '&exclude=current,minutely,hourly,alerts'
        '&units=metric'
        '&appid=$apiKey';

    final response = await http.get(Uri.parse(url));
    if (response.statusCode != 200) {
      throw Exception('날씨 API 호출 실패: ${response.statusCode}');
    }

    final Map<String, dynamic> data = jsonDecode(response.body);
    final List dailyList = data['daily'];

    final target = dailyList.firstWhere((d) {
      final dt = DateTime.fromMillisecondsSinceEpoch(d['dt'] * 1000);
      return dt.year == date.year && dt.month == date.month && dt.day == date.day;
    }, orElse: () {
      throw Exception('선택한 날짜의 날씨 데이터가 없습니다.');
    });

    return WeatherResult(
      date: date,
      minTemp: (target['temp']['min'] as num).round(),
      maxTemp: (target['temp']['max'] as num).round(),
      iconCode: target['weather'][0]['icon'],
    );
  }
}
