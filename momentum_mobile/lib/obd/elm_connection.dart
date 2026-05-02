import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';

/// Classic Bluetooth SPP link to an ELM327 adapter (common for USB-style ELM327 clones).
class ElmConnection {
  BluetoothConnection? _connection;
  StreamSubscription<Uint8List>? _subscription;
  String _partial = '';
  final StreamController<String> _lineController = StreamController<String>.broadcast();

  /// Called when the RFCOMM link drops (dongle sleep, out of range, ignition off, etc.).
  void Function()? onDisconnected;

  Stream<String> get lines => _lineController.stream;

  bool get isConnected => _connection?.isConnected ?? false;

  void _onData(Uint8List data) {
    _partial += ascii.decode(data, allowInvalid: true);
    while (true) {
      final i = _partial.indexOf('\r');
      if (i < 0) break;
      final line = _partial.substring(0, i).trim();
      _partial = _partial.substring(i + 1);
      if (line.isEmpty) continue;
      if (!_lineController.isClosed) {
        _lineController.add(line);
      }
    }
  }

  Future<void> connect(String address) async {
    await disconnect();
    _connection = await BluetoothConnection.toAddress(address);
    _subscription = _connection!.input!.listen(
      _onData,
      onError: (_) => disconnect(),
      onDone: disconnect,
      cancelOnError: true,
    );
  }

  Future<void> writeRaw(String s) async {
    final c = _connection;
    if (c == null || !c.isConnected) {
      throw StateError('Not connected to OBD adapter');
    }
    c.output.add(Uint8List.fromList(ascii.encode(s)));
    await c.output.allSent;
  }

  /// Sends one ELM327 command (CR terminator added).
  Future<void> writeCommand(String command) => writeRaw('$command\r');

  /// [notifyListeners] false when the app user chose to disconnect (no "lost link" toast).
  Future<void> disconnect({bool notifyListeners = true}) async {
    final wasConnected = isConnected;
    await _subscription?.cancel();
    _subscription = null;
    await _connection?.close();
    _connection = null;
    _partial = '';
    if (wasConnected && notifyListeners) {
      onDisconnected?.call();
    }
  }

  Future<void> dispose() async {
    await disconnect(notifyListeners: false);
    if (!_lineController.isClosed) {
      await _lineController.close();
    }
  }
}
