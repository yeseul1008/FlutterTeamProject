class WeatherResult {
  final DateTime date;
  final int minTemp;
  final int maxTemp;
  final String iconCode;

  WeatherResult({
    required this.date,
    required this.minTemp,
    required this.maxTemp,
    required this.iconCode,
  });
}
