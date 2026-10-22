import 'package:flutter/material.dart';

/// Logo HUTECH trong khung trắng bo góc (đọc rõ ở cả chế độ sáng và tối).
class HutechLogo extends StatelessWidget {
  const HutechLogo({super.key, this.height = 56});

  final double height;

  @override
  Widget build(BuildContext context) => Container(
    padding: EdgeInsets.symmetric(
      horizontal: height * 0.28,
      vertical: height * 0.14,
    ),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(height * 0.28),
      border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
    ),
    child: Image.asset(
      'assets/images/hutech_logo.webp',
      height: height,
      semanticLabel: 'Logo Đại học Công nghệ TP.HCM (HUTECH)',
    ),
  );
}
