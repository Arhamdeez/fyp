import 'package:flutter/material.dart';

import '../../api/momentum_api.dart';
import '../../motion/app_motion.dart';

class AnalysisTab extends StatefulWidget {
  const AnalysisTab({super.key, required this.api});

  final MomentumApi api;

  @override
  State<AnalysisTab> createState() => _AnalysisTabState();
}

class _AnalysisTabState extends State<AnalysisTab> {
  bool _loading = true;
  List<dynamic> _vehicles = const [];
  String? _vehicleId;
  List<dynamic> _history = const [];

  String _vehicleIdFrom(Map<String, dynamic> v) => (v['_id'] ?? v['vehicle_id']).toString();

  @override
  void initState() {
    super.initState();
    _boot();
  }

  Future<void> _boot() async {
    if (!context.mounted) return;
    setState(() => _loading = true);
    List<dynamic> v;
    try {
      v = await widget.api.vehicles();
      if (v.isEmpty) v = MomentumApi.dummyVehicles();
    } catch (_) {
      v = MomentumApi.dummyVehicles();
    }
    if (!context.mounted) return;
    setState(() {
      _vehicles = v;
      if (_vehicleId == null && v.isNotEmpty) {
        _vehicleId = _vehicleIdFrom(v.first as Map<String, dynamic>);
      }
    });
    await _refreshHistory();
    if (!context.mounted) return;
    setState(() => _loading = false);
  }

  Future<void> _refreshHistory() async {
    final id = _vehicleId;
    if (id == null || MomentumApi.isOfflineDemoVehicleId(id)) {
      if (!context.mounted) return;
      setState(() => _history = const []);
      return;
    }
    try {
      final h = await widget.api.analysisHistory(id);
      if (!context.mounted) return;
      setState(() => _history = h);
    } catch (_) {
      if (!context.mounted) return;
      setState(() => _history = const []);
    }
  }

  Future<void> _run() async {
    final id = _vehicleId;
    if (id == null) return;
    try {
      await widget.api.analyze(id);
      await _refreshHistory();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Analysis saved')));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 360),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (child, animation) =>
          fadeSlideSwitcherChild(animation, child),
      child: _loading
          ? Center(
              key: const ValueKey('analysis-loading'),
              child: CircularProgressIndicator(color: scheme.primary),
            )
          : ListView(
              key: ValueKey(
                  'analysis-${_vehicleId}_${_history.length}'),
              padding: const EdgeInsets.all(16),
              children: [
        DropdownButtonFormField<String>(
          initialValue: _vehicleId,
          decoration: const InputDecoration(labelText: 'Vehicle', border: OutlineInputBorder()),
          items: _vehicles
              .map(
                (v) => DropdownMenuItem<String>(
                  value: _vehicleIdFrom(v as Map<String, dynamic>),
                  child: Text('${v['vehicle_model']}'),
                ),
              )
              .toList(),
          onChanged: (x) async {
            if (!context.mounted) return;
            setState(() => _vehicleId = x);
            await _refreshHistory();
          },
        ),
        const SizedBox(height: 16),
        FilledButton.icon(onPressed: _vehicleId == null ? null : _run, icon: const Icon(Icons.play_arrow), label: const Text('Run driving analysis')),
        const SizedBox(height: 8),
        Text(
          'Uses speed/RPM time series to estimate harsh braking and acceleration (prototype rules).',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 20),
        Text('Recent reports', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        if (_history.isEmpty)
          const Text('No reports yet.')
        else
          ..._history.map((raw) {
            final r = raw as Map<String, dynamic>;
            return Card(
              child: ListTile(
                title: Text('Score ${r['driving_score']}'),
                subtitle: Text(
                  'Harsh braking: ${r['harsh_braking_events']} · Rapid accel: ${r['acceleration_events']}\n${r['report_date']}',
                ),
                isThreeLine: true,
              ),
            );
          }),
      ],
    ),
    );
  }
}
