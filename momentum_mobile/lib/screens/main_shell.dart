import 'package:flutter/material.dart';

import '../api/momentum_api.dart';
import '../live/obd_live_store.dart';
import '../session.dart';
import 'tabs/analysis_tab.dart';
import 'tabs/dashboard_tab.dart';
import 'tabs/obd_tab.dart';
import 'tabs/recommendations_tab.dart';
import 'tabs/routes_tab.dart';
import 'tabs/vehicle_tab.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key, required this.api, required this.session});

  final MomentumApi api;
  final Session session;

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0;
  late final List<Widget> _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = <Widget>[
      DashboardTab(api: widget.api),
      VehicleTab(api: widget.api),
      const ObdTab(),
      AnalysisTab(api: widget.api),
      RoutesTab(api: widget.api),
      RecommendationsTab(api: widget.api),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return ListenableBuilder(
      listenable: ObdLiveStore.instance,
      builder: (context, _) {
        final obd = ObdLiveStore.instance;
        final obdLive = obd.elmConnected;
        final statusText = obdLive ? 'OBD connected' : 'OBD not connected';
        final statusIcon = obdLive ? Icons.bluetooth_connected : Icons.bluetooth_disabled;
        return Scaffold(
          appBar: AppBar(
            title: const Text('Momentum'),
            actions: [
              Center(
                child: Container(
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: obdLive ? scheme.primaryContainer : scheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: scheme.outlineVariant),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        statusIcon,
                        size: 16,
                        color: obdLive ? scheme.onPrimaryContainer : scheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        statusText,
                        style: Theme.of(context).textTheme.labelMedium?.copyWith(
                              color: obdLive ? scheme.onPrimaryContainer : scheme.onSurfaceVariant,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ],
                  ),
                ),
              ),
              IconButton(
                tooltip: 'API base',
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Backend URL'),
                    content: Text(
                      '${widget.api.baseUrl}\n\n'
                      'Override at build time:\n'
                      'flutter run --dart-define=MOMENTUM_API_BASE=http://<pc-ip>:5001/api\n\n'
                      'Android emulator → host: 10.0.2.2:5001',
                    ),
                    actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK'))],
                  ),
                ),
                icon: const Icon(Icons.info_outline),
              ),
            ],
          ),
          body: IndexedStack(
            index: _index,
            children: _tabs,
          ),
          bottomNavigationBar: NavigationBar(
            selectedIndex: _index,
            onDestinationSelected: (i) => setState(() => _index = i),
            destinations: [
              const NavigationDestination(
                icon: Icon(Icons.dashboard_outlined),
                selectedIcon: Icon(Icons.dashboard),
                label: 'Home',
              ),
              const NavigationDestination(
                icon: Icon(Icons.directions_car_outlined),
                selectedIcon: Icon(Icons.directions_car),
                label: 'Vehicle',
              ),
              NavigationDestination(
                icon: Icon(
                  obdLive ? Icons.bluetooth_connected : Icons.sensors_outlined,
                  color: obdLive ? scheme.primary : null,
                ),
                selectedIcon: Icon(
                  obdLive ? Icons.bluetooth_connected : Icons.sensors,
                  color: obdLive ? scheme.primary : null,
                ),
                label: 'OBD',
              ),
              const NavigationDestination(
                icon: Icon(Icons.analytics_outlined),
                selectedIcon: Icon(Icons.analytics),
                label: 'Analysis',
              ),
              const NavigationDestination(
                icon: Icon(Icons.route_outlined),
                selectedIcon: Icon(Icons.route),
                label: 'Routes',
              ),
              const NavigationDestination(
                icon: Icon(Icons.recommend_outlined),
                selectedIcon: Icon(Icons.recommend),
                label: 'Shop',
              ),
            ],
          ),
        );
      },
    );
  }
}
