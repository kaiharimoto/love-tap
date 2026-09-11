// The two setup checklists, as things that are observed rather than things that are claimed.
//
// Every step here ticks off a fact the app can see for itself: an address on the tainet, a
// certificate that verified, a pairing that completed, an event in the spine. Nothing ticks
// because someone pressed "done", because a checklist that can be lied to is worse than none —
// on the day the notes stop arriving it is the only honest account of what is actually set up.
import '../spine/spine.dart';
import '../transport/transport.dart';

enum StepState { waiting, doing, done }

class SetupStep {
  const SetupStep({
    required this.id,
    required this.title,
    required this.detail,
    required this.observedBy,
  });

  final String id;
  final String title;

  /// What to do, in the couple's own voice: a sentence, not an instruction manual.
  final String detail;

  /// What the app is watching for. Shown under the step while it is undone, so it is always clear
  /// what would make it tick.
  final String observedBy;
}

class SetupFacts {
  const SetupFacts({
    required this.platform,
    required this.link,
    required this.paired,
    required this.notificationsAllowed,
    required this.installedToHome,
    required this.certificate,
    this.secureOrigin = false,
    required this.mineInSpine,
    required this.theirsInSpine,
  });

  /// 'android' or 'pwa'.
  final String platform;
  final TransportStatus link;
  final Pairing? paired;
  final bool notificationsAllowed;

  /// PWA only: running from the Home Screen rather than from a browser tab.
  final bool installedToHome;

  /// The fingerprint of the certificate the link is actually running on: what the host is
  /// serving, or what the client pinned when the two people said the six words in one room.
  ///
  /// This used to be a bool derived from `link.state == connected || listening`, and the host was
  /// serving plain HTTP, so the step ticked for every connection that had no certificate in it at
  /// all. A checklist that can tick for a thing that did not happen is worse than one step short,
  /// and a code critic was right to call it the worst thing in the transport.
  final String? certificate;

  /// The link came up over a certificate this device can name. On the PWA this stays false even
  /// when Safari is perfectly happy, because Safari does not hand the page what it validated —
  /// there [secureOrigin] is what the browser will say for itself.
  bool get certificateVerified => (certificate ?? '').isNotEmpty || secureOrigin;

  /// PWA only: `window.isSecureContext`. The one thing the browser will tell the page about its
  /// own origin, and the thing the service worker actually turns on.
  final bool secureOrigin;
  final bool mineInSpine;
  final bool theirsInSpine;

  bool get onTailnet {
    final a = link.address;
    return a != null && (a.contains('100.') || a.endsWith('.ts.net'));
  }
}

/// The Android list. Ordered the way it actually has to happen.
const List<SetupStep> kAndroidSetup = [
  SetupStep(
    id: 'tailnet',
    title: 'put this phone on the tailnet',
    detail: 'the same private network as the other phone, and nothing else on it.',
    observedBy: 'waiting for an address on the tailnet',
  ),
  SetupStep(
    id: 'certificate',
    title: 'trust the certificate the other phone holds',
    detail: 'so nothing between the two of you can read what goes across.',
    observedBy: 'waiting for the first connection that verifies',
  ),
  SetupStep(
    id: 'pair',
    title: 'read the six words off the other phone',
    detail: 'say them out loud in the same room. they are only good once.',
    observedBy: 'waiting for the pairing to complete',
  ),
  SetupStep(
    id: 'notifications',
    title: 'let it interrupt you',
    detail: 'you choose which kinds, later, in settings. this only opens the door.',
    observedBy: 'waiting for notifications to be allowed',
  ),
  SetupStep(
    id: 'first',
    title: 'write the first thing',
    detail: 'anything. it goes to one person.',
    observedBy: 'waiting for something written here',
  ),
  SetupStep(
    id: 'theirs',
    title: 'wait for theirs to arrive',
    detail: 'when it lands, the two of you are done here.',
    observedBy: 'waiting for the first thing from them',
  ),
];

