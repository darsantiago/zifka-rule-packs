import 'dart:convert';
import 'dart:io';

import 'package:cryptography/cryptography.dart';

/// Sign a JSON pack file with an Ed25519 private key and write a
/// detached signature next to it. Zero dependencies on private
/// infrastructure: the private key path comes as an argument (typically
/// piped from GitHub Actions Secrets in CI), the pack path is the file
/// we want to sign, and the signature lands as `<pack>.sig`.
///
/// Usage:
///   dart run tool/bin/sign_pack.dart <private_key_path> <pack.json>
///
/// The signature is base64-encoded to match the app's
/// `SignedRulePackService.verify()` expectations.
Future<void> main(List<String> args) async {
  if (args.length != 2) {
    stderr.writeln(
      'usage: dart run tool/bin/sign_pack.dart <private_key_path> <pack.json>',
    );
    exitCode = 64;
    return;
  }
  final privateKeyPath = args[0];
  final packPath = args[1];

  final privateKeyBytes = _readPrivateKeyBytes(File(privateKeyPath));
  if (privateKeyBytes == null) {
    stderr.writeln('Private key at $privateKeyPath is not 32-byte Ed25519 seed.');
    exitCode = 65;
    return;
  }

  final packBytes = File(packPath).readAsBytesSync();

  final algo = Ed25519();
  final keyPair = await algo.newKeyPairFromSeed(privateKeyBytes);
  final signature = await algo.sign(packBytes, keyPair: keyPair);
  final sigB64 = base64Encode(signature.bytes);

  final sigPath = '$packPath.sig';
  File(sigPath).writeAsStringSync(sigB64);
  stdout.writeln('Signed $packPath → $sigPath (${sigB64.length} bytes)');
}

/// Accepts either raw 32 bytes or a base64-encoded seed. Rejects anything
/// else so we fail fast if the wrong file gets piped in from CI.
List<int>? _readPrivateKeyBytes(File keyFile) {
  final raw = keyFile.readAsBytesSync();
  if (raw.length == 32) return raw;
  try {
    final decoded = base64Decode(utf8.decode(raw).trim());
    if (decoded.length == 32) return decoded;
  } catch (_) {
    // fall through
  }
  return null;
}
