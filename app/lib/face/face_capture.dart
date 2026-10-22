import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../core/api.dart';
import '../core/ui.dart';
import 'face_embedder.dart';

/// Chụp mặt bằng camera trước và trả về vector. null nếu người dùng hủy hoặc ảnh không dùng được.
typedef FaceCapture = Future<List<double>?> Function(
  BuildContext context,
  String hint,
);

Future<List<double>?> captureFace(BuildContext context, String hint) async {
  if (!FaceEmbedder.supported) {
    showMessage(context, 'Nhận diện khuôn mặt chỉ dùng được trên điện thoại');
    return null;
  }
  final go = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      icon: const Icon(Icons.face_retouching_natural, size: 40),
      title: const Text('Chụp khuôn mặt'),
      content: Text('$hint\nĐứng nơi đủ sáng, không đeo khẩu trang, mở mắt.'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Hủy'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Mở camera'),
        ),
      ],
    ),
  );
  if (go != true) return null;
  final photo = await ImagePicker().pickImage(
    source: ImageSource.camera,
    preferredCameraDevice: CameraDevice.front,
    maxWidth: 1080,
  );
  if (photo == null || !context.mounted) return null;

  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (_) => const Center(child: CircularProgressIndicator()),
  );
  try {
    return await FaceEmbedder.fromPhoto(photo.path);
  } on ApiException catch (e) {
    if (context.mounted) showMessage(context, e.message);
    return null;
  } finally {
    if (context.mounted) Navigator.of(context, rootNavigator: true).pop();
  }
}
