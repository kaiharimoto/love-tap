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

  /// 'day' or 'dusk'. The whole app is lit by one condition at a time, so the desk, the paper and
  /// every baked shadow agree; this is what the dusk capture is taken under.
  static const String light = String.fromEnvironment('LIGHT', defaultValue: 'day');

  static bool get seeded => seed == 'year';
  static bool get dusk => light == 'dusk';
}
