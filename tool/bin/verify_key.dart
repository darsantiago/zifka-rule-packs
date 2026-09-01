// Quick check that a given Ed25519 private-key seed produces the
// expected public key. Ephemeral tool — not shipped in the workflow.
//
//   dart run tool/bin/verify_key.dart <private_key_path> <expected_pubkey_hex>

import 'dart:convert';
import 'dart:io';

import 'package:cryptography/cryptography.dart';

Future<void> main(List<String> args) async {
  if (args.length != 2) {
    stderr.writeln(
        'usage: dart run tool/bin/verify_key.dart <priv_key_path> <expected_pubkey_hex>');
    exitCode = 64;
    return;
  }
  final raw = File(args[0]).readAsBytesSync();
  List<int> seed =
      raw.length == 32 ? raw : base64Decode(utf8.decode(raw).trim());
  final kp = await Ed25519().newKeyPairFromSeed(seed);
  final pub = await kp.extractPublicKey();
  final hex = pub.bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  print('Derived pubkey: $hex');
  print('Expected:       ${args[1]}');
  print('MATCH: ${hex.toLowerCase() == args[1].toLowerCase()}');
}
