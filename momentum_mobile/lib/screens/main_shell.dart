import 'package:flutter/material.dart';

import '../api/momentum_api.dart';
import '../session.dart';
import 'tabs/analysis_tab.dart';
import 'tabs/dashboard_tab.dart';
import 'tabs/recommendations_tab.dart';
import 'tabs/routes_tab.dart';
import 'tabs/vehicle_tab.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key, required this.api, required this.session, required this.onLogout});

  final MomentumApi api;
  final Session session;
  final VoidCallback onLogout;

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final tabs = <Widget>[
      DashboardTab(api: widget.api),
      VehicleTab(api: widget.api),
      AnalysisTab(api: widget.api),
      RoutesTab(api: widget.api),
      RecommendationsTab(api: widget.api),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Momentum'),
        actions: [
          IconButton(
            tooltip: 'API base',
            onPressed: () => showDialog<void>(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text('Backend URL'),
                content: Text('${widget.api.baseUrl}\n\nChange in lib/config.dart if needed.\nAndroid emulator → host: 10.0.2.2:8000'),
                actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK'))],
              ),
            ),
            icon: const Icon(Icons.info_outline),
          ),
          IconButton(
            tooltip: 'Log out',
            onPressed: () async {
              widget.api.bearerToken = null;
              await widget.session.clear();
              widget.onLogout();
            },
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: tabs[_index],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.dashboard_outlined), selectedIcon: Icon(Icons.dashboard), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.directions_car_outlined), selectedIcon: Icon(Icons.directions_car), label: 'Vehicle'),
          NavigationDestination(icon: Icon(Icons.analytics_outlined), selectedIcon: Icon(Icons.analytics), label: 'Analysis'),
          NavigationDestination(icon: Icon(Icons.route_outlined), selectedIcon: Icon(Icons.route), label: 'Routes'),
          NavigationDestination(icon: Icon(Icons.recommend_outlined), selectedIcon: Icon(Icons.recommend), label: 'Shop'),
        ],
      ),
    );
  }
}
