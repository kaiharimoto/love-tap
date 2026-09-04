// Partner-state projection: the latest value of every signal for each person, from
// state_declared and state_passive events. docs/SIGNALS.md lists the signals.
import '../event.dart';

class SignalValue {
  const SignalValue({required this.signal, required this.value, required this.at, required this.declared});
  final String signal;
  final dynamic value;
  final int at;
  final bool declared;

  Duration ageAt(int nowMs) => Duration(milliseconds: nowMs - at);
}

class PersonState {
  PersonState(this.person, this.signals);
  final Person person;
  final Map<String, SignalValue> signals;

  SignalValue? operator [](String signal) => signals[signal];

  String? get mood => signals['mood']?.value as String?;
  String? get statusLine => signals['status_line']?.value as String?;
  String get availability => (signals['availability']?.value as String?) ?? 'open';
  int get need => (signals['need']?.value as num?)?.toInt() ?? 0;
  int get energy => (signals['energy']?.value as num?)?.toInt() ?? 2;
  String? get place => signals['place']?.value as String?;
  int? get battery => (signals['battery']?.value as num?)?.toInt();
  bool get charging => signals['charging']?.value == true;
  int? get lastActiveMinutes => (signals['last_active']?.value as num?)?.toInt();
  int? get localHour => (signals['local_hour']?.value as num?)?.toInt();
  String? get ringer => signals['ringer']?.value as String?;
  String? get moving => signals['moving']?.value as String?;
  String? get network => signals['network']?.value as String?;
  bool? get atHome => signals['at_home']?.value as bool?;
}

const List<String> kDeclaredSignals = ['mood', 'status_line', 'availability', 'need', 'energy', 'place'];
const List<String> kPassiveSignals = [
  'battery', 'charging', 'last_active', 'local_hour', 'ringer', 'moving', 'network', 'at_home',
];

Map<Person, PersonState> projectState(List<Event> events) {
  // in order, for the same reason projectThread is: the last thing said about a signal is the
  // last thing said about it, not the last one that happened to arrive
  events = inLogOrder(events);
  final out = {for (final p in Person.values) p: PersonState(p, {})};
  for (final e in events) {
    if (e.type != 'state_declared' && e.type != 'state_passive') continue;
    final signal = e.payload['signal'] as String?;
    if (signal == null) continue;
    out[e.author]!.signals[signal] = SignalValue(
      signal: signal,
      value: e.payload['value'],
      at: e.ts,
      declared: e.type == 'state_declared',
    );
  }
  return out;
}

/// The feelings exchanged in a window (for the Pulse "day's traffic").
List<Event> feelingsSince(List<Event> events, int sinceMs) =>
    events.where((e) => e.type == 'feeling' && e.ts >= sinceMs).toList();
