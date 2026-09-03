// The wire: JSON shapes, request signing, and the pairing key derivation. Shared by the host
// server and the client, and by both transports.
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

const String kApiPrefix = '/v1';
const int kProtocolVersion = 1;
const Duration kAuthSkew = Duration(minutes: 5);
const Duration kPairingWindow = Duration(minutes: 10);
const int kMaxPushBatch = 200;
const int kMaxPullBatch = 500;

/// 256 plain words; six of them carry 48 bits, read out loud once.
const List<String> kPairingWords = [
  'apple', 'arrow', 'bake', 'barn', 'beach', 'bell', 'bird', 'blanket', 'boat', 'book', 'bottle', 'bread',
  'brick', 'bridge', 'broom', 'brush', 'bucket', 'butter', 'button', 'cabin', 'candle', 'canal', 'card',
  'carpet', 'carrot', 'cellar', 'chair', 'chalk', 'cheese', 'cherry', 'clock', 'cloud', 'coat', 'coin',
  'comb', 'copper', 'corner', 'cotton', 'cup', 'curtain', 'desk', 'door', 'drawer', 'drum', 'duck', 'eagle',
  'engine', 'fence', 'ferry', 'field', 'flag', 'flour', 'flute', 'fog', 'forest', 'fork', 'fox', 'frost',
  'garden', 'gate', 'glass', 'glove', 'goat', 'grape', 'gravel', 'hammer', 'harbour', 'hat', 'hedge', 'hill',
  'honey', 'hook', 'horse', 'iron', 'island', 'ivy', 'jar', 'jacket', 'kettle', 'key', 'kite', 'knot',
  'ladder', 'lamp', 'lantern', 'leaf', 'lemon', 'letter', 'lily', 'lime', 'linen', 'lock', 'loom', 'magnet',
  'map', 'marble', 'meadow', 'melon', 'mill', 'mirror', 'moss', 'moth', 'mountain', 'mug', 'nail', 'needle',
  'nest', 'net', 'oak', 'oar', 'olive', 'onion', 'orchard', 'otter', 'oven', 'owl', 'paddle', 'pail', 'paper',
  'peach', 'pear', 'pebble', 'pen', 'pencil', 'pepper', 'piano', 'pillow', 'pine', 'plate', 'plum', 'pocket',
  'pond', 'poppy', 'quilt', 'rabbit', 'radio', 'rain', 'ribbon', 'river', 'road', 'robin', 'rope', 'rose',
  'rug', 'saddle', 'sail', 'salt', 'sand', 'scarf', 'school', 'shell', 'ship', 'shoe', 'silk', 'silver',
  'sleeve', 'snow', 'soap', 'sock', 'sofa', 'spoon', 'stair', 'stamp', 'star', 'stone', 'stool', 'storm',
  'straw', 'string', 'sugar', 'summer', 'sun', 'table', 'tape', 'tea', 'tent', 'thread', 'ticket', 'tide',
  'timber', 'toast', 'tower', 'train', 'tulip', 'tunnel', 'valley', 'vase', 'velvet', 'village', 'violin',
  'wagon', 'wall', 'walnut', 'water', 'wax', 'wheat', 'wheel', 'whistle', 'willow', 'window', 'wing',
  'winter', 'wire', 'wolf', 'wood', 'wool', 'yard', 'yarn', 'zebra', 'zinc', 'acorn', 'amber', 'anchor',
  'attic', 'badge', 'basket', 'bench', 'berry', 'birch', 'bonnet', 'branch', 'buckle', 'cable', 'canvas',
  'castle', 'cedar', 'chimney', 'cliff', 'clover', 'compass', 'cradle', 'crane', 'creek', 'crumb', 'daisy',
  'dune', 'ember', 'fern', 'fiddle', 'flint', 'gable', 'garlic', 'ginger', 'goose', 'harp', 'hazel',
  'heron', 'ink', 'juniper', 'kelp', 'lark', 'latch', 'lodge', 'maple', 'mast', 'nutmeg', 'orbit',
  'pantry', 'parcel', 'pier', 'plough', 'quill', 'reed', 'saucer', 'shingle', 'slate', 'sparrow', 'spool',
];

