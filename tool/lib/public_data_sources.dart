import 'dart:convert';

import 'package:http/http.dart' as http;

/// A scalar value plus the source period that makes it auditable.
class PublicDataObservation {
  final double value;
  final String period;

  const PublicDataObservation({required this.value, required this.period});
}

/// Federal Reserve Economic Data — Federal Reserve Bank of St. Louis.
///
/// The official JSON API requires an API key. Scheduled refreshes without a
/// key use FRED's public graph CSV endpoint instead.
class FredClient {
  final http.Client _http;
  final String? apiKey;

  FredClient({http.Client? httpClient, this.apiKey})
      : _http = httpClient ?? http.Client();

  bool get _hasApiKey => apiKey?.trim().isNotEmpty == true;

  Future<PublicDataObservation?> latestObservation(String seriesId) async {
    final observations = await _observations(seriesId, limit: 1);
    return observations.isEmpty ? null : observations.first;
  }

  /// Calculates the latest month-over-same-month-last-year change.
  Future<PublicDataObservation?> latestYearOverYearPercent(
    String seriesId,
  ) async {
    final observations = await _observations(seriesId, limit: 18);
    if (observations.length < 13) return null;

    final latest = observations.first;
    final latestDate = DateTime.tryParse(latest.period);
    if (latestDate == null) return null;
    final priorPeriod = DateTime.utc(latestDate.year - 1, latestDate.month);
    PublicDataObservation? prior;
    for (final observation in observations.skip(1)) {
      final date = DateTime.tryParse(observation.period);
      if (date != null &&
          date.year == priorPeriod.year &&
          date.month == priorPeriod.month) {
        prior = observation;
        break;
      }
    }
    if (prior == null || prior.value == 0) return null;
    return PublicDataObservation(
      value: ((latest.value / prior.value) - 1) * 100,
      period: latest.period,
    );
  }

  Future<double?> latestValue(String seriesId) async =>
      (await latestObservation(seriesId))?.value;

  Future<List<PublicDataObservation>> _observations(
    String seriesId, {
    required int limit,
  }) async {
    if (_hasApiKey) {
      final url = Uri.https(
        'api.stlouisfed.org',
        '/fred/series/observations',
        <String, String>{
          'series_id': seriesId,
          'file_type': 'json',
          'api_key': apiKey!.trim(),
          'sort_order': 'desc',
          'limit': '$limit',
        },
      );
      final response = await _http.get(url);
      if (response.statusCode != 200) return const [];
      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      final rows = decoded['observations'] as List?;
      if (rows == null) return const [];
      return _parseJsonRows(rows);
    }

    final url = Uri.https(
      'fred.stlouisfed.org',
      '/graph/fredgraph.csv',
      <String, String>{'id': seriesId},
    );
    final response = await _http.get(url);
    if (response.statusCode != 200) return const [];
    final lines = const LineSplitter().convert(response.body);
    final observations = <PublicDataObservation>[];
    for (final line in lines.skip(1)) {
      final separator = line.indexOf(',');
      if (separator <= 0) continue;
      final period = line.substring(0, separator).trim();
      final value = double.tryParse(line.substring(separator + 1).trim());
      if (value != null) {
        observations.add(PublicDataObservation(value: value, period: period));
      }
    }
    return observations.reversed.take(limit).toList(growable: false);
  }

  List<PublicDataObservation> _parseJsonRows(List<dynamic> rows) {
    final observations = <PublicDataObservation>[];
    for (final row in rows.whereType<Map<String, dynamic>>()) {
      final value = double.tryParse(row['value']?.toString() ?? '');
      final period = row['date']?.toString();
      if (value != null && period != null && period.isNotEmpty) {
        observations.add(PublicDataObservation(value: value, period: period));
      }
    }
    return observations;
  }

  void close() => _http.close();
}

/// World Bank Open Data — public JSON API, no key.
class WorldBankClient {
  final http.Client _http;

  WorldBankClient({http.Client? httpClient})
      : _http = httpClient ?? http.Client();

  Future<PublicDataObservation?> latestObservation({
    required String countryIso2,
    required String indicator,
    int lookbackYears = 4,
    int? currentYear,
  }) async {
    final now = currentYear ?? DateTime.now().toUtc().year;
    final url = Uri.parse(
      'https://api.worldbank.org/v2/country/$countryIso2/indicator/$indicator'
      '?format=json&date=${now - lookbackYears}:$now&per_page=100',
    );
    final response = await _http.get(url);
    if (response.statusCode != 200) return null;
    final decoded = jsonDecode(response.body);
    if (decoded is! List || decoded.length < 2 || decoded[1] is! List) {
      return null;
    }
    for (final row in (decoded[1] as List).whereType<Map<String, dynamic>>()) {
      final value = row['value'];
      final period = row['date']?.toString();
      if (value is num && period != null && period.isNotEmpty) {
        return PublicDataObservation(
          value: value.toDouble(),
          period: period,
        );
      }
    }
    return null;
  }

  Future<double?> latestValue({
    required String countryIso2,
    required String indicator,
    int lookbackYears = 4,
  }) async =>
      (await latestObservation(
        countryIso2: countryIso2,
        indicator: indicator,
        lookbackYears: lookbackYears,
      ))
          ?.value;

  void close() => _http.close();
}

/// IMF DataMapper — public REST API, no key.
class ImfClient {
  final http.Client _http;

  ImfClient({http.Client? httpClient}) : _http = httpClient ?? http.Client();

  /// Returns the requested year instead of silently selecting the farthest
  /// forecast in the WEO horizon.
  Future<PublicDataObservation?> observationForYear({
    required String indicator,
    required String countryIso3,
    int? year,
  }) async {
    final targetYear = year ?? DateTime.now().toUtc().year;
    final url = Uri.parse(
      'https://www.imf.org/external/datamapper/api/v1/$indicator/$countryIso3',
    );
    final response = await _http.get(url);
    if (response.statusCode != 200) return null;
    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final values = decoded['values'] as Map<String, dynamic>?;
    final series = values?[indicator] as Map<String, dynamic>?;
    final country = series?[countryIso3] as Map<String, dynamic>?;
    final value = country?['$targetYear'];
    if (value is! num) return null;
    return PublicDataObservation(
      value: value.toDouble(),
      period: '$targetYear',
    );
  }

  Future<double?> latestValue({
    required String indicator,
    required String countryIso3,
  }) async =>
      (await observationForYear(
        indicator: indicator,
        countryIso3: countryIso3,
      ))
          ?.value;

  void close() => _http.close();
}

/// SEC EDGAR — public JSON API, no key. Requires a descriptive User-Agent.
class EdgarClient {
  static const _userAgent =
      'Saribot SAS Valuation Suite data-feed / darsantiago@gmail.com';

  final http.Client _http;

  EdgarClient({http.Client? httpClient}) : _http = httpClient ?? http.Client();

  Future<List<Map<String, dynamic>>> companyTickers() async {
    final url = Uri.parse('https://www.sec.gov/files/company_tickers.json');
    final response = await _http.get(url, headers: {'User-Agent': _userAgent});
    if (response.statusCode != 200) return const [];
    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    return decoded.values
        .whereType<Map<String, dynamic>>()
        .toList(growable: false);
  }

  void close() => _http.close();
}
