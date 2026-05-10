import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../live/obd_live_store.dart';
import '../../obd/elm_connection.dart';
import '../../obd/obd_pid_parse.dart';

/// Live ELM327 (Bluetooth Classic) — shows raw lines from the dongle + decoded speed/RPM.
class ObdTab extends StatefulWidget {
  const ObdTab({super.key});

  @override
  State<ObdTab> createState() => _ObdTabState();
}

class _ObdTabState extends State<ObdTab> {
  final ElmConnection _elm = ElmConnection();
  StreamSubscription<String>? _lineSub;
  Timer? _pollTimer;
  bool _polling = false;

  List<BluetoothDevice> _bonded = const [];
  BluetoothDevice? _selected;
  bool _busy = false;
  String? _status;

  final List<String> _log = [];
  int? _speedKph;
  double? _rpm;
  double? _engineLoadPct;
  double? _coolantTempC;
  double? _intakeTempC;
  double? _throttlePct;
  bool _harshBraking = false;
  int? _lastSpeedForBrake;
  DateTime? _lastSpeedAt;
  DateTime? _lastHarshBrakingAt;

  static const int _maxLog = 350;

  String? _adapterShortLabel(BluetoothDevice? d) {
    if (d == null) return null;
    final n = (d.name ?? '').trim();
    if (n.isEmpty) return d.address;
    return '$n · ${d.address}';
  }

