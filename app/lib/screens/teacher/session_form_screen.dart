import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/api.dart';
import '../../core/location.dart';
import '../../core/time.dart';
import '../../core/ui.dart';

/// Tạo (session == null) hoặc sửa buổi học. Trả về true khi đã lưu.
class SessionFormScreen extends StatefulWidget {
  const SessionFormScreen({super.key, required this.classId, this.session});

  final String classId;
  final Map<String, dynamic>? session;

  @override
  State<SessionFormScreen> createState() => _SessionFormScreenState();
}

class _SessionFormScreenState extends State<SessionFormScreen> {
  final _form = GlobalKey<FormState>();
  late final _title = TextEditingController(
    text: widget.session?['title'] ?? '',
  );
  late DateTime _start;
  late DateTime _end;
  double? _lat;
  double? _lng;
  late double _radius =
      (widget.session?['radiusMeters'] as num?)?.toDouble() ?? 100;
  late bool _requireFace = widget.session?['requireFace'] == true;
  bool _locating = false;
  bool _busy = false;

  bool get _isEdit => widget.session != null;

  @override
  void initState() {
    super.initState();
    final s = widget.session;
    if (s != null) {
      _start = fromApiTime(s['startTime']);
      _end = fromApiTime(s['endTime']);
      _lat = (s['latitude'] as num?)?.toDouble();
      _lng = (s['longitude'] as num?)?.toDouble();
    } else {
      final now = DateTime.now();
      _start = DateTime(
        now.year,
        now.month,
        now.day,
        now.hour,
        now.minute - now.minute % 5,
      );
      _end = _start.add(const Duration(minutes: 90));
    }
  }

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _start,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (d == null) return;
    setState(() {
      _start = DateTime(d.year, d.month, d.day, _start.hour, _start.minute);
      _end = DateTime(d.year, d.month, d.day, _end.hour, _end.minute);
    });
  }

  Future<void> _pickTime(bool isStart) async {
    final current = isStart ? _start : _end;
    final t = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(current),
    );
    if (t == null) return;
    setState(() {
      final picked = DateTime(
        current.year,
        current.month,
        current.day,
        t.hour,
        t.minute,
      );
      if (isStart) {
        final length = _end.difference(_start);
        _start = picked;
        _end = picked.add(length);
      } else {
        _end = picked;
      }
    });
  }

  Future<void> _useCurrentLocation() async {
    setState(() => _locating = true);
    try {
      final p = await currentPosition();
      setState(() {
        _lat = p.latitude;
        _lng = p.longitude;
      });
    } on ApiException catch (e) {
      if (mounted) showMessage(context, e.message);
    } catch (e) {
      if (mounted) showMessage(context, 'Không lấy được vị trí: $e');
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    if (!_end.isAfter(_start)) {
      showMessage(context, 'Giờ kết thúc phải sau giờ bắt đầu');
      return;
    }
    setState(() => _busy = true);
    final body = {
      'title': _title.text.trim(),
      'startTime': toApiTime(_start),
      'endTime': toApiTime(_end),
      if (_lat != null) 'latitude': _lat,
      if (_lng != null) 'longitude': _lng,
      'radiusMeters': _radius.round(),
      'requireFace': _requireFace,
    };
    try {
      if (_isEdit) {
        await Api.put('/api/sessions/${widget.session!['id']}', body);
      } else {
        await Api.post('/api/classes/${widget.classId}/sessions', body);
      }
      if (!mounted) return;
      showMessage(
        context,
        _isEdit ? 'Đã lưu buổi học' : 'Đã tạo buổi học',
        error: false,
      );
      Navigator.pop(context, true);
    } on ApiException catch (e) {
      if (mounted) showMessage(context, e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final hm = DateFormat('HH:mm');
    return Scaffold(
      appBar: AppBar(title: Text(_isEdit ? 'Sửa buổi học' : 'Tạo buổi học')),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _title,
              decoration: const InputDecoration(
                labelText: 'Tiêu đề buổi học',
                hintText: 'VD: Buổi 3 - Widget cơ bản',
              ),
              validator: (v) => requiredField(v, 'tiêu đề'),
            ),
            const SizedBox(height: 16),
            Card(
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.calendar_today_outlined),
                    title: const Text('Ngày học'),
                    trailing: Text(
                      DateFormat('EEEE, dd/MM/yyyy', 'vi').format(_start),
                    ),
                    onTap: _pickDate,
                  ),
                  ListTile(
                    leading: const Icon(Icons.schedule),
                    title: const Text('Bắt đầu'),
                    trailing: Text(hm.format(_start)),
                    onTap: () => _pickTime(true),
                  ),
                  ListTile(
                    leading: const Icon(Icons.schedule_outlined),
                    title: const Text('Kết thúc'),
                    trailing: Text(hm.format(_end)),
                    onTap: () => _pickTime(false),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Vị trí phòng học',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _lat == null
                          ? 'Chưa đặt. Sinh viên ở đâu cũng điểm danh được.'
                          : 'Đã đặt: ${_lat!.toStringAsFixed(5)}, ${_lng!.toStringAsFixed(5)}. '
                                'Sinh viên phải ở trong bán kính ${_radius.round()} m.',
                      style: TextStyle(color: scheme.onSurfaceVariant),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _locating ? null : _useCurrentLocation,
                            icon: _locating
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.my_location),
                            label: const Text('Lấy vị trí hiện tại'),
                          ),
                        ),
                        if (_lat != null) ...[
                          const SizedBox(width: 8),
                          IconButton(
                            tooltip: 'Bỏ vị trí',
                            onPressed: () => setState(() {
                              _lat = null;
                              _lng = null;
                            }),
                            icon: const Icon(Icons.location_off_outlined),
                          ),
                        ],
                      ],
                    ),
                    if (_lat != null) ...[
                      const SizedBox(height: 8),
                      Text('Bán kính cho phép: ${_radius.round()} m'),
                      Slider(
                        value: _radius,
                        min: 20,
                        max: 500,
                        divisions: 48,
                        label: '${_radius.round()} m',
                        onChanged: (v) => setState(() => _radius = v),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              value: _requireFace,
              onChanged: (v) => setState(() => _requireFace = v),
              title: const Text('Yêu cầu xác thực khuôn mặt'),
              subtitle: const Text(
                'Sinh viên quét QR xong phải chụp mặt, chống điểm danh hộ',
              ),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _busy ? null : _save,
              child: Text(_isEdit ? 'Lưu thay đổi' : 'Tạo buổi học'),
            ),
          ],
        ),
      ),
    );
  }
}
