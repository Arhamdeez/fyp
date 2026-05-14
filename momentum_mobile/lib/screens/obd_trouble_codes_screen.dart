/// Read stored MIL / diagnostic trouble codes and clear ECU fault memory over ELM327.
library;

import 'dart:async';

import 'package:flutter/material.dart';

import '../motion/app_motion.dart';
import '../obd/elm_connection.dart';
import '../obd/obd_dtc_parse.dart';

class ObdTroubleCodesScreen extends StatefulWidget {
  const ObdTroubleCodesScreen({
    super.key,
    required this.elm,
  });

  final ElmConnection elm;

  /// Opens with [fadeSlidePageRoute].
  static Future<void> open(
    BuildContext context, {
    required ElmConnection elm,
  }) async {
    await Navigator.of(context).push<void>(
      fadeSlidePageRoute(ObdTroubleCodesScreen(elm: elm)),
    );
  }

  @override
  State<ObdTroubleCodesScreen> createState() => _ObdTroubleCodesScreenState();
}

class _ObdTroubleCodesScreenState extends State<ObdTroubleCodesScreen> {
  final List<String> _buffer = [];
  StreamSubscription<String>? _lineSub;

  List<String> _codes = [];
  bool _busy = false;
  String? _hint;

  @override
  void initState() {
    super.initState();
    _lineSub = widget.elm.lines.listen(_onRawLine);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (mounted && widget.elm.isConnected) {
        await _readStoredDtcs(silentHints: false);
      }
    });
  }

  @override
  void dispose() {
    unawaited(_lineSub?.cancel());
    super.dispose();
  }

  void _onRawLine(String line) {
    final t = line.trim();
    if (t.isEmpty || t.startsWith('>')) return;
    _buffer.add(line);
    if (_buffer.length > 120) {
      _buffer.removeRange(0, _buffer.length - 120);
    }
  }

  Future<void> _readStoredDtcs({bool silentHints = true}) async {
    if (!widget.elm.isConnected) {
      if (mounted) {
        setState(() {
          _codes = [];
          _hint =
              'Not connected to the adapter — go back and tap Connect & read.';
        });
      }
      return;
    }
    setState(() {
      _busy = true;
      _hint = null;
    });

    try {
      _buffer.clear();
      await widget.elm.writeCommand('03');

      await Future<void>.delayed(const Duration(milliseconds: 2800));

      final fresh = _buffer
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();

      var codes = obdParseStoredDtcs(fresh);
      final joined = fresh.join('|').toUpperCase();

      var hint = silentHints
          ? _hint
          : (codes.isEmpty
                  ? 'No stored emissions-related codes parsed (still check pending/pending Mode 07 on workshop tools).'
                  : null);

      if (joined.contains('SEARCHING') && codes.isEmpty) {
        hint ??= 'ECU stayed in SEARCHING — try ignition ON/engine running.';
      }

      if (mounted) {
        setState(() {
          _codes = codes;
          _hint = hint;
          _busy = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _hint =
              'Read failed (${e.toString().replaceFirst('Exception', '').trim()}).';
        });
      }
    }
  }

  Future<bool> _confirmClear() async {
    final ok = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        icon: Icon(
          Icons.warning_amber_rounded,
          color: Theme.of(ctx).colorScheme.error,
          size: 36,
        ),
        title: const Text('Clear all trouble codes & MIL'),
        content: const Text(
          'This sends OBD-II Mode 04 to the ECU: stored fault codes and '
          'the emissions “check engine” light reset after a successful clear.\n\n'
          'Ignition should normally be ON; do not disconnect during the clear.\n\n'
          'Clearing does not repair hardware — faults often come back '
          'if the underlying problem remains.\n'
          'Only continue if that is intentional.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
              foregroundColor: Theme.of(ctx).colorScheme.onError,
            ),
            child: const Text('Clear faults'),
          ),
        ],
      ),
    );
    return ok == true;
  }

  Future<void> _clearDtcs() async {
    if (!widget.elm.isConnected) return;
    if (!await _confirmClear()) return;

    setState(() {
      _busy = true;
      _hint = null;
    });

    try {
      _buffer.clear();
      await widget.elm.writeCommand('04');

      await Future<void>.delayed(const Duration(milliseconds: 2200));

      final fresh = [..._buffer];
      final ok = obdParseClearConfirmed(fresh);

      if (!mounted) return;
      if (ok) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content:
                Text('Clear command acknowledged — re-reading stored list…'),
          ),
        );
        await Future<void>.delayed(const Duration(milliseconds: 600));
        await _readStoredDtcs(silentHints: false);
        if (_codes.isEmpty && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Stored code list appears empty')),
          );
        }
      } else {
        setState(() {
          _busy = false;
          _hint =
              'Adapter did not confirm Mode 04 (try ignition ON, engine idling). '
              'Raw: ${fresh.take(6).join(' | ')}';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _hint = 'Clear failed: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final connected = widget.elm.isConnected;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Check engine · trouble codes'),
        actions: [
          IconButton(
            tooltip: 'Refresh stored codes',
            onPressed: _busy || !connected
                ? null
                : () => _readStoredDtcs(silentHints: false),
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.dashboard_customize_outlined,
                          color: scheme.primary,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            connected
                                ? 'Mode 03 (stored DTCs). Live PID polling pauses until you leave this screen.'
                                : 'Adapter disconnected — reconnect from OBD.',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            if (_busy) const LinearProgressIndicator(),
            const SizedBox(height: 14),
            if (_hint != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  _hint!,
                  style: TextStyle(color: scheme.onSurfaceVariant, height: 1.35),
                ),
              ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: !_busy && connected
                    ? () => _readStoredDtcs(silentHints: false)
                    : () async {},
                child: _codes.isEmpty
                    ? ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        children: [
                          const SizedBox(height: 44),
                          Center(
                            child: Icon(
                              Icons.check_circle_outline,
                              size: 56,
                              color: scheme.outline.withValues(alpha: 0.5),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            _busy
                                ? 'Waiting for adapter…'
                                : 'No stored codes parsed from the last Mode 03 response.',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                  color: scheme.onSurfaceVariant,
                                ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            connected
                                ? 'Pull to refresh — try ignition/engine state your ECU prefers.'
                                : 'Reconnect from the OBD tab.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: scheme.onSurfaceVariant),
                          ),
                        ],
                      )
                    : ListView.separated(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.only(bottom: 24),
                        itemBuilder: (_, i) {
                          final c = _codes[i];
                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor:
                                  scheme.errorContainer.withValues(alpha: 0.9),
                              child: Icon(
                                Icons.code_rounded,
                                color: scheme.onErrorContainer,
                                size: 20,
                              ),
                            ),
                            title: Text(
                              c,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.35,
                              ),
                            ),
                            subtitle: Text(obdBriefDtcHint(c)),
                            isThreeLine: true,
                          );
                        },
                        separatorBuilder: (_, _) => Divider(
                          height: 1,
                          color: scheme.outlineVariant,
                        ),
                        itemCount: _codes.length,
                      ),
              ),
            ),
            const SizedBox(height: 8),
            FilledButton.icon(
              onPressed: _busy || !connected ? null : _clearDtcs,
              icon: const Icon(Icons.delete_sweep_rounded),
              label: const Text('Clear codes / reset MIL (Mode 04)'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                foregroundColor: scheme.onErrorContainer,
                backgroundColor: scheme.errorContainer.withValues(alpha: 0.9),
              ),
            ),
            TextButton.icon(
              onPressed: (_busy || !connected)
                  ? null
                  : () => _readStoredDtcs(silentHints: false),
              icon: const Icon(Icons.cached_rounded),
              label: const Text('Refresh stored codes'),
            ),
          ],
        ),
      ),
    );
  }
}
