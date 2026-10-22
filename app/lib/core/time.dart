import 'package:intl/intl.dart';

/// Gửi giờ lên API: luôn đổi sang UTC, nếu không sẽ lệch 7 tiếng.
String toApiTime(DateTime local) => local.toUtc().toIso8601String();

/// Giờ API trả về (UTC) đổi về giờ máy.
DateTime fromApiTime(String s) => DateTime.parse(s).toLocal();

String showTime(String s) =>
    DateFormat('HH:mm dd/MM/yyyy').format(fromApiTime(s));

String showDate(String s) => DateFormat('dd/MM/yyyy').format(fromApiTime(s));

/// "Thứ Tư, 08/10 · 15:03–16:33"
String showRange(String start, String end) {
  final s = fromApiTime(start);
  final e = fromApiTime(end);
  final day = DateFormat('EEEE, dd/MM', 'vi').format(s);
  final hm = DateFormat('HH:mm');
  return '${day[0].toUpperCase()}${day.substring(1)} · ${hm.format(s)}–${hm.format(e)}';
}

/// "15:03–16:33" (dùng cạnh ô ngày, không lặp lại ngày)
String showHours(String start, String end) {
  final hm = DateFormat('HH:mm');
  return '${hm.format(fromApiTime(start))}–${hm.format(fromApiTime(end))}';
}
