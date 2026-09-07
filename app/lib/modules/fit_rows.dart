// Whole rows, ending where the paper ends.
//
// Us puts five modules on one desk. A shell that budgets in *rows* cannot know what a row costs —
// a date is a ticket stub the better part of two hundred points tall and a to-do is a line under
// fifty — so two rows each ran three modules off the bottom of the screen while the report for the
// same artifact listed all five. A shell that budgets in *points* and clips gets the other failure:
// a to-do that reads `get someone out to look at the` and then stops at a hard horizontal edge.
//
// This lays children out in order and keeps the ones that fit whole. Nothing is sliced, nothing is
// scaled, and the budget is enforced by the layout rather than by a constant that can be wrong.
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

class FitRows extends MultiChildRenderObjectWidget {
  const FitRows({super.key, required this.maxHeight, required super.children});

  /// The points of desk this module was given.
  final double maxHeight;

  @override
  RenderFitRows createRenderObject(BuildContext context) => RenderFitRows(maxHeight: maxHeight);

  @override
  void updateRenderObject(BuildContext context, RenderFitRows renderObject) {
    renderObject.maxHeight = maxHeight;
  }
}

class _FitRowsParentData extends ContainerBoxParentData<RenderBox> {
  bool shown = false;
}

class RenderFitRows extends RenderBox
    with ContainerRenderObjectMixin<RenderBox, _FitRowsParentData>,
        RenderBoxContainerDefaultsMixin<RenderBox, _FitRowsParentData> {
  RenderFitRows({required double maxHeight}) : _maxHeight = maxHeight;

  double _maxHeight;
  double get maxHeight => _maxHeight;
  set maxHeight(double v) {
    if (v == _maxHeight) return;
    _maxHeight = v;
    markNeedsLayout();
  }

  @override
  void setupParentData(RenderObject child) {
    if (child.parentData is! _FitRowsParentData) child.parentData = _FitRowsParentData();
  }

  @override
  void performLayout() {
    final width = constraints.maxWidth.isFinite ? constraints.maxWidth : 0.0;
    var used = 0.0;
    var child = firstChild;
    var first = true;
    var stopped = false;
    while (child != null) {
      final pd = child.parentData! as _FitRowsParentData;
      child.layout(BoxConstraints(minWidth: width, maxWidth: width), parentUsesSize: true);
      final h = child.size.height;
      // The first row is always kept: a module with a heading and nothing under it is not a
      // module on the desk, and a row that overruns its share by a little is a smaller lie than
      // a module that is not there. Every row after the first has to fit whole, and the paper
      // ends at the first one that does not — a later, shorter row is not promoted past a longer
      // one it comes after, because that would reorder the list to fill a gap.
      if (!stopped && (first || used + h <= _maxHeight)) {
        pd.shown = true;
        pd.offset = Offset(0, used);
        used += h;
      } else {
        stopped = true;
        pd.shown = false;
        pd.offset = Offset.zero;
      }
      first = false;
      child = pd.nextSibling;
    }
    size = constraints.constrain(Size(width, used));
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    var child = firstChild;
    while (child != null) {
      final pd = child.parentData! as _FitRowsParentData;
      if (pd.shown) context.paintChild(child, offset + pd.offset);
      child = pd.nextSibling;
    }
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    var child = lastChild;
    while (child != null) {
      final pd = child.parentData! as _FitRowsParentData;
      if (pd.shown) {
        final hit = result.addWithPaintOffset(
          offset: pd.offset,
          position: position,
          hitTest: (BoxHitTestResult r, Offset p) => child!.hitTest(r, position: p),
        );
        if (hit) return true;
      }
      child = pd.previousSibling;
    }
    return false;
  }

  @override
  double computeMinIntrinsicWidth(double height) => 0.0;

  @override
  double computeMaxIntrinsicWidth(double height) {
    var w = 0.0;
    var child = firstChild;
    while (child != null) {
      w = w > child.getMaxIntrinsicWidth(height) ? w : child.getMaxIntrinsicWidth(height);
      child = (child.parentData! as _FitRowsParentData).nextSibling;
    }
    return w;
  }

  @override
  double computeMinIntrinsicHeight(double width) => computeMaxIntrinsicHeight(width);

  @override
  double computeMaxIntrinsicHeight(double width) {
    var used = 0.0;
    var child = firstChild;
    var first = true;
    while (child != null) {
      final h = child.getMaxIntrinsicHeight(width);
      if (!first && used + h > _maxHeight) break;
      used += h;
      first = false;
      child = (child.parentData! as _FitRowsParentData).nextSibling;
    }
    return used;
  }
}
