import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/ui.dart';
import 'hutech_logo.dart';

/// Khung chung cho các màn tài khoản: dải xanh HUTECH có logo và vạch vàng, form bên dưới.
class AuthScaffold extends StatelessWidget {
  const AuthScaffold({
    super.key,
    required this.title,
    required this.subtitle,
    required this.child,
    this.showBack = false,
  });

  final String title;
  final String subtitle;
  final Widget child;
  final bool showBack;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final top = MediaQuery.paddingOf(context).top;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        body: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                color: brandBlueDeep,
                padding: EdgeInsets.fromLTRB(
                  showBack ? 8 : 24,
                  top + (showBack ? 4 : 28),
                  24,
                  28,
                ),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (showBack) ...[
                        BackButton(
                          color: Colors.white,
                          onPressed: () => Navigator.maybePop(context),
                        ),
                        const SizedBox(width: 8),
                      ],
                      HutechLogo(height: showBack ? 30 : 40),
                    ],
                  ),
                ),
              ),
              Container(height: 6, color: brandYellow),
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 440),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 28, 24, 32),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(title, style: text.headlineMedium),
                        const SizedBox(height: 8),
                        Text(
                          subtitle,
                          style: text.bodyLarge?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 28),
                        child,
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class BusyButton extends StatelessWidget {
  const BusyButton({
    super.key,
    required this.label,
    required this.busy,
    required this.onPressed,
  });

  final String label;
  final bool busy;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => FilledButton(
    onPressed: busy ? null : onPressed,
    child: busy
        ? const SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2.5),
          )
        : Text(label),
  );
}