  @override
  void initState() {
    super.initState();
    // Android 12+ requires BLUETOOTH_CONNECT before BluetoothAdapter.getBondedDevices().
    // Never touch the adapter until runtime permissions are granted (avoids native crash).
    if (Platform.isAndroid) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _bootstrapAndroidBt(),
      );
    }
  }

  Future<void> _bootstrapAndroidBt() async {
    final ok = await _ensureAndroidPermissions();
    if (!mounted || !ok) return;
    if (!await Permission.bluetoothConnect.isGranted) return;
    await Future<void>.delayed(const Duration(milliseconds: 250));
    await _loadBonded();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _lineSub?.cancel();
    _elm.dispose();
    super.dispose();
  }

  Future<void> _loadBonded() async {
    if (!Platform.isAndroid) return;
    if (!await Permission.bluetoothConnect.isGranted) {
      if (mounted) {
        setState(
          () => _status =
              'Bluetooth permission missing — allow “Nearby devices” / Bluetooth for Momentum, then tap refresh.',
        );
      }
      return;
    }
    try {
      final list = await FlutterBluetoothSerial.instance.getBondedDevices();
      if (!mounted) return;
      setState(() {
        _bonded = list;
        _selected = list.isNotEmpty ? list.first : null;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _status = 'Could not load paired devices: $e');
      }
    }
  }

  Future<bool> _ensureAndroidPermissions() async {
    if (!Platform.isAndroid) return true;

    // Order matters: CONNECT must be granted before any BluetoothAdapter call (getBondedDevices, etc.).
    var connect = await Permission.bluetoothConnect.status;
    if (!connect.isGranted) {
      connect = await Permission.bluetoothConnect.request();
    }
    if (!connect.isGranted) {
      if (mounted) {
        setState(
          () => _status =
              'Allow Bluetooth / “Nearby devices” for Momentum (required on Android 12+). Open app settings if you chose “Don’t allow”.',
        );
      }
      return false;
    }

    var scan = await Permission.bluetoothScan.status;
    if (!scan.isGranted) {
      scan = await Permission.bluetoothScan.request();
    }
    // Paired-only flow can work without SCAN on many devices; don’t block if user denies.

    await Future<void>.delayed(const Duration(milliseconds: 150));
    return true;
  }

  Future<void> _ensureBluetoothOn() async {
    final enabled = await FlutterBluetoothSerial.instance.isEnabled ?? false;
    if (!enabled) {
      await FlutterBluetoothSerial.instance.requestEnable();
    }
  }

  void _appendLog(String line) {
    if (!mounted) return;
    var speed = _speedKph;
    var rpm = _rpm;
    var load = _engineLoadPct;
    var coolant = _coolantTempC;
    var intake = _intakeTempC;
    var throttle = _throttlePct;
    final s = parseSpeedKph(line);
    if (s != null) speed = s;
    final r = parseRpm(line);
    if (r != null) rpm = r;
    final l = parseEngineLoadPct(line);
    if (l != null) load = l;
    final c = parseCoolantTempC(line);
    if (c != null) coolant = c;
    final i = parseIntakeTempC(line);
    if (i != null) intake = i;
    final t = parseThrottlePct(line);
    if (t != null) throttle = t;
    final now = DateTime.now();
    if (s != null) {
      final isHarsh = _updateHarshBraking(s, now);
      if (isHarsh) _lastHarshBrakingAt = now;
    }
    final harshBraking = _isHarshBrakingNow(now);
    setState(() {
      final ts = now.toIso8601String();
      _log.add('$ts  $line');
      if (_log.length > _maxLog) {
        _log.removeRange(0, _log.length - _maxLog);
      }
      _speedKph = speed;
      _rpm = rpm;
      _engineLoadPct = load;
      _coolantTempC = coolant;
      _intakeTempC = intake;
      _throttlePct = throttle;
      _harshBraking = harshBraking;
    });
    ObdLiveStore.instance.updateFromObd(
      connected: _elm.isConnected,
      speed: speed,
      rpm: rpm,
      engineLoadPct: load,
      coolantTempC: coolant,
      intakeTempC: intake,
      throttlePct: throttle,
      harshBraking: harshBraking,
    );
  }

  bool _updateHarshBraking(int speedKph, DateTime now) {
    final prevSpeed = _lastSpeedForBrake;
    final prevAt = _lastSpeedAt;
    _lastSpeedForBrake = speedKph;
    _lastSpeedAt = now;
    if (prevSpeed == null || prevAt == null || speedKph >= prevSpeed) {
      return false;
    }
    final dtSec = now.difference(prevAt).inMilliseconds / 1000.0;
    if (dtSec < 0.2) return false;
    final dvMs = (speedKph - prevSpeed) / 3.6;
    final accelMs2 = dvMs / dtSec;
    return accelMs2 <= -3.0;
  }

  bool _isHarshBrakingNow(DateTime now) {
    final last = _lastHarshBrakingAt;
    if (last == null) return false;
    return now.difference(last) <= const Duration(seconds: 3);
  }

  String _friendlyError(Object error) {
    final raw = error.toString();
    final compact = raw
        .replaceAll('\n', ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    final lower = compact.toLowerCase();
    if (lower.contains('timeout')) {
      return 'connection timed out';
    }
    if (lower.contains('future not completed')) {
      return 'adapter did not respond in time';
    }
    if (lower.contains('socket might closed') ||
        lower.contains('read failed')) {
      return 'bluetooth socket closed during connect';
    }
    if (lower.contains('permission')) {
      return 'bluetooth permission denied';
    }
    if (compact.isEmpty) return 'unknown error';
    return compact.length > 90 ? '${compact.substring(0, 87)}...' : compact;
  }

  Future<void> _pollOnce() async {
    if (!_elm.isConnected) return;
    if (_polling) return;
    _polling = true;
    try {
      // Fast loop: speed (0D), RPM (0C), engine load (04), coolant (05), intake (0F), throttle (11).
      await _elm.writeCommand('010D');
      await Future<void>.delayed(const Duration(milliseconds: 120));
      await _elm.writeCommand('010C');
      await Future<void>.delayed(const Duration(milliseconds: 120));
      await _elm.writeCommand('0104');
      await Future<void>.delayed(const Duration(milliseconds: 120));
      await _elm.writeCommand('0105');
      await Future<void>.delayed(const Duration(milliseconds: 120));
      await _elm.writeCommand('010F');
      await Future<void>.delayed(const Duration(milliseconds: 120));
      await _elm.writeCommand('0111');
      // Heartbeat update even if the ECU returns same values.
      if (mounted) {
        ObdLiveStore.instance.updateFromObd(
          connected: true,
          speed: _speedKph,
          rpm: _rpm,
          engineLoadPct: _engineLoadPct,
          coolantTempC: _coolantTempC,
          intakeTempC: _intakeTempC,
          throttlePct: _throttlePct,
          harshBraking: _harshBraking,
        );
      }
    } finally {
      _polling = false;
    }
  }

  Future<void> _connect() async {
    if (!Platform.isAndroid) return;
    final dev = _selected;
    if (dev == null || dev.address.isEmpty) {
      setState(
        () => _status =
            'Pick a paired OBD adapter (pair it in Android Bluetooth settings first).',
      );
      return;
    }

    setState(() {
      _busy = true;
      _status = 'Connecting…';
    });

    try {
      if (!await _ensureAndroidPermissions()) {
        return;
      }
      await Future<void>.delayed(const Duration(milliseconds: 200));
      await _ensureBluetoothOn();

      await _lineSub?.cancel();
      _pollTimer?.cancel();

      _elm.onDisconnected = () {
        if (!mounted) return;
        _pollTimer?.cancel();
        _pollTimer = null;
        ObdLiveStore.instance.updateFromObd(
          connected: false,
          speed: null,
          rpm: null,
        );
        setState(() {
          _status =
              'Bluetooth link closed (dongle disconnected). Often: ignition OFF, adapter sleep, or out of range. Turn ignition ON and tap Connect again.';
        });
      };

      await _elm.connect(dev.address);

      if (!mounted) return;

      _lineSub = _elm.lines.listen(_appendLog);

      setState(() => _status = 'Connected — initializing ELM327…');
      ObdLiveStore.instance.updateFromObd(
        connected: true,
        speed: _speedKph,
        rpm: _rpm,
        engineLoadPct: _engineLoadPct,
        coolantTempC: _coolantTempC,
        intakeTempC: _intakeTempC,
        throttlePct: _throttlePct,
        harshBraking: _harshBraking,
        adapterLabel: _adapterShortLabel(dev),
      );

      await _elm.writeCommand('ATZ');
      await Future<void>.delayed(const Duration(milliseconds: 1500));
      await _elm.writeCommand('ATE0');
      await _elm.writeCommand('ATL0');
      await _elm.writeCommand('ATSP0');

      setState(
        () => _status =
            'Live — polling speed, RPM, load, coolant temp, intake temp, and throttle. Ignition ON helps.',
      );
      ObdLiveStore.instance.updateFromObd(
        connected: true,
        speed: _speedKph,
        rpm: _rpm,
        engineLoadPct: _engineLoadPct,
        coolantTempC: _coolantTempC,
        intakeTempC: _intakeTempC,
        throttlePct: _throttlePct,
        harshBraking: _harshBraking,
        adapterLabel: _adapterShortLabel(dev),
      );

      await _pollOnce();
      _pollTimer = Timer.periodic(const Duration(milliseconds: 650), (_) async {
        try {
          await _pollOnce();
        } catch (e) {
          if (mounted) {
            setState(() => _status = 'Poll error: ${_friendlyError(e)}');
          }
        }
      });
    } catch (e) {
      ObdLiveStore.instance.updateFromObd(
        connected: false,
        speed: null,
        rpm: null,
      );
      if (mounted) {
        setState(() {
          _status = 'Connect failed: ${_friendlyError(e)}';
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _disconnect() async {
    _pollTimer?.cancel();
    _pollTimer = null;
    await _lineSub?.cancel();
    _lineSub = null;
    _elm.onDisconnected = null;
    await _elm.disconnect(notifyListeners: false);
    if (mounted) {
      setState(() {
        _status = 'Disconnected';
        _speedKph = null;
        _rpm = null;
        _engineLoadPct = null;
        _coolantTempC = null;
        _intakeTempC = null;
        _throttlePct = null;
        _harshBraking = false;
        _lastSpeedForBrake = null;
        _lastSpeedAt = null;
        _lastHarshBrakingAt = null;
      });
    }
    ObdLiveStore.instance.updateFromObd(
      connected: false,
      speed: null,
      rpm: null,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!Platform.isAndroid) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'OBD-II over Bluetooth Classic is implemented for Android only.\n'
            'Use an Android phone with a paired ELM327 adapter.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.only(bottom: 12),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Text(
            'ELM327 live',
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Text(
            'Pair your dongle in system Bluetooth, then select it here. Raw lines from the adapter appear below; '
            'metrics update when the ECU returns Mode 01 frames.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Row(
            children: [
              Expanded(
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Paired adapter',
                    border: OutlineInputBorder(),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<BluetoothDevice>(
                      isExpanded: true,
                      value:
                          _selected != null &&
                              _bonded.any(
                                (d) => d.address == _selected!.address,
                              )
                          ? _selected
                          : null,
                      hint: const Text('Select dongle'),
                      items: _bonded
                          .map(
                            (d) => DropdownMenuItem(
                              value: d,
                              child: Text(
                                '${d.name ?? "OBD"} (${d.address})',
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: _elm.isConnected
                          ? null
                          : (d) {
                              setState(() => _selected = d);
                            },
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.outlined(
                tooltip: 'Refresh paired list',
                onPressed: _busy ? null : () => _bootstrapAndroidBt(),
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: _busy
                      ? null
                      : _elm.isConnected
                      ? null
                      : _connect,
                  icon: const Icon(Icons.link),
                  label: const Text('Connect & read'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _elm.isConnected ? _disconnect : null,
                  icon: const Icon(Icons.link_off),
                  label: const Text('Disconnect'),
                ),
              ),
            ],
          ),
        ),
        if (_status != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Text(_status!, style: Theme.of(context).textTheme.bodySmall),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Row(
            children: [
              Expanded(
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Speed',
                          style: Theme.of(context).textTheme.labelMedium,
                        ),
                        Text(
                          _speedKph == null ? '—' : '$_speedKph km/h',
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'RPM',
                          style: Theme.of(context).textTheme.labelMedium,
                        ),
                        Text(
                          _rpm == null ? '—' : _rpm!.toStringAsFixed(0),
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  const Icon(Icons.tune),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Engine load',
                          style: Theme.of(context).textTheme.labelMedium,
                        ),
                        Text(
                          _engineLoadPct == null
                              ? '—'
                              : '${_engineLoadPct!.toStringAsFixed(1)} %',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ],
                    ),
                  ),
                  if (_engineLoadPct != null)
                    Text(
                      'PID 04',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Row(
            children: [
              Expanded(
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Coolant temp',
                          style: Theme.of(context).textTheme.labelMedium,
                        ),
                        Text(
                          _coolantTempC == null
                              ? '—'
                              : '${_coolantTempC!.toStringAsFixed(0)} °C',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Intake temp',
                          style: Theme.of(context).textTheme.labelMedium,
                        ),
                        Text(
                          _intakeTempC == null
                              ? '—'
                              : '${_intakeTempC!.toStringAsFixed(0)} °C',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  const Icon(Icons.speed),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Throttle position',
                          style: Theme.of(context).textTheme.labelMedium,
                        ),
                        Text(
                          _throttlePct == null
                              ? '—'
                              : '${_throttlePct!.toStringAsFixed(1)} %',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ],
                    ),
                  ),
                  if (_throttlePct != null)
                    Text(
                      'PID 11',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Card(
            color: _harshBraking
                ? Theme.of(context).colorScheme.errorContainer
                : null,
            child: ListTile(
              leading: Icon(
                _harshBraking
                    ? Icons.warning_amber_rounded
                    : Icons.monitor_heart_outlined,
                color: _harshBraking
                    ? Theme.of(context).colorScheme.onErrorContainer
                    : null,
              ),
              title: Text(
                _harshBraking ? 'Harsh braking detected' : 'Braking monitor',
                style: _harshBraking
                    ? Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: Theme.of(context).colorScheme.onErrorContainer,
                        fontWeight: FontWeight.w700,
                      )
                    : null,
              ),
              subtitle: Text(
                'Estimated from speed drop rate between consecutive speed updates.',
                style: _harshBraking
                    ? Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onErrorContainer,
                      )
                    : null,
              ),
            ),
          ),
        ),
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Raw from device',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ),
        SizedBox(
          height: 220,
          child: Container(
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              border: Border.all(
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
              borderRadius: BorderRadius.circular(8),
              color: Theme.of(
                context,
              ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
            ),
            child: _log.isEmpty
                ? const Center(child: Text('No data yet — connect above.'))
                : ListView.builder(
                    reverse: true,
                    itemCount: _log.length,
                    itemBuilder: (_, i) {
                      final line = _log[_log.length - 1 - i];
                      return SelectableText(
                        line,
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 11,
                        ),
                      );
                    },
                  ),
          ),
        ),
      ],
    );
  }
}
