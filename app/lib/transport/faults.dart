// Injectable faults for the development transport. The Tailscale transport uses NoFaults.
import 'dart:async';

/// Thrown by a fault to stand in for a network failure.
class InjectedFault implements Exception {
  InjectedFault(this.what);
  final String what;

  @override
  String toString() => 'InjectedFault($what)';
}

abstract class FaultInjector {
  /// Called before every request the client makes. May delay or throw.
  Future<void> beforeRequest(String op);

  /// Called after a request reached the host but before the client reads the response.
  /// Throwing here is "killed mid-send": the host has the data, the client does not know.
  Future<void> beforeResponse(String op);

  /// Whether the client currently believes it is offline (no requests attempted).
  bool get offline;

  Map<String, dynamic> describe();
}

class NoFaults implements FaultInjector {
  const NoFaults();

  @override
  Future<void> beforeRequest(String op) async {}

  @override
  Future<void> beforeResponse(String op) async {}

  @override
  bool get offline => false;

  @override
  Map<String, dynamic> describe() => const {'faults': 'none'};
}

/// Faults that a test or run.sh can flip at will.
class ScriptedFaults implements FaultInjector {
  ScriptedFaults();

  bool _offline = false;
  int _dropNext = 0;
  int _loseResponseNext = 0;
  Duration _latency = Duration.zero;
  final List<String> _log = [];

  @override
  bool get offline => _offline;

  /// Go offline: every request fails as unreachable until [online] is called.
  void goOffline() {
    _offline = true;
    _log.add('offline');
  }

  void goOnline() {
    _offline = false;
    _log.add('online');
  }

  /// The next [n] requests fail before reaching the host.
  void dropNext(int n) {
    _dropNext += n;
    _log.add('drop $n');
  }

  /// The next [n] requests reach the host but their responses are lost (kill mid-send).
  void loseResponseNext(int n) {
    _loseResponseNext += n;
    _log.add('lose-response $n');
  }

  void setLatency(Duration d) {
    _latency = d;
    _log.add('latency ${d.inMilliseconds}ms');
  }

  List<String> get log => List.unmodifiable(_log);

  @override
  Future<void> beforeRequest(String op) async {
    if (_offline) throw InjectedFault('offline ($op)');
    if (_dropNext > 0) {
      _dropNext--;
      throw InjectedFault('dropped ($op)');
    }
    if (_latency > Duration.zero) await Future<void>.delayed(_latency);
  }

  @override
  Future<void> beforeResponse(String op) async {
    if (_loseResponseNext > 0) {
      _loseResponseNext--;
      throw InjectedFault('response lost ($op)');
    }
  }

  @override
  Map<String, dynamic> describe() => {
        'faults': 'scripted',
        'offline': _offline,
        'drop_next': _dropNext,
        'lose_response_next': _loseResponseNext,
        'latency_ms': _latency.inMilliseconds,
        'log': _log,
      };
}
