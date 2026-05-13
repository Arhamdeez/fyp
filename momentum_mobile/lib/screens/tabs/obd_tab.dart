import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../live/obd_live_store.dart';
import '../../obd/elm_connection.dart';
import '../../obd/obd_pid_parse.dart';
import '../../telemetry/ride_demo.dart';
import '../../telemetry/ride_db.dart';
import '../../telemetry/ride_session.dart';
import '../last_ride_report_screen.dart';

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

  RideSession? _rideSession;
  String? _rideAdapterLabel;

  _ObdGaugeSnapshot? _freezeAtSilentTripEnd;

  bool _awaitingTelemetryResume = false;

  DateTime _lastTelemetryMotionAt = DateTime.now();

  int? _motionPrevSpeed;
  double? _motionPrevRpm;
  double? _motionPrevLoad;
  double? _motionPrevCoolant;
  double? _motionPrevThrottle;

  Timer? _rideStallWatcher;

  static const Duration _rideSilenceEndsTrip = Duration(seconds: 95);
  static const Duration _minimumRecordedBeforeSilenceEnd = Duration(seconds: 42);
  static const Duration _rideStallPollInterval = Duration(seconds: 8);

  static const int _epsSpeedKph = 1;
  static const double _epsRpm = 28;
  static const double _epsLoad = 6;
  static const double _epsCoolantC = 0.9;
  static const double _epsThrottlePct = 3.5;

  static const int _maxLog = 350;

  Future<void> _finishRidePersist({
    bool endedByStaleTelemetry = false,
    _ObdGaugeSnapshot? stalledTelemetryFrame,
  }) async {
    final session = _rideSession;
    _rideSession = null;
    if (session == null) return;

    final rec = session.finish(
      endedAt: DateTime.now(),
      adapterLabel: _rideAdapterLabel,
    );
    final keep = rec.sampleCount >= 3 ||
        rec.duration.inSeconds >= 8 ||
        rec.maxSpeedKph > 5 ||
        rec.maxRpm > 500;

    if (!keep) {
      _awaitingTelemetryResume = false;
      _freezeAtSilentTripEnd = null;
      return;
    }
    try {
      await RideDb.instance.insertRide(rec);
    } catch (e, stack) {
      debugPrint('RideDb.insertRide failed: $e\n$stack');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not save ride summary: $e')),
      );
      _awaitingTelemetryResume = false;
      _freezeAtSilentTripEnd = null;
      return;
    }

    if (endedByStaleTelemetry && mounted) {
      setState(
        () => _status =
            'Trip saved — telemetry paused (usually ignition OFF or ECU sleep). Wake the car / restart engine '
            'to begin a new trip while staying connected.',
      );
    }

    if (endedByStaleTelemetry && _elm.isConnected && stalledTelemetryFrame != null) {
      _awaitingTelemetryResume = true;
      _freezeAtSilentTripEnd = stalledTelemetryFrame;
    } else {
      _awaitingTelemetryResume = false;
      _freezeAtSilentTripEnd = null;
    }
  }

  _ObdGaugeSnapshot _snapshotGauges() {
    return _ObdGaugeSnapshot(
      speed: _speedKph,
      rpm: _rpm,
      loadPct: _engineLoadPct,
      coolantC: _coolantTempC,
      throttlePct: _throttlePct,
    );
  }

  /// Call whenever a fresh [RideSession] begins (Bluetooth connect or post-stall resume).
  void _resetMotionAnchorsForNewTrip() {
    _motionPrevSpeed = null;
    _motionPrevRpm = null;
    _motionPrevLoad = null;
    _motionPrevCoolant = null;
    _motionPrevThrottle = null;
    _lastTelemetryMotionAt = DateTime.now();
  }

  void _observePidMotionAgainstPreviousPoll() {
    if (_rideSession == null) return;

    bool tick = false;
    final s = _speedKph;
    final r = _rpm;
    final load = _engineLoadPct;
    final c = _coolantTempC;
    final th = _throttlePct;

    if (!_ObdGaugeSnapshot.sameishInt(s, _motionPrevSpeed, _epsSpeedKph)) tick = true;
    if (!_ObdGaugeSnapshot.sameishDouble(r, _motionPrevRpm, _epsRpm)) tick = true;
    if (!_ObdGaugeSnapshot.sameishDouble(load, _motionPrevLoad, _epsLoad)) tick = true;
    if (!_ObdGaugeSnapshot.sameishDouble(c, _motionPrevCoolant, _epsCoolantC)) tick = true;
    if (!_ObdGaugeSnapshot.sameishDouble(th, _motionPrevThrottle, _epsThrottlePct)) tick = true;

    if (tick) _lastTelemetryMotionAt = DateTime.now();

    _motionPrevSpeed = s ?? _motionPrevSpeed;
    _motionPrevRpm = r ?? _motionPrevRpm;
    _motionPrevLoad = load ?? _motionPrevLoad;
    _motionPrevCoolant = c ?? _motionPrevCoolant;
    _motionPrevThrottle = th ?? _motionPrevThrottle;
  }

  bool _looksLikeTelemetryResumedAfterStale() {
    final frozen = _freezeAtSilentTripEnd;
    if (frozen == null) return false;
    return frozen.gateMeaningfullyChanged(_snapshotGauges());
  }

  void _attemptResumeRideAfterSilentEnd() {
    if (!_elm.isConnected || !_awaitingTelemetryResume) return;
    if (_freezeAtSilentTripEnd == null || _rideSession != null) return;
    if (!_looksLikeTelemetryResumedAfterStale()) return;

    _awaitingTelemetryResume = false;
    _freezeAtSilentTripEnd = null;
    _rideSession = RideSession();
    _resetMotionAnchorsForNewTrip();
    if (mounted) {
      setState(
        () => _status =
            'Recording new trip — telemetry is updating again. Drive safely.',
      );
    }
  }

  void _evaluateSilentTelemetryTripEnd() {
    if (!_elm.isConnected) return;

    /// Only auto-close while we are accumulating a ride, not already waiting on resume.
    final session = _rideSession;
    if (session == null || _awaitingTelemetryResume) return;

    final now = DateTime.now();
    if (now.difference(session.startedAt) < _minimumRecordedBeforeSilenceEnd) return;

    if (now.difference(_lastTelemetryMotionAt) < _rideSilenceEndsTrip) return;

    final stalledSnap = _snapshotGauges();
    unawaited(_finishRidePersist(endedByStaleTelemetry: true, stalledTelemetryFrame: stalledSnap));
  }

  void _startRideStallWatcher() {
    _rideStallWatcher?.cancel();
    _rideStallWatcher = Timer.periodic(_rideStallPollInterval, (_) {
      try {
        _evaluateSilentTelemetryTripEnd();
      } catch (_) {
        /* non-fatal */
      }
    });
  }

  void _stopRideStallWatcher() {
    _rideStallWatcher?.cancel();
    _rideStallWatcher = null;
  }

  Future<void> _saveDemoRide(String mode) async {
    final rec = mode == 'harsh' ? RideDemo.stressful() : RideDemo.smooth();
    try {
      await RideDb.instance.insertRide(rec);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Demo ride saved — open Last ride to view')),
      );
    } catch (e, stack) {
      debugPrint('Demo insert failed: $e\n$stack');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Demo save failed: $e')),
      );
    }
  }

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
    _stopRideStallWatcher();
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
      await Future<void>.delayed(const Duration(milliseconds: 180));
      if (!mounted || !_elm.isConnected) return;

      _attemptResumeRideAfterSilentEnd();
      _observePidMotionAgainstPreviousPoll();

      final session = _rideSession;
      if (session != null) {
        session.ingestPollSnapshot(
          now: DateTime.now(),
          speedKph: _speedKph,
          rpm: _rpm,
          engineLoadPct: _engineLoadPct,
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
        _stopRideStallWatcher();
        _pollTimer?.cancel();
        _pollTimer = null;
        _awaitingTelemetryResume = false;
        _freezeAtSilentTripEnd = null;
        unawaited(_finishRidePersist());
        _rideAdapterLabel = null;
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

      _rideAdapterLabel = _adapterShortLabel(dev);
      _freezeAtSilentTripEnd = null;
      _awaitingTelemetryResume = false;
      _rideSession = RideSession();
      _resetMotionAnchorsForNewTrip();
      _startRideStallWatcher();

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
            'Live — polling PIDs. Trip recording runs while gauges keep changing; when ignition turns OFF and '
            'readings go flat for ~95s, your last trip is saved (Bluetooth can stay on).',
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
      _stopRideStallWatcher();
      await _finishRidePersist();
      _rideAdapterLabel = null;
      _awaitingTelemetryResume = false;
      _freezeAtSilentTripEnd = null;
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
    _stopRideStallWatcher();
    await _finishRidePersist();
    _awaitingTelemetryResume = false;
    _freezeAtSilentTripEnd = null;
    _rideAdapterLabel = null;
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
      return ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(
            'OBD-II over Bluetooth Classic is implemented for Android only.\n'
            'Use an Android phone with a paired ELM327 adapter.',
            style: Theme.of(context).textTheme.bodyLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          Text(
            'You can still try ride summaries:',
            style: Theme.of(context).textTheme.titleSmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: () => _saveDemoRide('smooth'),
                icon: const Icon(Icons.directions_car_outlined),
                label: const Text('Demo · smooth'),
              ),
              OutlinedButton.icon(
                onPressed: () => _saveDemoRide('harsh'),
                icon: const Icon(Icons.report_gmailerrorred_outlined),
                label: const Text('Demo · harsh'),
              ),
              FilledButton.icon(
                onPressed: () {
                  Navigator.of(context).push<void>(
                    MaterialPageRoute<void>(
                      builder: (_) => const LastRideReportScreen(),
                    ),
                  );
                },
                icon: const Icon(Icons.history_edu_outlined),
                label: const Text('Last ride'),
              ),
            ],
          ),
        ],
      );
    }

    return ListView(
      padding: const EdgeInsets.only(bottom: 12),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'ELM327 live',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              Tooltip(
                message: 'Save a fake ride to test summaries',
                child: PopupMenuButton<String>(
                  onSelected: (v) => unawaited(_saveDemoRide(v)),
                  itemBuilder: (context) => const [
                    PopupMenuItem(value: 'smooth', child: Text('Demo · smooth')),
                    PopupMenuItem(value: 'harsh', child: Text('Demo · harsh')),
                  ],
                  icon: Icon(
                    Icons.science_outlined,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              OutlinedButton.icon(
                onPressed: () async {
                  await Navigator.of(context).push<void>(
                    MaterialPageRoute<void>(
                      builder: (_) => const LastRideReportScreen(),
                    ),
                  );
                },
                icon: const Icon(Icons.history_edu_outlined),
                label: const Text('Last ride'),
              ),
            ],
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

/// Immutable gauge frame for comparing successive poll snapshots (frozen ECU vs live again).
class _ObdGaugeSnapshot {
  const _ObdGaugeSnapshot({
    required this.speed,
    required this.rpm,
    required this.loadPct,
    required this.coolantC,
    required this.throttlePct,
  });

  final int? speed;
  final double? rpm;
  final double? loadPct;
  final double? coolantC;
  final double? throttlePct;

  static bool sameishInt(int? a, int? b, int eps) {
    if (a == null && b == null) return true;
    if (a == null || b == null) return false;
    return (a - b).abs() < eps;
  }

  static bool sameishDouble(double? a, double? b, double eps) {
    if (a == null && b == null) return true;
    if (a == null || b == null) return false;
    return (a - b).abs() < eps;
  }

  bool gateMeaningfullyChanged(_ObdGaugeSnapshot live) {
    if (_meaningfulGaugeMove(speed?.toDouble(), live.speed?.toDouble(), resumeThSpeedKph)) return true;
    if (_meaningfulGaugeMove(rpm, live.rpm, resumeThRpm)) return true;
    if (_meaningfulGaugeMove(loadPct, live.loadPct, resumeThLoad)) return true;
    if (_meaningfulGaugeMove(coolantC, live.coolantC, resumeThCoolantC)) return true;
    if (_meaningfulGaugeMove(throttlePct, live.throttlePct, resumeThThrottlePct)) return true;
    return false;
  }

  /// Enough change vs the stalled frame to treat as ECM / ignition waking up again (tunable).
  static const double resumeThSpeedKph = 10;
  static const double resumeThRpm = 85;
  static const double resumeThLoad = 15;
  static const double resumeThCoolantC = 3;
  static const double resumeThThrottlePct = 10;

  /// True when the live PID clearly diverged vs the stalled frame, or gauges reappear.
  static bool _meaningfulGaugeMove(double? stalled, double? live, double th) {
    if (stalled != null && live != null && (stalled - live).abs() >= th) return true;
    final stalledNull = stalled == null;
    final liveNull = live == null;
    if ((!stalledNull && liveNull) || (stalledNull && !liveNull)) return true;
    return false;
  }
}