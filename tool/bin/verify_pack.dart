// Verify a pack's Ed25519 signature against a public key hex — the
// same operation the mobile app performs at fetch time. Ephemeral.
//
//   dart run tool/bin/verify_pack.dart <pack.json> <pack.json.sig> <pubkey_hex>

import 'dart:convert';
import 'dart:io';

import 'package:cryptography/cryptography.dart';

Future<void> main(List<String> args) async {
  if (args.length != 3) {
    stderr.writeln('usage: dart run tool/bin/verify_pack.dart <pack> <sig> <pubkey_hex>');
    exitCode = 64;
    return;
  }
  final payload = File(args[0]).readAsBytesSync();
  final sig = base64Decode(File(args[1]).readAsStringSync().trim());
  final hex = args[2];
  final pub = SimplePublicKey(
    List<int>.generate(hex.length ~/ 2,
        (i) => int.parse(hex.substring(i * 2, i * 2 + 2), radix: 16)),
    type: KeyPairType.ed25519,
  );
  final ok = await Ed25519().verify(payload, signature: Signature(sig, publicKey: pub));
  print('VERIFY: ${ok ? "OK" : "FAIL"}');
  exitCode = ok ? 0 : 1;
}
