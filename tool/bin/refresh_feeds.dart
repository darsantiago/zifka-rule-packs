import 'dart:convert';
import 'dart:io';

import '../lib/public_data_sources.dart';

/// Assemble the `data_feeds.json` pack from public, license-clean
/// sources: FRED (US Treasury rates), World Bank (macro), IMF (WEO),
/// SEC EDGAR (US company tickers index).
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
  final outputPath =
      args.isEmpty ? 'data_feeds.json' : args.first;

  stdout.writeln('▶ Fetching Federal Reserve series…');
  final fred = FredClient(apiKey: Platform.environment['FRED_API_KEY']);
  final fredData = await _fetchFred(fred);
  fred.close();

  stdout.writeln('▶ Fetching World Bank indicators…');
  final wb = WorldBankClient();
  final wbData = await _fetchWorldBank(wb);
  wb.close();

  stdout.writeln('▶ Fetching IMF WEO forecasts…');
  final imf = ImfClient();
  final imfData = await _fetchImf(imf);
  imf.close();

  stdout.writeln('▶ Fetching SEC EDGAR company tickers…');
  final edgar = EdgarClient();
  final edgarTickers = await edgar.companyTickers();
  edgar.close();

  // Read the previous version for a monotonic bump — never regress.
  final previous = _readPreviousVersion(outputPath);
  final nextVersion = previous + 1;

  final now = DateTime.now().toUtc();
  final pack = <String, dynamic>{
    'schemaVersion': 1,
    'version': nextVersion,
    'publishedAt': now.toIso8601String(),
    'attribution': {
      'fred':
          'St Louis Fed FRED series (public domain — US federal government output).',
      'worldBank':
          'World Bank Open Data (Creative Commons Attribution 4.0 International).',
      'imf':
          'IMF DataMapper API — © IMF, referenced under fair-use with attribution.',
      'secEdgar':
          'SEC EDGAR company tickers — public domain (US federal government output).',
    },
    'fred': fredData,
    'worldBank': wbData,
    'imf': imfData,
    'edgar': {
      'tickerCount': edgarTickers.length,
      // We ship only the top ~500 by CIK to keep the pack small; the app
      // can request more from the app-tier live-data path if it needs.
      'topTickers': edgarTickers.take(500).toList(growable: false),
    },
  };

  final json = const JsonEncoder.withIndent('  ').convert(pack);
  File(outputPath).writeAsStringSync('$json\n');
  stdout.writeln('✔ Wrote $outputPath (v$nextVersion, published $now)');
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

/// FRED series we ship. Kept intentionally small — this is a reference
/// feed the app hydrates from, not a full data warehouse.
Future<Map<String, dynamic>> _fetchFred(FredClient fred) async {
  final series = <String, String>{
    'us10YearYield': 'DGS10',
    'us3MonthYield': 'DGS3MO',
    'us3MonthTBill': 'DTB3',
    'usInflationExpectation10Y': 'T10YIE',
    'fedFundsRate': 'FEDFUNDS',
    'usCoreCpiYoy': 'CPILFESL',
  };
  final out = <String, dynamic>{};
  for (final entry in series.entries) {
    try {
      final v = await fred.latestValue(entry.value);
      out[entry.key] = {
        'seriesId': entry.value,
        'value': v,
      };
      stdout.writeln('  • ${entry.value} = $v');
    } catch (e) {
      stderr.writeln('  ! ${entry.value} failed: $e');
      out[entry.key] = {'seriesId': entry.value, 'value': null};
    }
  }
  return out;
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
      final v = await wb.latestValue(
        countryIso2: country,
        indicator: entry.value,
      );
      row[entry.key] = {'indicator': entry.value, 'value': v};
    }
    out[country] = row;
    stdout.writeln('  • $country done');
  }
  return out;
}

/// IMF WEO real-GDP-growth forecast for the priority EM markets.
Future<Map<String, dynamic>> _fetchImf(ImfClient imf) async {
  const iso3ByIso2 = <String, String>{
    'MX': 'MEX',
    'BR': 'BRA',
    'IN': 'IND',
    'CO': 'COL',
    'NG': 'NGA',
    'ID': 'IDN',
  };
  final out = <String, dynamic>{};
  for (final entry in iso3ByIso2.entries) {
    try {
      final v = await imf.latestValue(
        indicator: 'NGDP_RPCH',
        countryIso3: entry.value,
      );
      out[entry.key] = {'indicator': 'NGDP_RPCH', 'value': v};
      stdout.writeln('  • ${entry.value} NGDP_RPCH = $v');
    } catch (e) {
      stderr.writeln('  ! ${entry.value} failed: $e');
      out[entry.key] = {'indicator': 'NGDP_RPCH', 'value': null};
    }
  }
  return out;
}
