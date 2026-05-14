import 'package:flutter/material.dart';

import '../../api/momentum_api.dart';
import '../../motion/app_motion.dart';

class RecommendationsTab extends StatefulWidget {
  const RecommendationsTab({super.key, required this.api});

  final MomentumApi api;

  @override
  State<RecommendationsTab> createState() => _RecommendationsTabState();
}

class _RecommendationsTabState extends State<RecommendationsTab> {
  bool _loading = true;
  List<dynamic> _vehicles = const [];
  String? _vehicleId;
  final _commuteKm = TextEditingController(text: '15');
  List<dynamic> _items = const [];

  String _vehicleIdFrom(Map<String, dynamic> v) => (v['_id'] ?? v['vehicle_id']).toString();

  @override
  void initState() {
    super.initState();
    _boot();
  }

  @override
  void dispose() {
    _commuteKm.dispose();
    super.dispose();
  }

  Future<void> _boot() async {
    if (!context.mounted) return;
    setState(() => _loading = true);
    List<dynamic> v;
    try {
      v = await widget.api.vehicles();
    } catch (_) {
      v = MomentumApi.dummyVehicles();
    }
    List<dynamic> recs = const [];
    try {
      recs = await widget.api.listRecommendations();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
    if (!context.mounted) return;
    setState(() {
      _vehicles = v.isEmpty ? MomentumApi.dummyVehicles() : v;
      final list = _vehicles;
      if (_vehicleId == null && list.isNotEmpty) {
        _vehicleId = _vehicleIdFrom(list.first as Map<String, dynamic>);
      }
      _items = recs;
    });
    if (!context.mounted) return;
    setState(() => _loading = false);
  }

  Future<void> _generate() async {
    final id = _vehicleId;
    if (id == null) return;
    final km = double.tryParse(_commuteKm.text.trim());
    try {
      await widget.api.generateRecommendations(id, commuteKm: km);
      final recs = await widget.api.listRecommendations();
      if (!mounted) return;
      setState(() => _items = recs);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Recommendations updated')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
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
              key: const ValueKey('rec-loading'),
              child: CircularProgressIndicator(color: scheme.primary),
            )
          : ListView(
              key: ValueKey('rec-${_vehicleId}_${_items.length}'),
              padding: const EdgeInsets.all(16),
              children: [
        Text('Vehicle recommendations', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Text(
          'Prototype matcher uses average speed, last analysis harsh events, and commute length vs. a static catalog.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          initialValue: _vehicleId,
          decoration: const InputDecoration(labelText: 'Base vehicle profile', border: OutlineInputBorder()),
          items: _vehicles
              .map(
                (v) => DropdownMenuItem<String>(
                  value: _vehicleIdFrom(v as Map<String, dynamic>),
                  child: Text('${v['vehicle_model']}'),
                ),
              )
              .toList(),
          onChanged: (x) => setState(() => _vehicleId = x),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _commuteKm,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Typical commute (km)', border: OutlineInputBorder()),
        ),
        const SizedBox(height: 12),
        FilledButton.icon(onPressed: _vehicleId == null ? null : _generate, icon: const Icon(Icons.auto_awesome), label: const Text('Generate')),
        const SizedBox(height: 20),
        Text('Saved recommendations', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        if (_items.isEmpty)
          const Text('None yet.')
        else
          ..._items.map((raw) {
            final r = raw as Map<String, dynamic>;
            return Card(
              child: ListTile(
                title: Text(r['recommendation_type']?.toString() ?? ''),
                subtitle: Text(r['description']?.toString() ?? ''),
                isThreeLine: true,
              ),
            );
          }),
      ],
    ),
    );
  }
}
