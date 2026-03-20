import 'package:flutter/material.dart';

import 'api/momentum_api.dart';
import 'session.dart';
import 'screens/login_screen.dart';
import 'screens/main_shell.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MomentumApp());
}

class MomentumApp extends StatefulWidget {
  const MomentumApp({super.key});

  @override
  State<MomentumApp> createState() => _MomentumAppState();
}

class _MomentumAppState extends State<MomentumApp> {
  final _session = Session();
  final _api = MomentumApi();
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _boot();
  }

  Future<void> _boot() async {
    await _session.load();
    _api.bearerToken = _session.token;
    setState(() => _ready = true);
  }

  void _onAuthChanged() {
    setState(() {
      _api.bearerToken = _session.token;
    });
  }

  @override
  Widget build(BuildContext context) {
    final seed = const Color(0xFF0D9488);
    return MaterialApp(
      title: 'Momentum',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: seed, brightness: Brightness.light),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: seed, brightness: Brightness.dark),
        useMaterial3: true,
      ),
      home: !_ready
          ? const Scaffold(body: Center(child: CircularProgressIndicator()))
          : _session.token == null
              ? LoginScreen(api: _api, session: _session, onSuccess: _onAuthChanged)
              : MainShell(
                  api: _api,
                  session: _session,
                  onLogout: () {
                    setState(() {});
                  },
                ),
    );
  }
}
