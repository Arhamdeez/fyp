import 'dart:async';

import 'package:flutter/material.dart';

import '../telemetry/ride_demo.dart';
import '../telemetry/ride_db.dart';
import '../telemetry/ride_record.dart';

class LastRideReportScreen extends StatefulWidget {
  const LastRideReportScreen({super.key});

  @override
  State<LastRideReportScreen> createState() => _LastRideReportScreenState();
}

class _LastRideReportScreenState extends State<LastRideReportScreen> {
  RideRecord? _ride;
  bool _loading = true;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final ride = await RideDb.instance.latestRide();
      if (!mounted) return;
      setState(() {
        _ride = ride;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  Future<void> _saveDemoRide(String mode) async {
    final rec = mode == 'harsh' ? RideDemo.stressful() : RideDemo.smooth();
    try {
      await RideDb.instance.insertRide(rec);
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Demo ride saved')),
      );
    } catch (e, st) {
      debugPrint('Demo insert failed: $e\n$st');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Demo save failed: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Last ride summary'),
        actions: [
          IconButton(
            tooltip: 'Reload',
            onPressed: () {
              setState(() {
                _loading = true;
                _error = null;
              });
              unawaited(_load());
            },
            icon: const Icon(Icons.refresh),
          ),
          PopupMenuButton<String>(
            tooltip: 'Demo rides',
            onSelected: (v) => unawaited(_saveDemoRide(v)),
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'smooth', child: Text('Demo · smooth')),
              PopupMenuItem(value: 'harsh', child: Text('Demo · harsh')),
            ],
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Could not load rides: $_error',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: () {
                        setState(() {
                          _loading = true;
                          _error = null;
                        });
                        _load();
                      },
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            )
          : _ride == null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'No finished ride recorded yet.\n'
                  'Connect to your OBD adapter, drive with telemetry running, '
                  'then disconnect — we save one summary per connected session.',
                  style: Theme.of(context).textTheme.bodyLarge,
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _VerdictBanner(verdict: _ride!.verdict),
                const SizedBox(height: 12),
                if (_ride!.adapterLabel != null)
                  Text(
                    'Adapter: ${_ride!.adapterLabel}',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                  ),
                const SizedBox(height: 4),
                Text(
                  'Started ${_ride!.startedAt.toLocal()}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                ),
                Text(
                  'Ended ${_ride!.endedAt.toLocal()}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                ),
                const SizedBox(height: 16),
                ..._ride!.summaryLines.map(
                  (line) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.chevron_right,
                          size: 20,
                          color: scheme.primary,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            line,
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Estimates use OBD speed/RPM/load only — no gyro. '
                  'Future versions can fuse GPS or phone sensors.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: scheme.outline,
                      ),
                ),
              ],
            ),
    );
  }
}

class _VerdictBanner extends StatelessWidget {
  const _VerdictBanner({required this.verdict});

  final RideVerdict verdict;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    late final Color bg;
    late final Color fg;
    late final IconData icon;
    late final String headline;

    switch (verdict) {
      case RideVerdict.good:
        bg = scheme.primaryContainer;
        fg = scheme.onPrimaryContainer;
        icon = Icons.check_circle_outline;
        headline = 'Good drive';
      case RideVerdict.moderate:
        bg = scheme.secondaryContainer;
        fg = scheme.onSecondaryContainer;
        icon = Icons.shield_moon_outlined;
        headline = 'Moderate';
      case RideVerdict.harsh:
        bg = scheme.errorContainer;
        fg = scheme.onErrorContainer;
        icon = Icons.warning_amber_rounded;
        headline = 'Harsh on the car';
    }

    return Card(
      color: bg,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(icon, color: fg, size: 40),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    headline,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: fg,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Based on high RPM stretches, harsh braking, and rapid acceleration inferred from ECU speed.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: fg,
                        ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
