// Build-time flags. run.sh passes them as --dart-define; nothing here is read at runtime from
// the network or the URL, so a build started without --seed=year can never contain the seed.
class Flags {
  /// 'year' loads the seeded history at first start; anything else starts empty.
  static const String seed = String.fromEnvironment('SEED', defaultValue: '');

  /// 'local' or 'tailscale'.
  static const String transport = String.fromEnvironment('TRANSPORT', defaultValue: 'local');

  /// 'host' (Android) or 'client' (PWA). Defaults by platform in main.dart when empty.
  static const String role = String.fromEnvironment('ROLE', defaultValue: '');

  /// 'noor' or 'teo'. Defaults by role in main.dart when empty.
  static const String person = String.fromEnvironment('PERSON', defaultValue: '');

  /// Separates two instances on one machine and the seeded profile from the empty one.
  static const String profile = String.fromEnvironment('PROFILE', defaultValue: 'default');

  /// Capture mode: driven clock, fixed RNG seed, no real-time animation timing.
  static const bool capture = bool.fromEnvironment('CAPTURE', defaultValue: false);
  static const int captureSeed = int.fromEnvironment('CAPTURE_SEED', defaultValue: 20260903);

  /// Frozen "now" for the seeded history, ISO 8601. Empty means the wall clock.
  static const String frozenNow = String.fromEnvironment('FROZEN_NOW', defaultValue: '');

  /// Local transport port (host binds it; client connects to it through adb forward).
  static const int port = int.fromEnvironment('PORT', defaultValue: 8480);

  /// This device's own tailnet address, when the setup list or run.sh knows it. Checked against
  /// the tailnet ranges before anything is bound to it — declaring it is a convenience, not a
  /// way round the rule that the host serves on the tailnet and nowhere else.
  static const String tailnetAddress = String.fromEnvironment('TAILNET_ADDRESS', defaultValue: '');

  /// The other phone's tailnet address, when pairing has not recorded one yet.
  static const String peerAddress = String.fromEnvironment('PEER_ADDRESS', defaultValue: '');

  /// 'day' or 'dusk'. The whole app is lit by one condition at a time, so the desk, the paper and
  /// every baked shadow agree; this is what the dusk capture is taken under.
  static const String light = String.fromEnvironment('LIGHT', defaultValue: 'day');

  static bool get seeded => seed == 'year';
  static bool get dusk => light == 'dusk';
}
