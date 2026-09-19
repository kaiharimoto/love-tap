// Where the regions hang the handles capture mode drives them by.
//
// The regions fill these in as they mount; hooks.dart reads them. Nothing here is called outside
// a CAPTURE build, and a handle that was never filled in fails the capture step loudly rather
// than producing a screenshot of the wrong thing.
typedef Report = Map<String, dynamic>;

class CaptureBus {
  /// Set by a test that wants the handles registered without a capture build.
  ///
  /// The handles are offered when `Flags.capture` is on, which is a compile-time define, which
  /// means the only thing that has ever run them is capture.sh — and a handle that throws is then
  /// found by a scene failing an hour into a run. `__deskStage` threw for exactly that long.
  /// With this a test can ask for them and call every one.
  static bool wanted = false;

  /// Which region is on screen, kept by the shell.
  static int regionIndex = -1;

  /// Shell: switch region by index (0 pulse, 1 chat, 2 us, 3 moments, 4 settings).
  static void Function(int index)? goToRegion;

  /// Shell: send a feeling as if the corner had been dragged to [intensity].
  static Future<void> Function(String feelingId, double intensity)? sendFeeling;

  /// Shell: open or close the feeling corner's fan.
  static void Function(bool open)? openCorner;

  /// Chat: scroll to an event id, or to a fraction of the thread ('0.5'), or 'end'.
  static Future<void> Function(String anchor)? scrollTo;

  /// Chat: open the composer's attachment sheet, or close it.
  static void Function(bool open)? openSender;

  /// Chat: open the media viewer on an event.
  static Future<void> Function(String eventId)? openViewer;

  /// Chat: run a search and land on the first hit.
  static Future<void> Function(String query)? search;

  /// Whether the setup list is the thing on screen. The artifact of it came back as text on
  /// bare wood once, and nothing in the report said whether the sheet under it had drawn.
  static bool setupShowing = false;

  /// Chat: move the thread by this many logical pixels, once, right now. One of these per frame
  /// is a scroll; a pointer drag down the middle of the desk is a long press on a note.
  static void Function(double dy)? scrollBy;

  /// Chat: put one of everything on the desk — a message on its way, one waiting for the link,
  /// one the host refused — beside the sent, read, edited, deleted, replied and reacted-to rows
  /// the seeded year already carries. The evidence for the messenger's states has to be a
  /// picture of the app in them, not a drawing of them.
  static Future<void> Function()? stageStates;

  /// Chat: which rows are on screen, and where the thread is sitting.
  static Report Function()? chatReport;

  /// Chat: open every folded note on screen at once, for the unfolding clip.
  static void Function()? unfoldAll;

  /// Chat: the other phone starts or stops writing. It is a frame that is not an event, and the
  /// evidence for it has to be a picture of this phone showing it, because rubric row 01 names
  /// typing indication and docs/BRIEF.md 09 forbids storing it as one — so it can never appear in
  /// reliability.json's capability list or anywhere else in the log.
  static void Function(bool on)? partnerTyping;

  /// Settings: begin pairing (host) so the six words are on screen.
  static Future<void> Function()? showWords;

  /// Settings: move the settings page by this many logical pixels, once, right now.
  ///
  /// The settings page is taller than one screenful and `what may interrupt` is the last thing
  /// on it, so a capture of the top of the page cannot see the interrupt matrix at all. Firing 21
  /// moved that table to the bottom on purpose -- it is the one thing here you set once and never
  /// look at again, and with it in the middle the artifact carried thirteen rows of it and none of
  /// the feeling-authoring tools the row asks for -- and the cost was that all 42 of the matrix's
  /// text runs left `05_settings.text.json` and the critics stopped being able to see a real
  /// surface. This is its own slot rather than `scrollBy` because that one belongs to the thread:
  /// both regions can be mounted at once, and whichever registered last would win.
  static void Function(double dy)? settingsScrollBy;

  static void clear() {
    regionIndex = -1;
    goToRegion = null;
    sendFeeling = null;
    openCorner = null;
    scrollTo = null;
    openSender = null;
    openViewer = null;
    search = null;
    chatReport = null;
    scrollBy = null;
    stageStates = null;
    partnerTyping = null;
    unfoldAll = null;
    showWords = null;
    settingsScrollBy = null;
  }
}
