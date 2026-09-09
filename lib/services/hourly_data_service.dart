import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/hourly_weather_data.dart';

class HourlyDataService {
  static const String _baseUrl = 
      'https://script.google.com/macros/s/AKfycbzbkE_FgihGklCqDai5vBJo7FT2KORegpPxd_0zjb-664WJUpE1pAeQN2KqdAtw17v9/exec';

  /// Mengambil data historis dari Google Apps Script
  static Future<List<HourlyWeatherData>> getHourlyData({
    required DateTime start,
    required DateTime end,
  }) async {
    try {
      // Format tanggal YYYY-MM-DD
      final startDate = _formatDate(start);
      final endDate = _formatDate(end);

      final url = '$_baseUrl?start=$startDate&end=$endDate';
      
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        
        if (jsonData['status'] == 'success') {
          final List<dynamic> dataList = jsonData['data'] ?? [];
          
          return dataList.map((item) {
            return HourlyWeatherData.fromJson(item);
          }).toList();
        } else {
          throw Exception(jsonData['message'] ?? 'Gagal mengambil data');
        }
      } else {
        throw Exception('HTTP Error: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error: $e');
    }
  }

  static String _formatDate(DateTime date) {
    return '${date.year}-${_padZero(date.month)}-${_padZero(date.day)}';
  }

  static String _padZero(int value) {
    return value.toString().padLeft(2, '0');
  }
}