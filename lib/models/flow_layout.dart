/// Layout decisions shared by the two renderers.
///
/// Papercraft paints every template twice, through two independent code paths:
/// [PrintService] builds a `pw.*` tree for the PDF, and `ElementRenderer`
/// builds a Flutter tree for the editor canvas and the read-only preview. They
/// are supposed to agree. Historically they did not — the PDF forced every row
/// child into `Expanded` and stretched the cross axis, while the canvas used
/// `CrossAxisAlignment.start`; `alignSelf` was honoured on the canvas and
/// silently dropped in print; and `alignItems` was read by neither, so a
/// property the model carries did nothing anywhere.
///
/// Every one of those was a layout *decision* duplicated in two places. This
/// file holds the decisions once, as pure functions over the model, so the two
/// renderers can only differ in how they paint — never in what they compute.
library;

import 'element_model.dart';

/// Cross-axis placement of a container's children, decoded from the container's
/// `alignItems` (or a child's `alignSelf`).
enum FlowAlign {
  start,
  center,
  end,
  stretch,
}

/// Decodes a CSS-flavoured alignment string (`flex-start`, `center`,
/// `flex-end`, `stretch`) into a [FlowAlign].
///
/// Unknown and empty values fall back to [fallback] rather than throwing: the
/// value reaches here straight from stored template JSON, and a template
/// written by a newer editor must not crash an older renderer.
FlowAlign flowAlign(String? value, {FlowAlign fallback = FlowAlign.stretch}) {
  switch (value) {
    case 'flex-start':
    case 'start':
      return FlowAlign.start;
    case 'center':
      return FlowAlign.center;
    case 'flex-end':
    case 'end':
      return FlowAlign.end;
    case 'stretch':
      return FlowAlign.stretch;
    default:
      return fallback;
  }
}

/// The cross-axis alignment [parent] applies to its children.
FlowAlign containerAlign(ContainerElement parent) =>
    flowAlign(parent.alignItems);

/// The cross-axis alignment [child] requests for itself, or `null` when it
/// defers to its parent's [containerAlign].
///
/// `'auto'` is the properties panel's "inherit" value and means exactly that.
FlowAlign? childAlign(CanvasElement child) {
  final self = alignSelfOf(child);
  if (self == null || self == 'auto') return null;
  return flowAlign(self, fallback: FlowAlign.stretch);
}

/// The `alignSelf` of any element, or `null` when it has none.
///
/// [CanvasElement] does not declare `alignSelf` — the six concrete types each
/// carry their own copy — so this is a type switch rather than a getter.
String? alignSelfOf(CanvasElement c) {
  if (c is TextElement) return c.alignSelf;
  if (c is ShapeElement) return c.alignSelf;
  if (c is ImageElement) return c.alignSelf;
  if (c is QrElement) return c.alignSelf;
  if (c is BarcodeElement) return c.alignSelf;
  if (c is ContainerElement) return c.alignSelf;
  return null;
}

/// The `flex` of any element, or `null` when it has none.
///
/// Same reason as [alignSelfOf]. Note both renderers previously carried their
/// own copy of this and **they disagreed**: the PDF's omitted [QrElement] and
/// [BarcodeElement], so a QR code in a row got a different width in print than
/// on screen.
int? flexOf(CanvasElement c) {
  if (c is TextElement) return c.flex;
  if (c is ShapeElement) return c.flex;
  if (c is ImageElement) return c.flex;
  if (c is QrElement) return c.flex;
  if (c is BarcodeElement) return c.flex;
  if (c is ContainerElement) return c.flex;
  return null;
}

/// How one child sits inside its container.
class ChildSlot {
  /// Wrap in `Expanded` — the child takes a share of the main axis.
  ///
  /// Row children only. A `false` here means the child is **intrinsic**: it
  /// takes exactly the width it needs, which is what a label beside a value or
  /// a right-hugging total column requires.
  final bool expand;

  /// The `Expanded` weight. Meaningful only when [expand].
  final int flex;

  /// Column children only — stretch the child across the container's width.
  final bool stretchWidth;

  /// A height the child declared for itself, or `null` for intrinsic height.
  final double? fixedHeight;

  /// Cross-axis placement for this child, or `null` to inherit the container's.
  final FlowAlign? align;

  const ChildSlot({
    required this.expand,
    this.flex = 1,
    this.stretchWidth = false,
    this.fixedHeight,
    this.align,
  });
}

/// How [child] should be laid out inside [parent].
///
/// **Backward compatibility.** A row child with `flex == 0` still expands with
/// weight 1, exactly as before — `flex: 0` is what every `createChild` factory
/// writes, so treating it as "no flex" would silently re-lay-out every template
/// ever drawn in the editor. Only a genuinely absent `flex` (which no editor
/// has ever produced, and which the DSL uses deliberately) means intrinsic.
ChildSlot slotFor(ContainerElement parent, CanvasElement child) {
  final align = childAlign(child);
  if (parent.type == 'row') {
    final f = flexOf(child);
    if (f == null) {
      return ChildSlot(expand: false, fixedHeight: child.height, align: align);
    }
    return ChildSlot(expand: true, flex: f > 0 ? f : 1, align: align);
  }
  return ChildSlot(
    expand: false,
    stretchWidth: true,
    fixedHeight: child.height,
    align: align,
  );
}

/// True when every element flows — no absolute `x`/`y` anywhere at the top
/// level.
///
/// Such a template is a plain vertical list of sections, which is the one shape
/// `pw.MultiPage` can paginate. Anything with an absolutely positioned element
/// has to stay on the single-page `pw.Page` + `pw.Stack` path, because a
/// `Positioned` has no meaning once content reflows across pages.
bool isFlowOnly(List<CanvasElement> elements) =>
    elements.isNotEmpty && elements.every((e) => e.isSection);
