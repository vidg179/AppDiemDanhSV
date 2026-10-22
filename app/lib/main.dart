import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'core/api.dart';
import 'core/session.dart';
import 'core/ui.dart';
import 'screens/auth/login_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Api.loadToken();
  runApp(const DiemDanhApp());
}

class DiemDanhApp extends StatelessWidget {
  const DiemDanhApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Điểm danh HUTECH',
    debugShowCheckedModeBanner: false,
    theme: buildTheme(Brightness.light),
    darkTheme: buildTheme(Brightness.dark),
    locale: const Locale('vi'),
    supportedLocales: const [Locale('vi'), Locale('en')],
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
    home: const StartScreen(),
  );
}

/// Mở app: còn đăng nhập thì vào thẳng trang theo vai trò, không thì ra màn đăng nhập.
class StartScreen extends StatefulWidget {
  const StartScreen({super.key});

  @override
  State<StartScreen> createState() => _StartScreenState();
}

class _StartScreenState extends State<StartScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _go());
  }

  Future<void> _go() async {
    Widget next = const LoginScreen();
    if (Api.token != null) {
      try {
        await Session.refresh();
        next = homeFor(Session.role);
      } on ApiException catch (e) {
        if (e.status == 401) await Session.signOut();
      }
    }
    if (!mounted) return;
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => next));
  }

  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Center(child: CircularProgressIndicator()));
}
