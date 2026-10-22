import '../core/api.dart';

class FaceEmbedder {
  static const supported = false;

  static Future<List<double>> fromPhoto(String path) async =>
      throw ApiException(
        0,
        'Nhận diện khuôn mặt chỉ dùng được trên điện thoại',
      );
}
