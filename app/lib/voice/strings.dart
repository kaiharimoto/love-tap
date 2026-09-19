// Every displayed string. docs/VOICE.md rules it; tools/lint/strings.py checks it.
// No app name, no exclamation marks, no one is a "user".
class S {
  // regions
  static const pulse = 'pulse';
  static const chat = 'chat';
  static const us = 'us';
  static const moments = 'moments';
  static const settings = 'settings';

  // chat
  static const composerHint = 'write something';
  static const send = 'send';
  static const reply = 'reply';
  static const react = 'react';
  static const edit = 'edit';
  static const delete = 'take it back';
  static const editHint = 'change it';
  static const keep = 'keep';
  static const tookBack = 'took this back';
  static const edited = 'edited';
  static const writtenEarlier = 'written earlier';
  static const waitingToSend = 'waiting to send';
  static const sent = 'sent';
  static const read = 'read';
  static const typing = 'writing…';
  static const photo = 'a photo';
  static const video = 'a video';
  static const voiceNote = 'a voice note';
  static const holdToRecord = 'hold to record';
  static const recording = 'recording…';
  static const search = 'search';
  static const searchHint = 'anything, any time';
  static const sending = 'going';
  static const refused = 'it would not go';

  /// What the person presses to send a refused one again. A refusal that offers nothing is a
  /// dead end on the one screen this whole build is for, and it is why somebody opens Instagram.
  static const tryAgain = 'try again';

  /// Why the host would not take something, written in the margin under the note it refused.
  /// The host chooses which of these to send; they live here because they are words on a screen
  /// and docs/VOICE.md rules every one of those, wherever it is chosen.
  static const refusedUnreadable = "the other phone couldn't read it.";
  static const refusedWrongName = 'the other phone is paired to a different name.';
  static const searchNothing = 'nothing with that in it.';
  static const searchAside = 'a year of it, and every kind of thing in it.';
  static const searchNoneAside = 'try fewer words, or a different month.';
  static const emptyChat = "first one's yours.";
  static const emptyChatAside = 'whatever it is. it only goes to one person.';
  static const replyingTo = 'answering';
  static const cancel = 'cancel';
  static const play = 'play';
  static const pause = 'pause';
  static const fetching = 'still fetching the picture.';

  /// A read that came back with nothing, which is not the same as one that has not come
  /// back. Both used to say the line above, and a screen that was merely slow could not be
  /// told from a screen that was broken -- including by this build's own review.
  static const pictureNotHere = "this picture isn't on this phone.";

  // link
  static const offlineQueued = "can't reach the other phone. it'll go when it can.";
  static const hostDown = "the other phone isn't answering. keeping this until it does.";
  static const notPaired = 'not paired yet.';

  // pulse
  static const emptyPulse = 'nothing from them yet. it will show here.';
  static const emptyPulseAside = 'their phone tells this one where they are, once it can reach it.';

  // us
  static const emptyDates = "nowhere planned. that's fine.";
  static const emptyTodos = 'nothing to do. suspicious.';
  static const emptyCalendar = 'no dates that matter yet. add the first.';
  static const emptyRituals = 'nothing kept yet.';

  // moments
  static const emptyMoments = 'it fills in as it happens.';
  static const emptyMomentsAside = 'everything either of you sends ends up here, by day and by kind.';

  // settings
  static const emptyFeelings = 'the built-in ones are here. make one below.';

  /// What is missing, said in words. It used to be said by drawing `keep it` at forty per cent of
  /// an ink, which is 2.4:1 against the paper and tells nobody which of the four fields it wants.
  static const itNeedsAName = 'it needs a name first.';

  static String feelingFrom(String feelingName, String person) => '$feelingName from $person';
  static String aPhotoFrom(String person) => '$person, a photo';
}
