import 'package:flutter/material.dart';
import '../api/momentum_api.dart';
import '../features/vehicle/domain/entities/vehicle.dart';
import '../motion/app_motion.dart';
import 'dart:math' as math;

class VehicleDetailScreen extends StatefulWidget {
  const VehicleDetailScreen({super.key, required this.vehicle, required this.api});

  final Vehicle vehicle;
  final MomentumApi api;

  @override
  State<VehicleDetailScreen> createState() => _VehicleDetailScreenState();
}

class _VehicleDetailScreenState extends State<VehicleDetailScreen> {
  bool _loading = true;
  List<dynamic> _samples = [];
  List<dynamic> _maintenance = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      if (widget.vehicle.id.startsWith('local')) {
        // Skip remote fetch for local-only vehicles
        setState(() => _loading = false);
        return;
      }
      final samples = await widget.api.vehicleData(widget.vehicle.id);
      final maintenance = await widget.api.maintenanceRecommendations(widget.vehicle.id);
      if (mounted) {
        setState(() {
          _samples = samples;
          _maintenance = maintenance;
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('Detail fetch failed: $e');
      if (mounted) {
        setState(() => _loading = false);
        // We don't show a snackbar here to avoid annoying the user in offline mode
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final v = widget.vehicle;

    return Scaffold(
      appBar: AppBar(
        title: Text(v.model),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _buildHeader(context, v),
                  const SizedBox(height: 24),
                  _buildStatusCards(context, v),
                  const SizedBox(height: 24),
                  _buildMaintenanceSection(context),
                  const SizedBox(height: 24),
                  _buildDrivingHistory(context),
                  const SizedBox(height: 24),
                  _buildObdSection(context),
                  const SizedBox(height: 40),
                ],
              ),
            ),
    );
  }

  Widget _buildHeader(BuildContext context, Vehicle v) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [scheme.primary, scheme.tertiary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: scheme.primary.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    v.model,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          color: scheme.onPrimary,
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  Text(
                    '${v.year} · ${v.type.toUpperCase()}',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: scheme.onPrimary.withOpacity(0.8),
                        ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: scheme.onPrimary.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'ID: ${v.id.substring(math.max(0, v.id.length - 6))}',
                  style: TextStyle(color: scheme.onPrimary, fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildHeaderStat(context, 'Health', '${(v.health * 100).toInt()}%', Icons.favorite),
              _buildHeaderStat(context, 'Avg', '${v.fuelAverage} L/100', Icons.local_gas_station),
              _buildHeaderStat(context, 'Status', v.lastDrivingStatus, Icons.speed),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderStat(BuildContext context, String label, String value, IconData icon) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        Icon(icon, color: scheme.onPrimary, size: 20),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(color: scheme.onPrimary, fontWeight: FontWeight.bold, fontSize: 16),
        ),
        Text(
          label,
          style: TextStyle(color: scheme.onPrimary.withOpacity(0.7), fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildStatusCards(BuildContext context, Vehicle v) {
    return Row(
      children: [
        Expanded(
          child: _buildInfoCard(
            context,
            'Tire Pressure',
            'Optimal',
            Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    Text('${v.tirePressures[0]} psi'),
                    Text('${v.tirePressures[1]} psi'),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    Text('${v.tirePressures[2]} psi'),
                    Text('${v.tirePressures[3]} psi'),
                  ],
                ),
              ],
            ),
            Icons.tire_repair,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildInfoCard(
            context,
            'Last Driven',
            v.lastDrivenAt != null ? _formatTimeAgo(v.lastDrivenAt!) : 'Today',
            const Text('No issues detected during last trip.'),
            Icons.access_time,
          ),
        ),
      ],
    );
  }

  Widget _buildInfoCard(BuildContext context, String title, String subtitle, Widget content, IconData icon) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: scheme.outlineVariant.withOpacity(0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: scheme.primary),
              const SizedBox(width: 8),
              Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
            ],
          ),
          const SizedBox(height: 12),
          Text(subtitle, style: TextStyle(color: scheme.primary, fontWeight: FontWeight.bold, fontSize: 18)),
          const SizedBox(height: 8),
          DefaultTextStyle(
            style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12),
            child: content,
          ),
        ],
      ),
    );
  }

  Widget _buildMaintenanceSection(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Maintenance History', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
              TextButton(onPressed: () {}, child: const Text('Add Record')),
            ],
          ),
        ),
        const SizedBox(height: 8),
        if (_maintenance.isEmpty)
          _buildMaintenanceItem(context, 'Oil Change', 'Last: 3,000 km ago', 'Next: in 2,000 km', Icons.oil_barrel, Colors.orange)
        else
          ..._maintenance.map((m) => _buildMaintenanceItem(
                context,
                m['title'] ?? 'Service',
                m['description'] ?? '',
                m['severity'] ?? 'Upcoming',
                Icons.build,
                Colors.blue,
              )),
        _buildMaintenanceItem(context, 'Tuning', 'Last: 6 months ago', 'Healthy', Icons.settings_suggest, Colors.green),
      ],
    );
  }

  Widget _buildMaintenanceItem(BuildContext context, String title, String subtitle, String status, IconData icon, Color color) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 0,
      color: scheme.surfaceContainerLowest,
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 24),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            status,
            style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }

  Widget _buildDrivingHistory(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Recent Trip Samples', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        if (_samples.isEmpty)
          const Center(child: Padding(padding: EdgeInsets.all(20), child: Text('No driving data available yet.')))
        else
          Container(
            height: 200,
            decoration: BoxDecoration(
              color: scheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(20),
            ),
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: _samples.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final s = _samples[index];
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      Icon(Icons.directions_car, size: 16, color: scheme.primary),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Speed: ${s['speed']} km/h · RPM: ${s['rpm']}', style: const TextStyle(fontWeight: FontWeight.w500)),
                            Text(s['timestamp']?.toString() ?? 'Just now', style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12)),
                          ],
                        ),
                      ),
                      Text(
                        (s['speed'] ?? 0) > 80 ? 'Fast' : 'Stable',
                        style: TextStyle(
                          color: (s['speed'] ?? 0) > 80 ? Colors.red : Colors.green,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
      ],
    );
  }

  Widget _buildObdSection(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (_samples.isEmpty) return const SizedBox();
    
    final last = _samples.last;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('OBD Scanner Information', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _buildObdBadge(context, 'Engine Temp', '${last['engine_temp'] ?? 92}°C', Icons.thermostat),
            _buildObdBadge(context, 'Engine Load', '${last['engine_load'] ?? 15}%', Icons.analytics),
            _buildObdBadge(context, 'Throttle', '${last['throttle_position'] ?? 12}%', Icons.settings_input_component),
            _buildObdBadge(context, 'Fuel Level', '${last['fuel_level'] ?? 45}%', Icons.local_gas_station),
          ],
        ),
      ],
    );
  }

  Widget _buildObdBadge(BuildContext context, String label, String value, IconData icon) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: (MediaQuery.of(context).size.width - 44) / 2,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.secondaryContainer.withOpacity(0.3),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.secondaryContainer),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: scheme.onSecondaryContainer),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(fontSize: 10, color: scheme.onSecondaryContainer.withOpacity(0.7))),
                Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: scheme.onSecondaryContainer)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatTimeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inDays > 0) return '${diff.inDays}d ago';
    if (diff.inHours > 0) return '${diff.inHours}h ago';
    if (diff.inMinutes > 0) return '${diff.inMinutes}m ago';
    return 'Just now';
  }
}
