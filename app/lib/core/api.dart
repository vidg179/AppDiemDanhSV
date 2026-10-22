import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'config.dart';

class ApiException implements Exception {
  ApiException(this.status, this.message);
  final int status;
  final String message;

  @override
  String toString() => message;
}

class Api {
  static String? token;

  /// Thay bằng MockClient khi chạy test.
  static http.Client client = http.Client();

  static Future<void> loadToken() async {
    final prefs = await SharedPreferences.getInstance();
    token = prefs.getString('token');
  }

  static Future<void> saveToken(String? value) async {
    token = value;
    final prefs = await SharedPreferences.getInstance();
    if (value == null) {
      await prefs.remove('token');
    } else {
      await prefs.setString('token', value);
    }
  }

  static Future<dynamic> get(String path) => _send('GET', path);
  static Future<dynamic> post(String path, [Object? body]) =>
      _send('POST', path, body);
  static Future<dynamic> put(String path, [Object? body]) =>
      _send('PUT', path, body);
  static Future<dynamic> delete(String path) => _send('DELETE', path);

  static Future<dynamic> _send(
    String method,
    String path, [
    Object? body,
  ]) async {
    final req = http.Request(method, Uri.parse('$baseUrl$path'))
      ..headers['Content-Type'] = 'application/json';
    if (token != null) req.headers['Authorization'] = 'Bearer $token';
    if (body != null) req.body = jsonEncode(body);
    return _handle(await _run(() => client.send(req)));
  }

  /// Gửi form kèm file (đơn xin phép). Mỗi file gửi dưới tên trường "files".
  static Future<dynamic> upload(
    String path,
    Map<String, String> fields,
    List<http.MultipartFile> files,
  ) async {
    final req = http.MultipartRequest('POST', Uri.parse('$baseUrl$path'));
    if (token != null) req.headers['Authorization'] = 'Bearer $token';
    req.fields.addAll(fields);
    req.files.addAll(files);
    return _handle(await _run(() => client.send(req)));
  }

  static Future<http.Response> _run(
    Future<http.StreamedResponse> Function() send,
  ) async {
    try {
      return await http.Response.fromStream(
        await send().timeout(const Duration(seconds: 30)),
      );
    } on TimeoutException {
      throw ApiException(0, 'Máy chủ phản hồi quá lâu, thử lại sau');
    } on http.ClientException {
      throw ApiException(0, 'Không kết nối được máy chủ, kiểm tra mạng');
    }
  }

  static dynamic _handle(http.Response res) {
    final text = utf8.decode(res.bodyBytes);
    final data = text.isEmpty ? null : jsonDecode(text);
    if (res.statusCode >= 200 && res.statusCode < 300) return data;

    var message = 'Lỗi ${res.statusCode}';
    if (data is Map && data['message'] is String) {
      message = data['message'];
    } else if (data is Map && data['errors'] is Map) {
      message = (data['errors'] as Map).values
          .expand((e) => e as List)
          .join('\n');
    }
    throw ApiException(res.statusCode, message);
  }
}
