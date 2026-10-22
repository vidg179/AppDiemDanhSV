import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/api.dart';
import '../../core/time.dart';
import '../../core/ui.dart';
import '../../widgets/common.dart';

class PickedPhoto {
  PickedPhoto(this.name, this.bytes);
  final String name;
  final Uint8List bytes;
}

/// Gửi đơn xin phép (multipart). Tách riêng để test được.
Future<Map<String, dynamic>> submitAbsenceRequest({
  required String sessionId,
  required String category,
  required String reason,
  required List<PickedPhoto> photos,
}) async {
  final res = await Api.upload(
    '/api/absence-requests',
    {'sessionId': sessionId, 'category': category, 'reason': reason},
    [
      for (final p in photos)
        http.MultipartFile.fromBytes(
          'files',
          p.bytes,
          filename: p.name,
          contentType: MediaType('image', 'jpeg'),
        ),
    ],
  );
  return Map<String, dynamic>.from(res);
}

/// Sinh viên xin phép vắng một buổi học, chụp/chọn ảnh minh chứng (tối đa 5 ảnh).
class AbsenceFormScreen extends StatefulWidget {
  const AbsenceFormScreen({
    super.key,
    required this.session,
    required this.classData,
    this.picker,
  });

  final Map<String, dynamic> session;
  final Map<String, dynamic> classData;
  final ImagePicker? picker;

  @override
  State<AbsenceFormScreen> createState() => _AbsenceFormScreenState();
}

class _AbsenceFormScreenState extends State<AbsenceFormScreen> {
  static const _maxPhotos = 5;
  static const _maxBytes = 800 * 1024;

  final _form = GlobalKey<FormState>();
  final _reason = TextEditingController();
  late final _picker = widget.picker ?? ImagePicker();
  final _photos = <PickedPhoto>[];
  String _category = 'sick';
  bool _busy = false;

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  Future<void> _addPhoto(ImageSource source) async {
    final file = await _picker.pickImage(
      source: source,
      imageQuality: 70,
      maxWidth: 1280,
    );
    if (file == null) return;
    final bytes = await file.readAsBytes();
    if (!mounted) return;
    if (bytes.length > _maxBytes) {
      showMessage(
        context,
        'Ảnh vẫn lớn hơn 800 KB, hãy chụp lại gần hơn hoặc chọn ảnh khác',
      );
      return;
    }
    setState(() => _photos.add(PickedPhoto(file.name, bytes)));
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      await submitAbsenceRequest(
        sessionId: widget.session['id'],
        category: _category,
        reason: _reason.text.trim(),
        photos: _photos,
      );
      if (!mounted) return;
      showMessage(context, 'Đã gửi đơn, chờ giảng viên duyệt', error: false);
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
    final s = widget.session;
    return Scaffold(
      appBar: AppBar(title: const Text('Xin phép vắng')),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: ListTile(
                leading: const Icon(Icons.event_note_outlined),
                title: Text(s['title']),
                subtitle: Text(
                  '${widget.classData['code']} · ${showTime(s['startTime'])}',
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text('Lý do', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final e in absenceCategoryText.entries)
                  ChoiceChip(
                    label: Text(e.value),
                    selected: _category == e.key,
                    onSelected: (_) => setState(() => _category = e.key),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _reason,
              maxLines: 3,
              maxLength: 1000,
              decoration: const InputDecoration(
                labelText: 'Trình bày lý do',
                hintText: 'VD: Em bị sốt, có giấy khám bệnh của bệnh viện',
              ),
              validator: (v) => requiredField(v, 'lý do'),
            ),
            const SizedBox(height: 8),
            Text(
              'Ảnh minh chứng (${_photos.length}/$_maxPhotos)',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            Text(
              'Giấy khám bệnh, giấy mời... Không bắt buộc nhưng giúp đơn dễ được duyệt.',
              style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final (i, p) in _photos.indexed)
                  Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.memory(
                          p.bytes,
                          width: 96,
                          height: 96,
                          fit: BoxFit.cover,
                        ),
                      ),
                      Positioned(
                        right: 0,
                        top: 0,
                        child: IconButton.filledTonal(
                          visualDensity: VisualDensity.compact,
                          tooltip: 'Bỏ ảnh',
                          icon: const Icon(Icons.close, size: 16),
                          onPressed: () => setState(() => _photos.removeAt(i)),
                        ),
                      ),
                    ],
                  ),
                if (_photos.length < _maxPhotos) ...[
                  _AddTile(
                    icon: Icons.photo_camera_outlined,
                    label: 'Chụp ảnh',
                    onTap: () => _addPhoto(ImageSource.camera),
                  ),
                  _AddTile(
                    icon: Icons.photo_library_outlined,
                    label: 'Thư viện',
                    onTap: () => _addPhoto(ImageSource.gallery),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _busy ? null : _submit,
              child: const Text('Gửi đơn'),
            ),
          ],
        ),
      ),
    );
  }
}

class _AddTile extends StatelessWidget {
  const _AddTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: 96,
        height: 96,
        decoration: BoxDecoration(
          border: Border.all(color: scheme.outlineVariant),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon),
            const SizedBox(height: 4),
            Text(label, style: const TextStyle(fontSize: 12)),
          ],
        ),
      ),
    );
  }
}
