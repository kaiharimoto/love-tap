// The one kind of row in the spine. docs/EVENT_TYPES.md is the contract.
import 'dart:convert';

/// One of the two people. The spine never holds a third author.
enum Person {
  noor,
  teo;

  static Person parse(String s) => Person.values.firstWhere((p) => p.name == s);

  Person get other => this == Person.noor ? Person.teo : Person.noor;
}

/// Which of the two devices minted an event.
enum DeviceKind {
  android,
  pwa;

  static DeviceKind parse(String s) => DeviceKind.values.firstWhere((d) => d.name == s);
}

class Event {
  Event({
    required this.id,
    required this.seq,
    required this.author,
    required this.device,
    required this.ts,
    required this.type,
    Map<String, dynamic>? payload,
    List<String>? refs,
    List<String>? blobs,
  })  : payload = Map.unmodifiable(payload ?? const {}),
        refs = List.unmodifiable(refs ?? const []),
        blobs = List.unmodifiable(blobs ?? const []);

  /// ULID minted by the author's device.
  final String id;

  /// Host-assigned monotonic sequence; null until the host has accepted the event.
  final int? seq;
  final Person author;
  final DeviceKind device;

  /// Author's wall clock, ms since epoch (UTC).
  final int ts;
  final String type;
  final Map<String, dynamic> payload;
  final List<String> refs;
  final List<String> blobs;

  bool get isPending => seq == null;

  DateTime get time => DateTime.fromMillisecondsSinceEpoch(ts, isUtc: true);

  Event withSeq(int newSeq) => Event(
        id: id,
        seq: newSeq,
        author: author,
        device: device,
        ts: ts,
        type: type,
        payload: payload,
        refs: refs,
        blobs: blobs,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'seq': seq,
        'author': author.name,
        'device': device.name,
        'ts': ts,
        'type': type,
        'refs': refs,
        'blobs': blobs,
        'payload': payload,
      };

  static Event fromJson(Map<String, dynamic> j) => Event(
        id: j['id'] as String,
        seq: j['seq'] as int?,
        author: Person.parse(j['author'] as String),
        device: DeviceKind.parse(j['device'] as String),
        ts: j['ts'] as int,
        type: j['type'] as String,
        payload: (j['payload'] as Map?)?.cast<String, dynamic>() ?? const {},
        refs: (j['refs'] as List?)?.cast<String>() ?? const [],
        blobs: (j['blobs'] as List?)?.cast<String>() ?? const [],
      );

  String encode() => jsonEncode(toJson());

  static Event decode(String s) => fromJson(jsonDecode(s) as Map<String, dynamic>);

  @override
  String toString() => 'Event($type ${author.name} seq=$seq id=$id)';
}
