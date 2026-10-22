import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../core/ui.dart';
import '../../widgets/common.dart';

/// Bản đồ điểm danh: vòng tròn phòng học và vị trí từng sinh viên lúc quét QR.
class AttendanceMapScreen extends StatelessWidget {
  const AttendanceMapScreen({
    super.key,
    required this.session,
    required this.roster,
  });

  final Map<String, dynamic> session;
  final List<dynamic> roster;

  @override
  Widget build(BuildContext context) {
    final center = LatLng(
      (session['latitude'] as num).toDouble(),
      (session['longitude'] as num).toDouble(),
    );
    final radius = (session['radiusMeters'] as num).toDouble();
    final located = roster.where((r) => r['latitude'] != null).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Bản đồ điểm danh')),
      body: Column(
        children: [
          Expanded(
            child: FlutterMap(
              options: MapOptions(initialCenter: center, initialZoom: 18),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.example.duonggiavi_diemdanh',
                ),
                CircleLayer(
                  circles: [
                    CircleMarker(
                      point: center,
                      radius: radius,
                      useRadiusInMeter: true,
                      color: brandColor.withValues(alpha: 0.15),
                      borderColor: brandColor,
                      borderStrokeWidth: 2,
                    ),
                  ],
                ),
                MarkerLayer(
                  markers: [
                    Marker(
                      point: center,
                      width: 36,
                      height: 36,
                      child: const Icon(
                        Icons.school,
                        color: brandColor,
                        size: 32,
                      ),
                    ),
                    for (final r in located)
                      Marker(
                        point: LatLng(
                          (r['latitude'] as num).toDouble(),
                          (r['longitude'] as num).toDouble(),
                        ),
                        width: 36,
                        height: 36,
                        child: Tooltip(
                          message: r['fullName'],
                          child: Icon(
                            Icons.person_pin_circle,
                            size: 34,
                            color: statusColor(context, r['status']),
                          ),
                        ),
                      ),
                  ],
                ),
                const RichAttributionWidget(
                  attributions: [TextSourceAttribution('© OpenStreetMap')],
                ),
              ],
            ),
          ),
          SizedBox(
            height: 200,
            child: located.isEmpty
                ? const InfoBox(
                    icon: Icons.location_off,
                    text: 'Chưa có sinh viên nào điểm danh bằng GPS.',
                  )
                : ListView(
                    children: [
                      for (final r in located)
                        ListTile(
                          dense: true,
                          leading: Icon(
                            Icons.person_pin_circle,
                            color: statusColor(context, r['status']),
                          ),
                          title: Text(r['fullName']),
                          subtitle: Text(
                            'Cách lớp ${(r['distanceMeters'] as num?)?.round() ?? '?'} m',
                          ),
                          trailing: StatusChip(r['status']),
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}
