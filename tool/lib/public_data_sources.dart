import 'dart:convert';

import 'package:http/http.dart' as http;

/// Free public data sources this repo re-serves as signed packs.
/// Every source below is either public-domain (US federal government
/// output), openly-licensed with attribution (World Bank, IMF), or
/// educational/informational per the source's own terms (Damodaran).

/// Federal Reserve Economic Data — St Louis Fed.
/// FRED requires no API key for the JSON `fred/series/observations`
/// endpoint IF the `api_key` is omitted (rate-limited; enough for our
/// bi-daily refresh cadence). For production runs, GitHub Actions
/// injects `FRED_API_KEY` from Secrets.
class FredClient {
  final http.Client _http;
  final String? apiKey;
  FredClient({http.Client? httpClient, this.apiKey})
      : _http = httpClient ?? http.Client();

  /// Latest observation for a series (e.g. DGS10 for the 10-year yield).
  Future<double?> latestValue(String seriesId) async {
    final url = Uri.parse(
      'https://api.stlouisfed.org/fred/series/observations'
      '?series_id=$seriesId&file_type=json'
      '${apiKey == null ? '' : '&api_key=$apiKey'}'
      '&sort_order=desc&limit=1',
    );
    final resp = await _http.get(url);
    if (resp.statusCode != 200) return null;
    final json = jsonDecode(resp.body) as Map<String, dynamic>;
    final obs = json['observations'] as List?;
    if (obs == null || obs.isEmpty) return null;
    final value = obs.first['value']?.toString();
    if (value == null || value == '.' || value.isEmpty) return null;
    return double.tryParse(value);
  }

  void close() => _http.close();
}

/// World Bank Open Data — public JSON API, no key.
/// Ex: `NY.GDP.MKTP.CD` for GDP current USD; `FP.CPI.TOTL.ZG` for
/// inflation; `CC.EST` for Governance Control-of-Corruption estimate.
class WorldBankClient {
  final http.Client _http;
  WorldBankClient({http.Client? httpClient})
      : _http = httpClient ?? http.Client();

  /// Latest available value for a country + indicator, going back up
  /// to [lookbackYears] years so we cope with the reporting lag.
  Future<double?> latestValue({
    required String countryIso2,
    required String indicator,
    int lookbackYears = 4,
  }) async {
    final now = DateTime.now().year;
    final url = Uri.parse(
      'https://api.worldbank.org/v2/country/$countryIso2/indicator/$indicator'
      '?format=json&date=${now - lookbackYears}:$now&per_page=100',
    );
    final resp = await _http.get(url);
    if (resp.statusCode != 200) return null;
    final decoded = jsonDecode(resp.body);
    if (decoded is! List || decoded.length < 2) return null;
    final rows = decoded[1] as List;
    for (final row in rows) {
      final v = (row as Map<String, dynamic>)['value'];
      if (v is num) return v.toDouble();
    }
    return null;
  }

  void close() => _http.close();
}

/// IMF DataMapper — public REST API, no key. WEO for forecasts, IFS
/// for cross-country macro.
class ImfClient {
  final http.Client _http;
  ImfClient({http.Client? httpClient}) : _http = httpClient ?? http.Client();

  /// Latest scalar from the IMF DataMapper API. `indicator` is an IMF
  /// series code (e.g. NGDP_RPCH for real GDP growth); `countryIso3`
  /// is the ISO 3-letter country code.
  Future<double?> latestValue({
    required String indicator,
    required String countryIso3,
  }) async {
    final url = Uri.parse(
      'https://www.imf.org/external/datamapper/api/v1/$indicator/$countryIso3',
    );
    final resp = await _http.get(url);
    if (resp.statusCode != 200) return null;
    final decoded = jsonDecode(resp.body) as Map<String, dynamic>;
    final values = decoded['values'] as Map<String, dynamic>?;
    if (values == null || values.isEmpty) return null;
    final series = values[indicator] as Map<String, dynamic>?;
    final country = series?[countryIso3] as Map<String, dynamic>?;
    if (country == null || country.isEmpty) return null;
    // Pick the latest year with a numeric value.
    final years = country.keys.toList()..sort();
    for (final year in years.reversed) {
      final v = country[year];
      if (v is num) return v.toDouble();
    }
    return null;
  }

  void close() => _http.close();
}

/// SEC EDGAR — public JSON API, no key. Requires a User-Agent per SEC
/// fair-use policy (`Sample Company Name AdminContact@<domain>.com`).
class EdgarClient {
  static const _userAgent =
      'Saribot SAS Valuation Suite data-feed / darsantiago@gmail.com';

  final http.Client _http;
  EdgarClient({http.Client? httpClient})
      : _http = httpClient ?? http.Client();

  /// The `company_tickers.json` list — one row per ticker + CIK + title.
  /// Used to build a public comps index the app can filter by ticker
  /// without ever calling SEC EDGAR at runtime.
  Future<List<Map<String, dynamic>>> companyTickers() async {
    final url = Uri.parse('https://www.sec.gov/files/company_tickers.json');
    final resp = await _http.get(url, headers: {'User-Agent': _userAgent});
    if (resp.statusCode != 200) return const [];
    final decoded = jsonDecode(resp.body) as Map<String, dynamic>;
    // Keys are numeric indices; values are {cik_str, ticker, title}.
    return decoded.values
        .whereType<Map<String, dynamic>>()
        .toList(growable: false);
  }

  void close() => _http.close();
}
