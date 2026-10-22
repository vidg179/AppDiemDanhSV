import 'dart:io';
import 'dart:math';

import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';

import '../core/api.dart';

/// Ảnh chụp → vector khuôn mặt: ML Kit tìm mặt, cắt 112x112, MobileFaceNet ra vector (thường 192 số).
class FaceEmbedder {
  static const supported = true;
  static const modelAsset = 'assets/models/mobilefacenet.tflite';

  static Interpreter? _interpreter;
  static final _detector = FaceDetector(
    options: FaceDetectorOptions(
      enableClassification: true,
      performanceMode: FaceDetectorMode.accurate,
    ),
  );

  static Future<Interpreter> _model() async {
    if (_interpreter != null) return _interpreter!;
    try {
      return _interpreter = await Interpreter.fromAsset(modelAsset);
    } catch (_) {
      throw ApiException(
        0,
        'Thiếu file model $modelAsset. Xem hướng dẫn trong assets/models/README.txt',
      );
    }
  }

  static Future<List<double>> fromPhoto(String path) async {
    final faces = await _detector.processImage(InputImage.fromFilePath(path));
    if (faces.isEmpty) {
      throw ApiException(0, 'Không thấy khuôn mặt, hãy chụp lại ở nơi đủ sáng');
    }
    if (faces.length > 1) {
      throw ApiException(0, 'Trong ảnh chỉ được có 1 khuôn mặt');
    }
    final face = faces.first;
    if ((face.leftEyeOpenProbability ?? 1) < 0.4 ||
        (face.rightEyeOpenProbability ?? 1) < 0.4) {
      throw ApiException(0, 'Hãy mở mắt và nhìn thẳng vào camera');
    }

    final decoded = img.decodeImage(await File(path).readAsBytes());
    if (decoded == null) {
      throw ApiException(0, 'Không đọc được ảnh, hãy chụp lại');
    }
    final photo = img.bakeOrientation(decoded);

    // Nới khung mặt thêm 10% cho đủ cằm và trán.
    final box = face.boundingBox;
    final pad = box.width * 0.1;
    final x = max(0, (box.left - pad).toInt());
    final y = max(0, (box.top - pad).toInt());
    final w = min(photo.width - x, (box.width + 2 * pad).toInt());
    final h = min(photo.height - y, (box.height + 2 * pad).toInt());
    final model = await _model();
    final inputShape = model.getInputTensor(0).shape; // [1, H, W, 3]
    final size = inputShape[1];
    final crop = img.copyResize(
      img.copyCrop(photo, x: x, y: y, width: w, height: h),
      width: size,
      height: size,
    );

    final input = [
      List.generate(
        size,
        (row) => List.generate(size, (col) {
          final p = crop.getPixel(col, row);
          return [
            (p.r - 127.5) / 128,
            (p.g - 127.5) / 128,
            (p.b - 127.5) / 128,
          ];
        }),
      ),
    ];
    final length = model.getOutputTensor(0).shape.last;
    final output = [List<double>.filled(length, 0)];
    model.run(input, output);
    return output.first;
  }
}
