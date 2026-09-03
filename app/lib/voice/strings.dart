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
  static const searchNothing = 'nothing with that in it.';
  static const emptyChat = "first one's yours.";
  static const replyingTo = 'answering';
  static const cancel = 'cancel';
  static const play = 'play';
  static const pause = 'pause';
  static const fetching = 'still fetching the picture.';

  // link
  static const offlineQueued = "can't reach the other phone. it'll go when it can.";
  static const hostDown = "the other phone isn't answering. keeping this until it does.";
  static const notPaired = 'not paired yet.';

  // pulse
  static const emptyPulse = 'nothing from them yet. it will show here.';

  // us
  static const emptyDates = "nowhere planned. that's fine.";
  static const emptyTodos = 'nothing to do. suspicious.';
  static const emptyCalendar = 'no dates that matter yet. add the first.';
  static const emptyRituals = 'nothing kept yet.';

  // moments
  static const emptyMoments = 'it fills in as it happens.';

  // settings
  static const emptyFeelings = 'the built-in ones are here. make one below.';

  static String feelingFrom(String feelingName, String person) => '$feelingName from $person';
  static String aPhotoFrom(String person) => '$person, a photo';
}
