import 'package:flutter/material.dart';

import '../../api/momentum_api.dart';

class RoutesTab extends StatefulWidget {
  const RoutesTab({super.key, required this.api});

  final MomentumApi api;

  @override
  State<RoutesTab> createState() => _RoutesTabState();
}

class _RoutesTabState extends State<RoutesTab> {
  final _oLat = TextEditingController(text: '31.5204');
  final _oLng = TextEditingController(text: '74.3587');
  final _dLat = TextEditingController(text: '31.4707');
  final _dLng = TextEditingController(text: '74.4091');
  final _label = TextEditingController(text: 'University commute');

  Map<String, dynamic>? _insights;
  List<dynamic> _matches = const [];
  bool _busy = false;

  @override
  void dispose() {
    _oLat.dispose();
    _oLng.dispose();
    _dLat.dispose();
    _dLng.dispose();
    _label.dispose();
    super.dispose();
  }

  double? _p(TextEditingController c) => double.tryParse(c.text.trim());

  Future<void> _fetchInsights() async {
    final olat = _p(_oLat);
    final olng = _p(_oLng);
    final dlat = _p(_dLat);
    final dlng = _p(_dLng);
    if (dlat == null || dlng == null) return;
    setState(() => _busy = true);
    try {
      final m = await widget.api.routeInsights(destLat: dlat, destLng: dlng, originLat: olat, originLng: olng);
      setState(() => _insights = m);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _share() async {
    final olat = _p(_oLat);
    final olng = _p(_oLng);
    final dlat = _p(_dLat);
    final dlng = _p(_dLng);
    if (olat == null || olng == null || dlat == null || dlng == null) return;
    setState(() => _busy = true);
    try {
      await widget.api.shareRoute(oLat: olat, oLng: olng, dLat: dlat, dLng: dlng, label: _label.text.trim());
      final matches = await widget.api.routeMatches(oLat: olat, oLng: olng, dLat: dlat, dLng: dlng);
      setState(() => _matches = matches);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Route shared — matches refreshed')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Route & weather insights', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Text('Default coordinates point to Lahore as a demo; replace with your origin/destination.', style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: TextField(controller: _oLat, decoration: const InputDecoration(labelText: 'Origin lat', border: OutlineInputBorder()))),
            const SizedBox(width: 8),
            Expanded(child: TextField(controller: _oLng, decoration: const InputDecoration(labelText: 'Origin lng', border: OutlineInputBorder()))),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(child: TextField(controller: _dLat, decoration: const InputDecoration(labelText: 'Dest lat', border: OutlineInputBorder()))),
            const SizedBox(width: 8),
            Expanded(child: TextField(controller: _dLng, decoration: const InputDecoration(labelText: 'Dest lng', border: OutlineInputBorder()))),
          ],
        ),
        const SizedBox(height: 8),
        TextField(controller: _label, decoration: const InputDecoration(labelText: 'Route label (for sharing)', border: OutlineInputBorder())),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: FilledButton(
                onPressed: _busy ? null : _fetchInsights,
                child: const Text('Get insights'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton(
                onPressed: _busy ? null : _share,
                child: const Text('Share route'),
              ),
            ),
          ],
        ),
        if (_insights != null) ...[
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_insights!['summary'] as String? ?? ''),
                  const SizedBox(height: 8),
                  Text('Weather: ${_insights!['weather_note']}', style: Theme.of(context).textTheme.bodySmall),
                  const SizedBox(height: 8),
                  Text('Tip: ${_insights!['driving_tip']}', style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
          ),
        ],
        const SizedBox(height: 16),
        Text('Similar shared routes (${_matches.length})', style: Theme.of(context).textTheme.titleMedium),
        ..._matches.map((raw) {
          final m = raw as Map<String, dynamic>;
          return ListTile(
            dense: true,
            title: Text(m['label']?.toString() ?? 'Unlabeled'),
            subtitle: Text('User ${m['user_id']} · created ${m['created_at']}'),
          );
        }),
      ],
    );
  }
}
