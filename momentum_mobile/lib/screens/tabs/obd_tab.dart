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

  List<BluetoothDevice> _bonded = const [];
  BluetoothDevice? _selected;
  bool _busy = false;
  String? _status;

  final List<String> _log = [];
  int? _speedKph;
  double? _rpm;
  /// Dongle used for the active session (shown while connected).
  BluetoothDevice? _linkedDevice;

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
      WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrapAndroidBt());
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
        setState(() => _status = 'Bluetooth permission missing — allow “Nearby devices” / Bluetooth for Momentum, then tap refresh.');
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
      if (mounted) setState(() => _status = 'Could not load paired devices: $e');
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
    final s = parseSpeedKph(line);
    if (s != null) speed = s;
    final r = parseRpm(line);
    if (r != null) rpm = r;
    setState(() {
      final ts = DateTime.now().toIso8601String();
      _log.add('$ts  $line');
      if (_log.length > _maxLog) {
        _log.removeRange(0, _log.length - _maxLog);
      }
      _speedKph = speed;
      _rpm = rpm;
    });
    ObdLiveStore.instance.updateFromObd(connected: _elm.isConnected, speed: speed, rpm: rpm);
  }

  Future<void> _connect() async {
    if (!Platform.isAndroid) return;
    final dev = _selected;
    if (dev == null || dev.address.isEmpty) {
      setState(() => _status = 'Pick a paired OBD adapter (pair it in Android Bluetooth settings first).');
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
        ObdLiveStore.instance.updateFromObd(connected: false, speed: null, rpm: null);
        setState(() {
          _linkedDevice = null;
          _status =
              'Bluetooth link closed (dongle disconnected). Often: ignition OFF, adapter sleep, or out of range. Turn ignition ON and tap Connect again.';
        });
      };

      await _elm.connect(dev.address);

      if (!mounted) return;
      setState(() => _linkedDevice = dev);

      _lineSub = _elm.lines.listen(_appendLog);

      setState(() => _status = 'Connected — initializing ELM327…');
      ObdLiveStore.instance.updateFromObd(
        connected: true,
        speed: _speedKph,
        rpm: _rpm,
        adapterLabel: _adapterShortLabel(dev),
      );

      await _elm.writeCommand('ATZ');
      await Future<void>.delayed(const Duration(milliseconds: 1500));
      await _elm.writeCommand('ATE0');
      await _elm.writeCommand('ATL0');
      await _elm.writeCommand('ATSP0');

      setState(() => _status = 'Live — polling vehicle speed (0D) and RPM (0C). Ignition ON, engine running helps.');
      ObdLiveStore.instance.updateFromObd(
        connected: true,
        speed: _speedKph,
        rpm: _rpm,
        adapterLabel: _adapterShortLabel(dev),
      );

      _pollTimer = Timer.periodic(const Duration(milliseconds: 1800), (_) async {
        if (!_elm.isConnected) return;
        try {
          await _elm.writeCommand('010D');
          await Future<void>.delayed(const Duration(milliseconds: 220));
          await _elm.writeCommand('010C');
          if (mounted) {
            ObdLiveStore.instance.updateFromObd(
              connected: true,
              speed: _speedKph,
              rpm: _rpm,
            );
          }
        } catch (e) {
          if (mounted) {
            setState(() => _status = 'Send error: $e');
          }
        }
      });
    } catch (e) {
      ObdLiveStore.instance.updateFromObd(connected: false, speed: null, rpm: null);
      if (mounted) {
        setState(() {
          _status = 'Connect failed: $e';
          _linkedDevice = null;
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
        _linkedDevice = null;
      });
    }
    ObdLiveStore.instance.updateFromObd(connected: false, speed: null, rpm: null);
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

    final scheme = Theme.of(context).colorScheme;
    final linked = _elm.isConnected;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (linked)
          Material(
            color: scheme.primaryContainer,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.bluetooth_connected, color: scheme.onPrimaryContainer, size: 28),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'OBD-II connected',
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                color: scheme.onPrimaryContainer,
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _adapterShortLabel(_linkedDevice) ?? 'Receiving data from your adapter',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onPrimaryContainer),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Speed and RPM update when the ECU answers mode 01 (41 0D / 41 0C). Turn ignition on.',
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(color: scheme.onPrimaryContainer.withValues(alpha: 0.9)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
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
            'Speed/RPM update when the ECU returns Mode 01 frames (41 0D / 41 0C).',
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
                      value: _selected != null && _bonded.any((d) => d.address == _selected!.address) ? _selected : null,
                      hint: const Text('Select dongle'),
                      items: _bonded
                          .map(
                            (d) => DropdownMenuItem(
                              value: d,
                              child: Text('${d.name ?? "OBD"} (${d.address})', overflow: TextOverflow.ellipsis),
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
                        Text('Speed', style: Theme.of(context).textTheme.labelMedium),
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
                        Text('RPM', style: Theme.of(context).textTheme.labelMedium),
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
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text('Raw from device', style: TextStyle(fontWeight: FontWeight.w600)),
          ),
        ),
        Expanded(
          child: Container(
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
              borderRadius: BorderRadius.circular(8),
              color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
            ),
            child: _log.isEmpty
                ? const Center(child: Text('No data yet — connect above.'))
                : ListView.builder(
                    reverse: true,
                    itemCount: _log.length,
                    itemBuilder: (_, i) {
                      final line = _log[_log.length - 1 - i];
                      return SelectableText(line, style: const TextStyle(fontFamily: 'monospace', fontSize: 11));
                    },
                  ),
          ),
        ),
      ],
    );
  }
}
