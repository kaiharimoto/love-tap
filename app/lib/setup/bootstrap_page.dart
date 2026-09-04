// The page the other phone opens before anything is encrypted.
//
// An iPhone will not trust a certificate it has not been given, and it will not take one from
// inside an app: it has to come as a configuration profile, opened in Safari, and then trusted by
// hand in Settings. So the host serves one page over plain HTTP on its tailnet address, and that
// page hands over exactly one thing — the certificate the host will present, as a profile.
//
// Nothing secret crosses here and nothing needs to. A certificate is a public key and a name; it
// is not a credential. The six words are what proves the two phones to each other, and they are
// said out loud in the same room, never served.
import 'dart:convert';

/// A configuration profile carrying one certificate authority, for iOS and macOS.
///
/// The plist is written out rather than templated from a library so that what is served is exactly
/// what is in this file: a profile that installs a root certificate and asks for nothing else. No
/// payload here can change a proxy, a VPN, a restriction or a password policy, and there is
/// nowhere in the tree that adds one.
String mobileConfig({
  required List<int> certificateDer,
  required String hostName,
  required String profileUuid,
  required String payloadUuid,
}) {
  final der = base64.encode(certificateDer);
  final wrapped = <String>[];
  for (var i = 0; i < der.length; i += 64) {
    wrapped.add(der.substring(i, i + 64 > der.length ? der.length : i + 64));
  }
  return '''<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>PayloadContent</key>
  <array>
    <dict>
      <key>PayloadType</key><string>com.apple.security.root</string>
      <key>PayloadVersion</key><integer>1</integer>
      <key>PayloadIdentifier</key><string>$hostName.ca</string>
      <key>PayloadUUID</key><string>$payloadUuid</string>
      <key>PayloadDisplayName</key><string>$hostName</string>
      <key>PayloadDescription</key><string>The certificate the other phone presents on the tailnet.</string>
      <key>PayloadCertificateFileName</key><string>$hostName.cer</string>
      <key>PayloadContent</key>
      <data>
${wrapped.join('\n')}
      </data>
    </dict>
  </array>
  <key>PayloadType</key><string>Configuration</string>
  <key>PayloadVersion</key><integer>1</integer>
  <key>PayloadIdentifier</key><string>$hostName.profile</string>
  <key>PayloadUUID</key><string>$profileUuid</string>
  <key>PayloadDisplayName</key><string>$hostName</string>
  <key>PayloadDescription</key><string>One certificate, so the two phones can tell it is each other.</string>
  <key>PayloadRemovalDisallowed</key><false/>
</dict>
</plist>
''';
}

/// The page itself. It is written in the same voice as everything else, it does not name the app,
/// and it says what happens next rather than congratulating anyone for arriving.
String bootstrapPage({required String hostName, required String address, required bool profileReady}) {
  final steps = profileReady
      ? '''
      <ol>
        <li>Take the profile. Safari will say it has been downloaded.</li>
        <li>Settings, at the top, will have it waiting. Install it.</li>
        <li>Settings, General, About, Certificate Trust Settings. Turn it on there too — iOS will
            not offer that switch until the profile is installed.</li>
        <li>Come back to the other phone and read the six words out.</li>
      </ol>
      <p class="take"><a href="/setup/profile.mobileconfig">take the profile</a></p>'''
      : '''
      <p>The other phone has not made its certificate yet. Leave this open; it will be here when
         it has.</p>''';
  return '''<!DOCTYPE html>
<html lang="en"><head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>$hostName</title>
<style>
  :root { color-scheme: dark; }
  body { margin: 0; background: #4C3E32; color: #F1ECDF;
         font: 17px/1.5 ui-serif, Georgia, serif; padding: 32px 24px 64px; }
  main { max-width: 34rem; margin: 0 auto; }
  h1 { font-size: 1.35rem; font-weight: 500; margin: 0 0 4px; }
  p.where { color: #CFC4B2; margin: 0 0 28px; font-size: 0.95rem; }
  ol { padding-left: 1.2em; }
  li { margin-bottom: 10px; }
  p.take { margin-top: 28px; }
  a { color: #F1ECDF; }
  p.small { color: #CFC4B2; font-size: 0.9rem; margin-top: 34px; }
</style>
</head><body><main>
  <h1>$hostName</h1>
  <p class="where">$address</p>
  $steps
  <p class="small">This page hands over one certificate and nothing else. It is a name and a public
     key: it is what lets this phone tell that it is talking to the other one and not to something
     in between. Nothing either of you has written goes through here.</p>
</main></body></html>
''';
}
