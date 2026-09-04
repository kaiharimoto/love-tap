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
    required this.certificateVerified,
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

  /// The link came up over a certificate this device actually trusts.
  final bool certificateVerified;
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

/// The PWA list. An iPhone needs two things Android does not: the app has to leave Safari, and the
/// certificate goes in through a profile rather than a prompt.
const List<SetupStep> kPwaSetup = [
  SetupStep(
    id: 'home',
    title: 'add it to the home screen',
    detail: 'share, then add to home screen. it will not hold on to anything until you do.',
    observedBy: 'waiting to be opened from the home screen rather than from a tab',
  ),
  SetupStep(
    id: 'tailnet',
    title: 'put this phone on the tailnet',
    detail: 'the same private network as the other phone, and nothing else on it.',
    observedBy: 'waiting for an address on the tailnet',
  ),
  SetupStep(
    id: 'certificate',
    title: 'install the profile the other phone is serving',
    detail: 'open its address in Safari, take the profile, then trust it in settings under about, '
        'certificate trust settings.',
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
    detail: 'an iPhone only offers this once the app is on the home screen.',
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
}) {
  final all = spine.all;
  final me = spine.identity.person;
  return SetupFacts(
    platform: platform,
    link: link,
    paired: pairing,
    notificationsAllowed: notificationsAllowed,
    installedToHome: installedToHome,
    certificateVerified: link.state == LinkState.connected || link.state == LinkState.listening,
    mineInSpine: all.any((e) => e.author == me && _counts(e.type)),
    theirsInSpine: all.any((e) => e.author != me && _counts(e.type)),
  );
}

/// A read marker or a passive signal is not "the first thing": someone has to have said something.
bool _counts(String type) => const {
      'message', 'photo', 'video', 'voice_note', 'feeling', 'ping', 'reaction',
    }.contains(type);
