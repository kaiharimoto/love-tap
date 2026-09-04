// Where the regions hang the handles capture mode drives them by.
//
// The regions fill these in as they mount; hooks.dart reads them. Nothing here is called outside
// a CAPTURE build, and a handle that was never filled in fails the capture step loudly rather
// than producing a screenshot of the wrong thing.
typedef Report = Map<String, dynamic>;

class CaptureBus {
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

  /// Settings: begin pairing (host) so the six words are on screen.
  static Future<void> Function()? showWords;

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
    unfoldAll = null;
    showWords = null;
  }
}
