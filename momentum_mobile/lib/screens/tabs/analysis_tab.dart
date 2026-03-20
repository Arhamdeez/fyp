import 'package:flutter/material.dart';

import '../../api/momentum_api.dart';

class AnalysisTab extends StatefulWidget {
  const AnalysisTab({super.key, required this.api});

  final MomentumApi api;

  @override
  State<AnalysisTab> createState() => _AnalysisTabState();
}

class _AnalysisTabState extends State<AnalysisTab> {
  bool _loading = true;
  List<dynamic> _vehicles = const [];
  int? _vehicleId;
  List<dynamic> _history = const [];

  @override
  void initState() {
    super.initState();
    _boot();
  }

  Future<void> _boot() async {
    setState(() => _loading = true);
    try {
      final v = await widget.api.vehicles();
      setState(() {
        _vehicles = v;
        if (_vehicleId == null && v.isNotEmpty) {
          _vehicleId = (v.first as Map<String, dynamic>)['vehicle_id'] as int;
        }
      });
      await _refreshHistory();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _refreshHistory() async {
    final id = _vehicleId;
    if (id == null) return;
    try {
      final h = await widget.api.analysisHistory(id);
      setState(() => _history = h);
    } catch (_) {
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
    if (_loading) return const Center(child: CircularProgressIndicator());

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        DropdownButtonFormField<int>(
          value: _vehicleId,
          decoration: const InputDecoration(labelText: 'Vehicle', border: OutlineInputBorder()),
          items: _vehicles
              .map(
                (v) => DropdownMenuItem<int>(
                  value: (v as Map<String, dynamic>)['vehicle_id'] as int,
                  child: Text('${v['vehicle_model']}'),
                ),
              )
              .toList(),
          onChanged: (x) async {
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
    );
  }
}
