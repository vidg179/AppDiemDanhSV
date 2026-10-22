import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../core/api.dart';
import '../../core/location.dart';
import '../../core/time.dart';
import '../../core/ui.dart';
import '../../face/face_capture.dart';
import '../../widgets/common.dart';

class FaceRequiredException implements Exception {}

/// Gửi điểm danh: mã QR + vị trí (nếu lấy được) + khuôn mặt (nếu buổi học yêu cầu).
/// Ném FaceRequiredException khi buổi học cần khuôn mặt mà chưa gửi.
Future<Map<String, dynamic>> submitCheckIn(
  String qrToken, {
  double? latitude,
  double? longitude,
  List<double>? faceEmbedding,
}) async {
  try {
    return Map<String, dynamic>.from(
      await Api.post('/api/attendance/checkin', {
        'qrToken': qrToken.trim(),
        'latitude': ?latitude,
        'longitude': ?longitude,
        'faceEmbedding': ?faceEmbedding,
      }),
    );
  } on ApiException catch (e) {
    if (faceEmbedding == null &&
        e.message.contains('yêu cầu xác thực khuôn mặt')) {
      throw FaceRequiredException();
    }
    if (e.message.contains('chưa đăng ký khuôn mặt')) {
      throw ApiException(
        e.status,
        'Bạn chưa đăng ký khuôn mặt. Vào Hồ sơ để đăng ký rồi quét lại.',
      );
    }
    rethrow;
  }
}

/// Quét mã QR giảng viên chiếu, lấy GPS rồi gửi điểm danh.
class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key, this.capture = captureFace});

  final FaceCapture capture;

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  final _controller = MobileScannerController(
    formats: const [BarcodeFormat.qrCode],
  );
  final _manual = TextEditingController();
  bool _busy = false;
  String _step = '';

  @override
  void dispose() {
    _controller.dispose();
    _manual.dispose();
    super.dispose();
  }

  Future<void> _handle(String token) async {
    if (_busy || token.trim().isEmpty) return;
    setState(() {
      _busy = true;
      _step = 'Đang lấy vị trí...';
    });
    await _controller.stop();
    double? lat, lng;
    try {
      final p = await currentPosition();
      lat = p.latitude;
      lng = p.longitude;
    } catch (_) {
      // Không có GPS vẫn gửi; nếu buổi học bắt buộc vị trí thì API sẽ báo lỗi rõ ràng.
    }
    setState(() => _step = 'Đang điểm danh...');
    try {
      Map<String, dynamic> record;
      try {
        record = await submitCheckIn(token, latitude: lat, longitude: lng);
      } on FaceRequiredException {
        if (!mounted) return;
        final face = await widget.capture(
          context,
          'Buổi học yêu cầu xác thực khuôn mặt. Nhìn thẳng vào camera.',
        );
        if (face == null) {
          throw ApiException(0, 'Chưa xác thực khuôn mặt nên chưa điểm danh');
        }
        setState(() => _step = 'Đang xác thực khuôn mặt...');
        record = await submitCheckIn(
          token,
          latitude: lat,
          longitude: lng,
          faceEmbedding: face,
        );
      }
      if (!mounted) return;
      await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          icon: Icon(
            Icons.check_circle,
            color: statusColor(ctx, record['status']),
            size: 48,
          ),
          title: Text(
            record['status'] == 'late'
                ? 'Điểm danh thành công (trễ)'
                : 'Điểm danh thành công',
          ),
          content: Text(
            'Ghi nhận lúc ${showTime(record['checkInTime'])}'
            '${record['faceVerified'] == true ? '\nĐã xác thực khuôn mặt' : ''}',
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Xong'),
            ),
          ],
        ),
      );
      if (mounted) Navigator.pop(context, true);
    } on ApiException catch (e) {
      if (!mounted) return;
      showMessage(context, e.message);
      setState(() => _busy = false);
      await _controller.start();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Quét QR điểm danh')),
      body: Column(
        children: [
          Expanded(
            child: Stack(
              alignment: Alignment.center,
              children: [
                MobileScanner(
                  controller: _controller,
                  onDetect: (capture) {
                    final value = capture.barcodes.firstOrNull?.rawValue;
                    if (value != null) _handle(value);
                  },
                  errorBuilder: (context, error) => InfoBox(
                    icon: Icons.no_photography_outlined,
                    text: 'Không mở được camera. Cho phép quyền camera hoặc nhập mã bên dưới.',
                  ),
                ),
                IgnorePointer(
                  child: Container(
                    width: 250,
                    height: 250,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.white, width: 3),
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                ),
                if (_busy)
                  Container(
                    color: Colors.black54,
                    alignment: Alignment.center,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const CircularProgressIndicator(),
                        const SizedBox(height: 12),
                        Text(
                          _step,
                          style: const TextStyle(color: Colors.white),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  const Text(
                    'Đưa mã QR vào khung. Không quét được thì nhập mã:',
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _manual,
                          textCapitalization: TextCapitalization.characters,
                          decoration: const InputDecoration(
                            hintText: 'Mã điểm danh',
                            isDense: true,
                          ),
                          onSubmitted: _handle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      FilledButton(
                        style: FilledButton.styleFrom(
                          minimumSize: const Size(0, 48),
                        ),
                        onPressed: _busy ? null : () => _handle(_manual.text),
                        child: const Text('Gửi'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
