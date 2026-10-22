import 'package:duonggiavi_diemdanh/core/time.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('toApiTime gửi giờ UTC có hậu tố Z', () {
    final local = DateTime(2026, 10, 22, 7, 30);
    final sent = toApiTime(local);
    expect(sent.endsWith('Z'), isTrue);
    expect(fromApiTime(sent), local);
  });
}
