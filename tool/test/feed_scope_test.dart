import 'dart:convert';
import 'dart:io';
import 'package:cryptography/cryptography.dart';
import 'package:test/test.dart';

void main() {
  test('publisher cannot enable excluded providers with a secret or flag', () {
    final producer = File('bin/refresh_feeds.dart').readAsStringSync();
    final workflow =
        File('../.github/workflows/refresh-feeds.yml').readAsStringSync();
    for (final token in [
      'FredClient(',
      'ImfClient(',
      '_fetchFred(',
      '_fetchImf(',
      'FRED_API_KEY',
      'IMF_COMMERCIAL_PERMISSION_CONFIRMED'
    ]) {
      expect(producer, isNot(contains(token)));
      expect(workflow, isNot(contains(token)));
    }
    expect(producer, contains("'kind': 'public_data_feeds'"));
  });
  test('distributed pack is scoped and signed with the existing identity',
      () async {
    final bytes = File('../data_feeds.json').readAsBytesSync();
    final data = jsonDecode(utf8.decode(bytes)) as Map;
    expect(data.containsKey('fred'), isFalse);
    expect(data.containsKey('imf'), isFalse);
    expect(data['kind'], 'public_data_feeds');
    const ids = {
      'NY.GDP.MKTP.CD',
      'NY.GDP.MKTP.KD.ZG',
      'FP.CPI.TOTL.ZG',
      'SL.UEM.TOTL.ZS',
      'GC.DOD.TOTL.GD.ZS'
    };
    for (final country in (data['worldBank'] as Map).values) {
      expect((country as Map).values.map((v) => v['indicator']).toSet(), ids);
    }
    const hex =
        'adc008715d83d3774236508c3d592c3eacc0ce6a2f3e05facea40bee334052e5';
    final key = SimplePublicKey([
      for (int i = 0; i < hex.length; i += 2)
        int.parse(hex.substring(i, i + 2), radix: 16)
    ], type: KeyPairType.ed25519);
    final signature =
        base64Decode(File('../data_feeds.json.sig').readAsStringSync().trim());
    expect(
        await Ed25519()
            .verify(bytes, signature: Signature(signature, publicKey: key)),
        isTrue);
  });
}
