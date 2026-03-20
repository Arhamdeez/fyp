import 'package:flutter/material.dart';

import '../../api/momentum_api.dart';

class RecommendationsTab extends StatefulWidget {
  const RecommendationsTab({super.key, required this.api});

  final MomentumApi api;

  @override
  State<RecommendationsTab> createState() => _RecommendationsTabState();
}

class _RecommendationsTabState extends State<RecommendationsTab> {
  bool _loading = true;
  List<dynamic> _vehicles = const [];
  int? _vehicleId;
  final _commuteKm = TextEditingController(text: '15');
  List<dynamic> _items = const [];

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
    setState(() => _loading = true);
    try {
      final v = await widget.api.vehicles();
      final recs = await widget.api.listRecommendations();
      setState(() {
        _vehicles = v;
        if (_vehicleId == null && v.isNotEmpty) {
          _vehicleId = (v.first as Map<String, dynamic>)['vehicle_id'] as int;
        }
        _items = recs;
      });
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _generate() async {
    final id = _vehicleId;
    if (id == null) return;
    final km = double.tryParse(_commuteKm.text.trim());
    try {
      await widget.api.generateRecommendations(id, commuteKm: km);
      final recs = await widget.api.listRecommendations();
      setState(() => _items = recs);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Recommendations updated')));
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
        Text('Vehicle recommendations', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Text(
          'Prototype matcher uses average speed, last analysis harsh events, and commute length vs. a static catalog.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<int>(
          value: _vehicleId,
          decoration: const InputDecoration(labelText: 'Base vehicle profile', border: OutlineInputBorder()),
          items: _vehicles
              .map(
                (v) => DropdownMenuItem<int>(
                  value: (v as Map<String, dynamic>)['vehicle_id'] as int,
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
    );
  }
}
