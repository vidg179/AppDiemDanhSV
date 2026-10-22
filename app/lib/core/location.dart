import 'package:geolocator/geolocator.dart';

import 'api.dart';

/// Xin quyền và lấy vị trí hiện tại. Lỗi được đổi thành ApiException để màn hình hiện thông báo.
Future<Position> currentPosition() async {
  if (!await Geolocator.isLocationServiceEnabled()) {
    throw ApiException(0, 'Hãy bật định vị (GPS) trên điện thoại');
  }
  var perm = await Geolocator.checkPermission();
  if (perm == LocationPermission.denied) {
    perm = await Geolocator.requestPermission();
  }
  if (perm == LocationPermission.denied) {
    throw ApiException(0, 'Cần cho phép truy cập vị trí');
  }
  if (perm == LocationPermission.deniedForever) {
    throw ApiException(
      0,
      'Quyền vị trí đã bị chặn, hãy mở Cài đặt để cho phép lại',
    );
  }
  return Geolocator.getCurrentPosition(
    locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
  );
}