/// The PWA list. An iPhone needs two things Android does not: the certificate goes in through a
/// profile rather than a prompt, and the app has to leave Safari.
///
/// In that order, and it is not arbitrary. A page served on an origin the phone does not trust is
/// not a secure context: no service worker, so no push, and storage the browser feels free to
/// evict. Adding *that* to the home screen gets you a home-screen app with those properties baked
/// in. The profile first, then the home screen.
const List<SetupStep> kPwaSetup = [
  SetupStep(
    id: 'tailnet',
    title: 'put this phone on the tailnet',
    detail: 'the same private network as the other phone, and nothing else on it.',
    observedBy: 'waiting for an address on the tailnet',
  ),
  SetupStep(
    id: 'certificate',
    title: 'install the profile the other phone is serving',
    detail: 'the other phone shows a second address for this one thing. open it in safari, take '
        'the profile, then turn it on in settings under about, certificate trust settings.',
    observedBy: 'waiting for the first connection that verifies',
  ),
  SetupStep(
    id: 'home',
    title: 'add it to the home screen',
    detail: 'share, then add to home screen. it will not hold on to anything until you do.',
    observedBy: 'waiting to be opened from the home screen rather than from a tab',
  ),
  SetupStep(
    id: 'pair',
    title: 'read the six words off the other phone',
    detail: 'say them out loud in the same room. they are only good once.',
    observedBy: 'waiting for the pairing to complete',
  ),
  SetupStep(
    id: 'notifications',
    title: 'let it interrupt you',
    detail: 'an iPhone only offers this once the app is on the home screen.',
    observedBy: 'waiting for notifications to be allowed',
  ),
  SetupStep(
    id: 'first',
    title: 'write the first thing',
    detail: 'anything. it goes to one person. when a feeling comes back, this phone cannot buzz: '
        'the paper under your thumb lifts to its rhythm instead, and its sound carries the beat.',
    observedBy: 'waiting for something written here',
  ),
  SetupStep(
    id: 'theirs',
    title: 'wait for theirs to arrive',
    detail: 'when it lands, the two of you are done here.',
    observedBy: 'waiting for the first thing from them',
  ),
];

List<SetupStep> stepsFor(String platform) => platform == 'android' ? kAndroidSetup : kPwaSetup;

/// Where the list has got to. The first undone step is the one being done; everything after it is
/// still waiting, because doing them out of order is how a setup goes wrong quietly.
Map<String, StepState> observe(List<SetupStep> steps, SetupFacts facts) {
  bool done(String id) => switch (id) {
        'home' => facts.installedToHome,
        'tailnet' => facts.onTailnet,
        'certificate' => facts.certificateVerified,
        'pair' => facts.paired != null,
        'notifications' => facts.notificationsAllowed,
        'first' => facts.mineInSpine,
        'theirs' => facts.theirsInSpine,
        _ => false,
      };
  final out = <String, StepState>{};
  var reachedCurrent = false;
  for (final s in steps) {
    if (done(s.id)) {
      out[s.id] = StepState.done;
    } else if (!reachedCurrent) {
      out[s.id] = StepState.doing;
      reachedCurrent = true;
    } else {
      out[s.id] = StepState.waiting;
    }
  }
  return out;
}

/// True when there is nothing left to do here.
bool settled(List<SetupStep> steps, SetupFacts facts) =>
    observe(steps, facts).values.every((s) => s == StepState.done);

/// The facts, read off the one object graph. Nothing in here is stored: it is all observed each
/// time the list is drawn, so a step cannot stay ticked after the thing it watched went away.
SetupFacts factsFrom({
  required String platform,
  required Spine spine,
  required TransportStatus link,
  required Pairing? pairing,
  required bool notificationsAllowed,
  required bool installedToHome,
  bool secureOrigin = false,
}) {
  final all = spine.all;
  final me = spine.identity.person;
  return SetupFacts(
    platform: platform,
    link: link,
    paired: pairing,
    notificationsAllowed: notificationsAllowed,
    installedToHome: installedToHome,
    certificate: link.certificate,
    secureOrigin: secureOrigin,
    mineInSpine: all.any((e) => e.author == me && _counts(e.type)),
    theirsInSpine: all.any((e) => e.author != me && _counts(e.type)),
  );
}

/// A read marker or a passive signal is not "the first thing": someone has to have said something.
bool _counts(String type) => const {
      'message', 'photo', 'video', 'voice_note', 'feeling', 'ping', 'reaction',
    }.contains(type);

/// The certificate's fingerprint in the form a person can actually read out loud.
///
/// Thirty-two pairs of hex is not something anybody says correctly, and a comparison nobody
/// completes is a comparison that always passes. The two ends are what a substituted certificate
/// would have to match, so they are what gets shown on both phones and compared by eye.
String spokenFingerprint(String fingerprint) {
  final parts = fingerprint.split(':');
  if (parts.length <= 8) return parts.join(' ');
  return '${parts.take(4).join(' ')} … ${parts.skip(parts.length - 4).join(' ')}';
}
