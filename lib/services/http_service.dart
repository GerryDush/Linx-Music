import 'dart:io';
import 'package:http/http.dart' as http;

class HttpService {
  HttpService._private();
  static final HttpService instance = HttpService._private();

  String baseUrl = 'https://log.geddy.cn';

  void setBaseUrl(String url) => baseUrl = url;

  Future<http.Response> postLog({
    required String body,
    Duration timeout = const Duration(seconds: 10),
  }) async {
    final uri = Uri.parse('$baseUrl/rooms/linx_music_${Platform.operatingSystem}/logs');

    try {
      final resp = await http.post(uri, body: body).timeout(timeout);
      return resp;
    } catch (e) {
      rethrow;
    }
  }
}
