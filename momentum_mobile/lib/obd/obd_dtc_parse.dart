/// Parse OBD-II Mode 03 (stored DTCs) & Mode 04 (clear confirmation) payloads.
library;

/// Extract raw bytes from ELM/Ecu response fragments (space / newline / ':' separated).
List<int> obdExtractHexBytes(String input) {
  final cleaned = input.replaceAll(RegExp(r'[^0-9A-Fa-f\s]'), '');
  final matches = RegExp(r'[0-9A-F]{2}', caseSensitive: false).allMatches(cleaned);
  return [
    for (final m in matches) int.tryParse(m.group(0)!, radix: 16) ?? -1,
  ].where((b) => b >= 0).toList();
}

/// Converts two ECU payload bytes → single DTC (e.g. P0420).
String obdDecodeDtcPair(int hi, int lo) {
  const systems = ['P', 'C', 'B', 'U'];
  const hexDigits = '0123456789ABCDEF';
  final system = systems[(hi >> 6) & 3];
  final d1 = (hi >> 4) & 0x03;
  final d2 = hi & 0x0F;
  final d3 = (lo >> 4) & 0x0F;
  final d4 = lo & 0x0F;
  return '$system$d1'
      '${hexDigits[d2 & 15]}${hexDigits[d3 & 15]}${hexDigits[d4 & 15]}';
}

/// Parses buffered lines after ISO `03` (stored diagnostic trouble codes).
///
/// Finds the Mode 03 positive response suffix `43` followed by `[DTC_hi,DTC_lo]…`
/// pairs. Leading CAN headers are ignored because we strip to raw nibbles.
List<String> obdParseStoredDtcs(List<String> lines) {
  final text = lines.join('\n').toUpperCase();
  if (text.contains('UNABLE') ||
      text.contains('CAN ERROR') ||
      text.contains('BUS INIT')) {
    return [];
  }
  if (!text.contains('43') &&
      RegExp(r'NO\s*DATA').hasMatch(text)) {
    return [];
  }

  final bytes = obdExtractHexBytes(text);

  final idx43 = bytes.indexOf(0x43);
  if (idx43 < 0) {
    return [];
  }

  var i = idx43 + 1;
  final out = <String>[];
  while (i + 1 < bytes.length) {
    final hi = bytes[i];
    final lo = bytes[i + 1];
    i += 2;
    if (hi == 0 && lo == 0) continue;
    out.add(obdDecodeDtcPair(hi, lo));
    if (out.length > 48) break;
  }

  return _uniq(out);
}

List<String> _uniq(List<String> codes) {
  final seen = <String>{};
  return [for (final c in codes) if (seen.add(c)) c];
}

/// True when response likely confirms Mode 04 (clear DTC memory / MIL).
bool obdParseClearConfirmed(List<String> lines) {
  final u = lines.join('\n').toUpperCase().trim();
  if (u.contains('ERROR') ||
      u.contains('UNABLE') ||
      u.contains('CAN ERROR')) {
    return false;
  }
  if (RegExp(r'\b44\b').hasMatch(u)) return true;
  final bytes = obdExtractHexBytes(u);
  return bytes.contains(0x44);
}

/// Optional short hint shown under a code row.
String obdBriefDtcHint(String code) {
  const hints = <String, String>{
    'P0420':
        'Catalyst efficiency — often O₂ sensors or converter (confirm with a workshop scan after repair).',
    'P0440':
        'Evaporative emissions — cap, hoses, purge valve leaks are common culprits.',
    'P0300':
        'Random misfire — inspect plugs/coils/leaks/fuel before heavy driving.',
    'P0171': 'Fuel trim lean — vacuum leak, airflow, or oxygen sensor faults.',
    'P0172': 'Fuel trim rich — fuel pressure or leaking injector/airflow faults.',
    'P0135': 'O₂ sensor heater circuit (wiring/fuse/sensor).',
    'P0128': 'Coolant temp / thermostat not reaching temperature in time.',
    'U0100': 'Network — lost talk with a module (connectors/power).',
    'P0442': 'Small EVAP leak.',
    'P0455': 'Large EVAP leak — check fuel cap seal first.',
  };
  final key = code.toUpperCase().trim();
  return hints[key] ??
      'Look up this code for your vehicle. Fix the root cause — clearing alone '
      'will not repair hardware faults.';
}
