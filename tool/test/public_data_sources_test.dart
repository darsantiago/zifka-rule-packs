import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';
import 'package:zifka_rule_packs_tool/public_data_sources.dart';

void main() {
  group('FredClient', () {
    test('uses public graph CSV when an API key is unavailable', () async {
      final client = FredClient(
        httpClient: MockClient((request) async {
          expect(request.url.host, 'fred.stlouisfed.org');
          expect(request.url.path, '/graph/fredgraph.csv');
          expect(request.url.queryParameters['id'], 'DGS10');
          return http.Response(
            'observation_date,DGS10\n2026-08-28,4.20\n2026-08-31,4.25\n',
            200,
          );
        }),
      );

      final observation = await client.latestObservation('DGS10');

      expect(observation?.value, 4.25);
      expect(observation?.period, '2026-08-31');
    });

    test('uses official JSON API when a key is present', () async {
      final client = FredClient(
        apiKey: 'test-key',
        httpClient: MockClient((request) async {
          expect(request.url.host, 'api.stlouisfed.org');
          expect(request.url.queryParameters['api_key'], 'test-key');
          return http.Response(
            jsonEncode({
              'observations': [
                {'date': '2026-08-31', 'value': '4.25'},
              ],
            }),
            200,
          );
        }),
      );

      final observation = await client.latestObservation('DGS10');

      expect(observation?.value, 4.25);
      expect(observation?.period, '2026-08-31');
    });

    test('calculates core CPI as a true year-over-year percentage', () async {
      final rows = <String>['observation_date,CPILFESL'];
      for (var month = 1; month <= 12; month++) {
        rows.add(
          '2025-${month.toString().padLeft(2, '0')}-01,'
          '${month == 8 ? 100 : 95 + month}',
        );
      }
      for (var month = 1; month <= 8; month++) {
        rows.add(
          '2026-${month.toString().padLeft(2, '0')}-01,'
          '${month == 8 ? 105 : 101 + month}',
        );
      }
      final client = FredClient(
        httpClient: MockClient(
          (_) async => http.Response('${rows.join('\n')}\n', 200),
        ),
      );

      final observation = await client.latestYearOverYearPercent('CPILFESL');

      expect(observation?.value, closeTo(5, 0.000001));
      expect(observation?.period, '2026-08-01');
    });
  });

  test('World Bank observation preserves the source year', () async {
    final client = WorldBankClient(
      httpClient: MockClient((request) async {
        expect(request.url.queryParameters['date'], '2022:2026');
        return http.Response(
          jsonEncode([
            {'page': 1},
            [
              {'date': '2026', 'value': null},
              {'date': '2025', 'value': 2.4},
            ],
          ]),
          200,
        );
      }),
    );

    final observation = await client.latestObservation(
      countryIso2: 'CO',
      indicator: 'NY.GDP.MKTP.KD.ZG',
      currentYear: 2026,
    );

    expect(observation?.value, 2.4);
    expect(observation?.period, '2025');
  });

  test('IMF selects the requested year, not the horizon endpoint', () async {
    final client = ImfClient(
      httpClient: MockClient(
        (_) async => http.Response(
          jsonEncode({
            'values': {
              'NGDP_RPCH': {
                'COL': {'2026': 2.8, '2031': 3.4},
              },
            },
          }),
          200,
        ),
      ),
    );

    final observation = await client.observationForYear(
      indicator: 'NGDP_RPCH',
      countryIso3: 'COL',
      year: 2026,
    );

    expect(observation?.value, 2.8);
    expect(observation?.period, '2026');
  });
}
