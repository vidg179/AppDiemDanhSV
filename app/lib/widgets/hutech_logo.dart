import 'package:flutter/material.dart';

/// Logo HUTECH trên tấm nền trắng bo góc (đọc rõ trên nền xanh, nền xám và chế độ tối).
class HutechLogo extends StatelessWidget {
  const HutechLogo({super.key, this.height = 56});

  final double height;

  @override
  Widget build(BuildContext context) => Container(
    padding: EdgeInsets.symmetric(
      horizontal: height * 0.32,
      vertical: height * 0.2,
    ),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(height * 0.3),
    ),
    child: Image.asset(
      'assets/images/hutech_logo.webp',
      height: height,
      semanticLabel: 'Logo Đại học Công nghệ TP.HCM (HUTECH)',
    ),
  );
}
