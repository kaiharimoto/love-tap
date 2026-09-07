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

  /// Turn the vocabulary to a family, so a clip can be *of* the vocabulary rather than of a
  /// sheet appearing for a fifth of a second. Returns the number of feelings now on the sheet.
  static int Function(String family)? showFamily;

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

  /// Chat: write one and let it be on its way when the picture is taken.
  ///
  /// `sending` is the one delivery state that is genuinely transient — a row is sending while its
  /// push is in flight and for no longer — so the only honest way to photograph it is to make the
  /// push actually take a moment. The link is slowed for a few seconds and a message is written
  /// into it; the sync engine sets its own in-flight mark around the push and clears it in its own
  /// finally, so the row reads `sending` because it is sending. Marking a row by hand did nothing:
  /// a pending row already reads `sending` while the link is up, and the engine cleared the mark.
  static Future<void> Function(String text, int slowMs)? sendSlowly;

  /// Search: what the search page is showing while it is the thing on the glass. Registered by
  /// the page itself, because the hooks dispatch on the region index and the search page is drawn
  /// inside Chat's slot — so without this the search artifact's record described the thread
  /// underneath it, down to the scroll positions of a list that was no longer mounted.
  static Report Function()? searchReport;

  /// The viewer: what is open in it, and whether the video is actually running.
  static Report Function()? viewerReport;

  /// Moments: which tiles are on screen and whether their pictures have arrived. The capture
  /// report used to describe Chat's thread whatever region was showing, so five regions' logs
  /// said the same seven notes were visible when four of them showed none.
  static Report Function()? momentsReport;

  /// Chat: open every folded note on screen at once, for the unfolding clip.
  static void Function()? unfoldAll;

  /// Settings: begin pairing (host) so the six words are on screen.
  static Future<void> Function()? showWords;

  static void clear() {
    regionIndex = -1;
    goToRegion = null;
    sendFeeling = null;
    openCorner = null;
    showFamily = null;
    scrollTo = null;
    openSender = null;
    openViewer = null;
    search = null;
    chatReport = null;
    sendSlowly = null;
    searchReport = null;
    viewerReport = null;
    momentsReport = null;
    scrollBy = null;
    stageStates = null;
    unfoldAll = null;
    showWords = null;
  }
}
