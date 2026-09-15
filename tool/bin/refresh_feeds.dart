import 'dart:convert';
import 'dart:io';

import '../lib/public_data_sources.dart';

/// Assemble the `data_feeds.json` pack from selected public sources:
/// Only the five reviewed World Bank indicators and SEC ticker metadata.
/// Direct FRED/IMF sources are excluded; environment flags cannot enable them.
///
/// Usage:
///   dart run tool/bin/refresh_feeds.dart <output_path>
///
/// Then sign it:
///   dart run tool/bin/sign_pack.dart <private.key> <output_path>
///
/// Both invocations are what `.github/workflows/refresh-feeds.yml`
/// executes on a weekly cron. The private key comes from GitHub
/// Actions Secrets and never lands on disk of a shared runner.
Future<void> main(List<String> args) async {
  final outputPath = args.isEmpty ? 'data_feeds.json' : args.first;

  stdout.writeln('▶ Fetching World Bank indicators…');
  final wb = WorldBankClient();
  final wbData = await _fetchWorldBank(wb);
  wb.close();

  stdout.writeln('▶ Fetching SEC EDGAR company tickers…');
  final edgar = EdgarClient();
  final edgarTickers = await edgar.companyTickers();
  edgar.close();

  // Read the previous version for a monotonic bump — never regress.
  final previous = _readPreviousVersion(outputPath);
  final nextVersion = previous + 1;

  final now = DateTime.now().toUtc();
  final pack = <String, dynamic>{
    'schemaVersion': 2,
    'kind': 'public_data_feeds',
    'version': nextVersion,
    'publishedAt': now.toIso8601String(),
    'attribution': {
      'worldBank':
          'World Bank Open Data (Creative Commons Attribution 4.0 International).',
      'secEdgar':
          'SEC EDGAR company tickers. Cite the SEC; reuse does not imply SEC endorsement.',
    },
    'usageNotice':
        'Public-source reference data. Verify source terms, observation periods, and suitability before professional use.',
    'worldBank': wbData,
    'edgar': {
      'tickerCount': edgarTickers.length,
      // The first 500 entries in SEC source order; no valuation/quote data.
      'topTickers': edgarTickers.take(500).toList(growable: false),
    },
  };

  final json = const JsonEncoder.withIndent('  ').convert(pack);
  File(outputPath).writeAsStringSync('$json\n');
  stdout.writeln('✔ Wrote $outputPath (v$nextVersion, published $now)');
}

/// Plausibility bands per feed key. An Ed25519 signature proves the pack
/// came from this pipeline — not that a source API returned a sane number.
/// A bad point is dropped to `null` (with a log line) instead of shipping,
/// so one glitch never invalidates the whole weekly pack on the client.
const Map<String, (double, double)> _plausibleRanges = {
  // Percent-style series.
  'gdpGrowthAnnual': (-60, 100),
  'inflationCpiYoy': (-30, 1000),
  'unemploymentPct': (0, 100),
  'governmentDebtPctGdp': (0, 500),
  // Absolute USD.
  'gdpUsdCurrent': (0, 1e15),
};

double? _sanitize(String key, double? value, {String? context}) {
  if (value == null) return null;
  final range = _plausibleRanges[key];
  final label = context == null ? key : '$context.$key';
  if (!value.isFinite) {
    stderr.writeln('  ! $label dropped: non-finite value $value');
    return null;
  }
  if (range != null && (value < range.$1 || value > range.$2)) {
    stderr.writeln(
      '  ! $label dropped: $value outside plausible band [${range.$1}, ${range.$2}]',
    );
    return null;
  }
  return value;
}

int _readPreviousVersion(String path) {
  final file = File(path);
  if (!file.existsSync()) return 0;
  try {
    final json = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
    final v = json['version'];
    return v is int ? v : 0;
  } catch (_) {
    return 0;
  }
}

/// World Bank macros for the 6 priority EM markets (matches the app's
/// [MarketKey] enum in sector_defaults.dart).
Future<Map<String, dynamic>> _fetchWorldBank(WorldBankClient wb) async {
  const priorityMarkets = <String>['MX', 'BR', 'IN', 'CO', 'NG', 'ID'];
  const indicators = <String, String>{
    'gdpUsdCurrent': 'NY.GDP.MKTP.CD',
    'gdpGrowthAnnual': 'NY.GDP.MKTP.KD.ZG',
    'inflationCpiYoy': 'FP.CPI.TOTL.ZG',
    'unemploymentPct': 'SL.UEM.TOTL.ZS',
    'governmentDebtPctGdp': 'GC.DOD.TOTL.GD.ZS',
  };
  final out = <String, dynamic>{};
  for (final country in priorityMarkets) {
    final row = <String, dynamic>{};
    for (final entry in indicators.entries) {
      final observation = await wb.latestObservation(
        countryIso2: country,
        indicator: entry.value,
      );
      row[entry.key] = {
        'indicator': entry.value,
        'value': _sanitize(entry.key, observation?.value, context: country),
        'period': observation?.period,
      };
    }
    out[country] = row;
    stdout.writeln('  • $country done');
  }
  return out;
}