List<String> mintPairingWords([Random? random]) {
  final r = random ?? Random.secure();
  return List<String>.generate(6, (_) => kPairingWords[r.nextInt(kPairingWords.length)]);
}

String normaliseWords(String spoken) =>
    spoken.toLowerCase().replaceAll(RegExp(r'[^a-z ]'), ' ').split(RegExp(r'\s+')).where((w) => w.isNotEmpty).join(' ');

/// HKDF-SHA256 (RFC 5869).
Uint8List hkdf(List<int> ikm, {required List<int> salt, required List<int> info, int length = 32}) {
  final prk = Hmac(sha256, salt).convert(ikm).bytes;
  final out = <int>[];
  var previous = <int>[];
  var counter = 1;
  while (out.length < length) {
    previous = Hmac(sha256, prk).convert([...previous, ...info, counter]).bytes;
    out.addAll(previous);
    counter++;
  }
  return Uint8List.fromList(out.sublist(0, length));
}

/// The pairing key: six words + the host id. Both sides derive the same 32 bytes; only the key
/// is stored, never the words.
Uint8List derivePairingKey(String sixWords, String hostId) => hkdf(
      utf8.encode(normaliseWords(sixWords)),
      salt: utf8.encode('lovetap-pair-v1'),
      info: utf8.encode(hostId),
    );

String hex(List<int> bytes) => bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

String sha256Hex(List<int> bytes) => sha256.convert(bytes).toString();

String randomHex(int bytes, [Random? random]) {
  final r = random ?? Random.secure();
  return hex(List<int>.generate(bytes, (_) => r.nextInt(256)));
}

/// What a signed request commits to.
String signingString(String method, String path, int ts, String nonce, String bodySha256) =>
    '$method\n$path\n$ts\n$nonce\n$bodySha256';

String sign(Uint8List key, String method, String path, int ts, String nonce, List<int> body) =>
    hex(Hmac(sha256, key).convert(utf8.encode(signingString(method, path, ts, nonce, sha256Hex(body)))).bytes);

bool constantTimeEquals(String a, String b) {
  if (a.length != b.length) return false;
  var diff = 0;
  for (var i = 0; i < a.length; i++) {
    diff |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
  }
  return diff == 0;
}

/// `Authorization: Pair <deviceId> <ts> <nonce> <hmac>`
class AuthHeader {
  const AuthHeader({required this.deviceId, required this.ts, required this.nonce, required this.mac});
  final String deviceId;
  final int ts;
  final String nonce;
  final String mac;

  String get value => 'Pair $deviceId $ts $nonce $mac';

  static AuthHeader? parse(String? header) {
    if (header == null) return null;
    final parts = header.trim().split(RegExp(r'\s+'));
    if (parts.length != 5 || parts[0] != 'Pair') return null;
    final ts = int.tryParse(parts[2]);
    if (ts == null) return null;
    return AuthHeader(deviceId: parts[1], ts: ts, nonce: parts[3], mac: parts[4]);
  }

  static AuthHeader make(Uint8List key, String deviceId, String method, String path, List<int> body, {int? nowMs}) {
    final ts = nowMs ?? DateTime.now().toUtc().millisecondsSinceEpoch;
    final nonce = randomHex(12);
    return AuthHeader(deviceId: deviceId, ts: ts, nonce: nonce, mac: sign(key, method, path, ts, nonce, body));
  }
}

/// Pairing proof: `HMAC(key, "pair\n<deviceId>\n<nonce>")`.
String pairingProof(Uint8List key, String deviceId, String nonce) =>
    hex(Hmac(sha256, key).convert(utf8.encode('pair\n$deviceId\n$nonce')).bytes);

/// Remembers recent nonces so a captured request cannot be replayed within the skew window.
class NonceCache {
  NonceCache({this.capacity = 20000});
  final int capacity;
  final Map<String, int> _seen = {};

  bool checkAndAdd(String nonce, int ts) {
    if (_seen.containsKey(nonce)) return false;
    if (_seen.length >= capacity) {
      final cutoff = ts - kAuthSkew.inMilliseconds;
      _seen.removeWhere((_, t) => t < cutoff);
      if (_seen.length >= capacity) _seen.remove(_seen.keys.first);
    }
    _seen[nonce] = ts;
    return true;
  }
}
