\# Stencil — Flutter Implementation Handoff



A complete spec to rebuild the \*\*Stencil\*\* printable-document/label editor as a Flutter app. The reference is the working web prototype (`Stencil Editor.dc.html`). This document is implementation-agnostic about state management but assumes a single source of truth (Riverpod/Bloc/`ChangeNotifier` all work — examples use a plain `ChangeNotifier` store).



The north star: \*\*Apple-grade calm.\*\* Generous whitespace, hairline separators, soft shadows, one accent color, SF/system type, nothing shouting. When in doubt, remove weight and add space.



> \*\*Priority: recreate the UI first.\*\* The prototype's \*visual design, placement, palette, panels, and interactions\* are the deliverable — match those faithfully. The free-primitive layer (text/shapes/image/QR/barcode) and all the chrome already behave correctly and should be ported 1:1. The \*\*Row/Column/Frame layout engine is the one area whose \*logic\* in the prototype is faulty\*\* — do \*\*not\*\* copy its behavior. §8 below is a clean-room re-spec of how layout is \*supposed\* to work; implement that, not the prototype's version. If anything is ambiguous, prefer the UI/visuals of the prototype and the layout semantics described here.



\---



\## 1. The mental model (read this first)



Stencil has \*\*two distinct kinds of element\*\*, and keeping them separate is the most important architectural decision:



\### Primitives (free layer)

Text, Rectangle, Ellipse, Line, Image, QR, Barcode. They are \*\*absolutely positioned\*\* by `(x, y, w, h, rotation)` on a layer that floats \*above\* everything. They \*\*do not collide\*\*, do not reflow, and ignore all layout. You place them with a toolbar tool + click, then drag/resize freely. Think "stickers on glass."



\### Layout nodes (structure layer)

Row, Column, Frame. They live on a layer \*below\* the primitives and obey \*\*flexbox flow\*\* (`Row`/`Column`/`Flexible` in Flutter). They strictly adhere to their parent:



\- A \*\*Row\*\* placed at the document root occupies the full width at the top and lays children left-to-right.

\- A \*\*Column\*\* lays children top-to-bottom.

\- A \*\*Frame\*\* is a \*leaf component\* — a styled box that holds \*\*content items\*\* (text / image), stacked vertically. It's the "cell" of the system.

\- Rows/Cols may only contain other layout nodes (their `+` adds a \*\*Frame\*\*). Frames may only contain content items (their `+` adds \*\*Text\*\* or \*\*Image\*\*). \*\*You never drag a primitive into a layout node\*\* — structure is built exclusively through the `+` buttons in the Layers tree.



> The two layers print stacked: layout flows in document order underneath, primitives paint on top.



This is the single rule that an earlier build got wrong — do not let primitives participate in layout, and do not let layout nodes be dragged around freely.



\---



\## 2. Design tokens



\### Color



| Token | Hex | Use |

|---|---|---|

| `bg` | `#F5F5F7` | App background |

| `panelBg` | `#FBFBFD` | Side panels (left rail, right inspector) |

| `canvasBg` | `#F0F0F2` | Area immediately around the paper |

| `surface` | `#FFFFFF` | Paper, cards, inputs |

| `ink` | `#1D1D1F` | Primary text / default fill |

| `inkSecondary` | `#515154` | Secondary text |

| `inkTertiary` | `#86868B` | Labels, captions |

| `inkQuaternary` | `#A1A1A6` | Hints, sample values |

| `hairline` | `#E0E0E4` / `#ECECED` / `#F0F0F2` | Borders (darker→lighter by prominence) |

| `hover` | `#EDEDF0` | Button/row hover |

| `segmentTrack` | `#EDEDF0` | Segmented-control track |

| `danger` | `#C0392B` | Delete actions |

| `success` | `#34C759` | "Connected" status dot |

| \*\*`accent`\*\* | \*\*`#0A66D6`\*\* | The one accent. Selection rings, active states, field chips, primary actions |



Accent is themeable. Palette options exposed in the prototype: `#0A66D6` (blue, default), `#C2603E` (terracotta), `#1D1D1F` (graphite), `#34C759` (green), `#5E5CE6` (indigo). Derive translucent variants by appending hex alpha: `accent + '14'` ≈ 8% (`Color.alpha = 0x14`), `'0d'` ≈ 5%, `'1f'` ≈ 12%, `'40'` ≈ 25%.



\*\*Swatch palette\*\* (fill quick-picks): `#1D1D1F, #C2603E, #0A66D6, #34C759, #FF9F0A, #5E5CE6, #FF375F, #FFFFFF`.



\### Type



\- \*\*UI font:\*\* system (`-apple-system` → on Flutter use `.SF Pro Text` / the platform default; `CupertinoTheme` default is correct).

\- \*\*Brand/serif accent:\*\* "New York" (`'New York', 'Iowan Old Style', Georgia, serif`) — used only for the app title and select template headings. On Flutter use `New York` if bundled, else Georgia.

\- \*\*Monospace:\*\* SF Mono (`ui-monospace, 'SF Mono', Menlo, monospace`) — used for field tokens like `{{customer.name}}` and hex codes.



UI sizes (px ≈ logical px in Flutter): captions `10–11`, labels `11–12`, body `12.5–13`, panel titles `13`, app title `15`. Section header labels are `10–11px`, weight 600–700, `letter-spacing: 0.08em`, `text-transform: uppercase`, color `inkTertiary`.



\### Spacing, radius, shadow



\- Spacing scale: 4 / 6 / 7 / 8 / 10 / 12 / 14 / 16 / 20 px. Panels pad `12–16`. Rows pad `6–8`.

\- Radius: inputs/buttons `7–8`, cards `9–12`, pills `13`, segmented track `7–8`, color swatch `5–6`, the \*\*paper\*\* `2` (or a full circle for round labels).

\- Shadows (soft, low):

&#x20; - Panel pill / floating: `0 4px 18px rgba(0,0,0,0.12)` + `0 1px 3px rgba(0,0,0,0.06)`

&#x20; - Paper: `0 14px 50px rgba(0,0,0,0.15)` + `0 2px 8px rgba(0,0,0,0.06)`

&#x20; - Cards: `0 1px 3px rgba(0,0,0,0.08)`

\- Frosted bars (top bar, zoom pill, autocomplete): white at \~82–90% opacity + `BackdropFilter(ImageFilter.blur(sigmaX:18, sigmaY:18))`.



\---



\## 3. Screen layout



```

┌──────────────────────────────────────────────────────────────────────┐

│  TOP BAR  (h≈52–62)  frosted                                           │

│  ‹  Stencil      | Select │ Primitives: T ▭ ◯ / 🖼 ▦ ||| │ Layout: ☰ ▥ ▢ | ↶ ↷ |   Preview(toggle)  Print  Save │

├───────────┬────────────────────────────────────────────┬───────────────┤

│ LEFT RAIL │              CANVAS VIEWPORT               │  RIGHT INSPECTOR │

│ (240) coll│   scroll + zoom; paper centered            │  (294) collapsible│

│           │                                            │  Tabs: Properties │

│  Fields   │        ┌────────────────┐                  │  Layers Data Page │

│  search   │        │     PAPER      │                  │                   │

│  grouped  │        │  layout layer  │                  │  (tab body)       │

│  list     │        │  + primitives  │                  │                   │

│           │        └────────────────┘                  │                   │

│           │                                            │                   │

│           │      ┌─ floating zoom pill ─┐              │                   │

│           │      │ − 100% + | Fit  Snap │              │                   │

└───────────┴──────┴──────────────────────┴──────────────┴───────────────┘

```



Both side panels collapse. When collapsed they show a small floating "peek" button (top-left for Fields, top-right for the inspector). In Flutter: `Row` of three children — left rail, `Expanded` viewport (a `Stack` so the zoom pill can be `Positioned` bottom-center), right inspector. Animate width with `AnimatedSize`/`AnimatedContainer` for the collapse.



\---



\## 4. Data model



```dart

// ---- shared fill (solid OR multi-stop linear gradient) ----

class Fill {

&#x20; String type;          // 'solid' | 'linear'

&#x20; String color;         // solid color, or stop\[0]

&#x20; String c2;            // legacy 2nd stop

&#x20; double angle;         // gradient angle in degrees (0–360), default 90

&#x20; List<String>? stops;  // ≥2 hex stops for multi-stop gradients

}



// ---- PRIMITIVE (free layer) ----

class Primitive {

&#x20; String id;

&#x20; String type;          // text|rect|ellipse|line|image|qr|barcode

&#x20; double x, y, w, h;    // absolute, in PAPER pixels (see §6 for px model)

&#x20; double rot;           // degrees

&#x20; double opacity;       // 0–100



&#x20; // text

&#x20; String? text;         // raw, with {{tokens}} inline

&#x20; String font;          // system|serif|mono|helv

&#x20; double size; int weight; bool italic; bool underline;

&#x20; String align;         // left|center|right

&#x20; double lh; double ls; // line-height multiplier, letter-spacing px



&#x20; Fill? fill;           // text color OR shape fill

&#x20; double radius;        // rect/image corner radius

&#x20; double strokeW; String strokeColor;



&#x20; String? src;          // image URL

&#x20; String? value;        // qr/barcode payload OR image field-binding (may contain {{token}})

&#x20; String fit;           // image: cover|contain

&#x20; String codeColor;     // qr/barcode ink

}



// ---- LAYOUT NODE (structure layer) ----

class LayoutNode {

&#x20; String id;

&#x20; String type;          // row|col|frame  (frame children are content items: text|image)

&#x20; List<String> childIds;

&#x20; double gap; double pad;

&#x20; double flex;          // grow factor (col/frame)

&#x20; double minH;

&#x20; String justify;       // flex-start|center|flex-end|space-between  -> MainAxisAlignment

&#x20; String alignI;        // flex-start|center|flex-end|stretch        -> CrossAxisAlignment

&#x20; Fill? fill;

&#x20; double radius; double strokeW; String strokeColor;



&#x20; // when type is a content item inside a frame, it reuses the text/image

&#x20; // fields from Primitive (text, font, size, fill, src, value, ...)

}



class DocState {

&#x20; // page

&#x20; String template;      // invoice|label|sticker

&#x20; String printer;       // key into PRINTERS

&#x20; String page;          // key into MEDIA, or 'custom'

&#x20; String orient;        // portrait|landscape

&#x20; String pageColor;     // hex

&#x20; Size customMM;        // when page=='custom'



&#x20; // content

&#x20; List<Primitive> els;          // free primitives, paint order = list order

&#x20; List<LayoutNode> layout;      // flat pool of all layout nodes

&#x20; List<String> layoutRoot;      // ordered root node ids (top-level rows/cols)



&#x20; // selection + ui

&#x20; String? sel; String? selKind; // 'primitive' | 'layout' | 'layoutItem'

&#x20; String? editing;              // id of text element in inline-edit

&#x20; double zoom;                  // 0.25–4

&#x20; bool snap; double gridSize;   // 8|16|24

&#x20; String tool;                  // select|text|rect|...|row|col|frame

&#x20; String tab;                   // props|layers|data|page

&#x20; bool leftOpen; bool rightOpen;

&#x20; bool preview;                 // resolve tokens vs show chips

&#x20; int record;                   // index into RECORDS



&#x20; // history

&#x20; List<Snapshot> history; int hidx;   // deep-copied {els,layout,layoutRoot}

}

```



Keep `layout` as a \*\*flat pool keyed by id\*\* with `childIds` references (not a nested tree). This makes add/remove/reorder and the Layers tree trivial, and mirrors the prototype exactly.



\---



\## 5. Page sizes are driven by the selected printer



This is a signature behavior: \*\*media sizes come from the chosen printer's supported media\*\*, not a global list. Picking a printer resets the page to that printer's default.



```

PRINTERS (key → {label, media\[], def, status}):

&#x20; system : System Default        media: letter, a4, legal                 def letter   "Generic PostScript driver"

&#x20; laser  : Office LaserJet M428   media: letter, legal, a4, a5, exec, env10 def letter  "Ready · Tray 2 · USB"

&#x20; zebra  : Zebra ZD420 (Labels)   media: ship4x6, lbl225, addr, cont62      def ship4x6 "Ready · 203 dpi · Network"

&#x20; dymo   : DYMO LabelWriter 550   media: addr, lbl225, sticker3, round3     def sticker3 "Ready · 300 dpi · USB"

&#x20; photo  : Canon PIXMA Photo      media: photo4x6, photo5x7, a4             def photo4x6 "Ready · Borderless · Wi-Fi"



MEDIA (key → {w, h in px @96dpi, label, dims, kind}):

&#x20; letter   816 ×1056  US Letter        8.5 × 11 in     doc

&#x20; legal    816 ×1344  US Legal         8.5 × 14 in     doc

&#x20; a4       794 ×1123  A4               210 × 297 mm    doc

&#x20; a5       559 × 794  A5               148 × 210 mm    doc

&#x20; exec     696 ×1008  Executive        7.25 ×10.5 in   doc

&#x20; env10    912 × 396  Envelope #10     9.5 ×4.125 in   doc

&#x20; ship4x6  384 × 576  Shipping 4×6"    4 × 6 in        label

&#x20; addr     269 ×  96  Address Label    2.8 × 1 in      label

&#x20; lbl225   216 × 120  Multipurpose     2.25×1.25 in    label

&#x20; cont62   235 × 360  Continuous 62mm  62 mm roll      label

&#x20; sticker3 288 × 288  Square Sticker   3 × 3 in        label

&#x20; round3   288 × 288  Round Sticker    3 in ⌀          round   (clip to circle!)

&#x20; photo4x6 384 × 576  Photo 4×6"       4 × 6 in        photo

&#x20; photo5x7 480 × 672  Photo 5×7"       5 × 7 in        photo



CUSTOM: width/height entered in mm → px = round(mm × 3.7795)  (96 dpi). Min 48px.

Landscape swaps w/h. Round kind clips the paper (and print output) to a circle.

```



In the Page tab, the media list only shows `PRINTERS\[printer].media` plus a "Custom size" row. Selecting a doc-kind printer (laser) gives paper sizes; a label printer (zebra/dymo) gives label rolls; the photo printer gives photo sizes. That printer-aware filtering is the feature — preserve it.



\---



\## 6. The canvas / coordinate model



\- The \*\*paper\*\* has a fixed pixel size = `orientW × orientH` (from MEDIA, landscape-swapped).

\- The paper is rendered at scale `zoom` via a `Transform.scale(alignment: topLeft)`. The outer box is `paper \* zoom`.

\- All primitive coordinates are stored in \*\*paper pixels\*\* (unscaled). To convert a pointer event to paper space: `paperPt = (globalPos - paperTopLeftGlobal) / zoom`.

\- \*\*Zoom controls:\*\* `−` / `+` step ±0.15 (clamp 0.25–4). \*\*Fit\*\* computes `min((viewportW-96)/W, (viewportH-96)/H, 4)`. Pill shows `round(zoom\*100)%`.

\- \*\*Snap:\*\* when on, round x/y/w/h to `gridSize` (8/16/24). Show a faint accent grid on the paper (`backgroundSize = grid`, lines at `accent @ \~12%`). While dragging with snap on, draw \*\*alignment guides\*\*: a 1px cyan (`rgba(0,180,230,0.8)`) full-width horizontal line at the element's snapped Y and full-height vertical at snapped X. Clear on pointer-up.

\- The viewport scrolls when the paper overflows; never horizontally-center an overflowing paper (it clips the left edge) — use start-aligned/`safe center`.



\### Selection \& handles (primitives only)

Selected primitive shows an accent outline + 8 resize handles (`nw ne sw se n s w e`), each a small white square with a `1.5/zoom` accent border (divide by zoom so handles stay visually constant). Corners resize both axes; edges one axis; `w`/`n` anchors reposition `x`/`y`. Layout nodes get a simple 2px accent outline on selection, no handles (their size is flow-driven).



\---



\## 7. Rendering each element



Render the SAME way in edit and preview; the only difference is \*\*token resolution\*\* (§9) and whether chips are shown.



| type | Flutter rendering |

|---|---|

| \*\*text\*\* | `Text`/`RichText`. Apply font family, size, weight, italic, underline, align, height=`lh`, letterSpacing=`ls`. \*\*Gradient text:\*\* if `fill.type=='linear'`, paint with `ShaderMask` using a `LinearGradient` of the stops at `angle` — the gradient must clip to the \*\*glyphs\*\*, not the box (the prototype's key bug-fix). Solid: just `color`. |

| \*\*rect\*\* | `Container` with fill (solid or `LinearGradient`), `borderRadius`, optional border. |

| \*\*ellipse\*\* | same but `shape: BoxShape.circle` / `BorderRadius` = 50%. |

| \*\*line\*\* | a thin `Container` (`height=strokeW`, full width) vertically centered. |

| \*\*image\*\* | `src` → `Image.network(fit)`; empty → placeholder box `#ECECED` with "Drop image". Honor `radius` via `ClipRRect`. |

| \*\*qr\*\* | Render a real QR from `value` (use `qr\_flutter`). The prototype fakes a 21×21 deterministic matrix with finder patterns; in Flutter use a proper encoder. Ink = `codeColor`, quiet zone \~4%. |

| \*\*barcode\*\* | Use `barcode`/`barcode\_widget` (Code128) from `value`, with human-readable text below in mono. Ink = `codeColor`. |



\*\*Gradient angle → Flutter:\*\* convert CSS `Ndeg` (0deg = up, clockwise) to `LinearGradient.begin/end`. Easiest: `final r = (angle-90)\*pi/180; begin = Alignment(cos(r+pi),sin(r+pi)); end = Alignment(cos(r),sin(r));` then verify against the swatch preview.



\*\*Multi-stop gradients:\*\* `stops` is an arbitrary-length list (UI allows 2–6). Map directly to `LinearGradient(colors: stops, ...)` with evenly distributed positions.



\---



\## 8. The Layout layer (Row / Column / Frame) — clean re-spec



> ⚠️ \*\*This section overrides the prototype.\*\* The prototype's row/col logic is buggy; build from the rules below. The \*look\* of the layout tree, properties panel, and on-canvas nodes should still match the prototype — only the \*\*semantics\*\* described here are authoritative.



\### 8.1 The three node kinds and what they may contain



| Node | Axis | May contain (children) | Sizing of itself |

|---|---|---|---|

| \*\*Row\*\* | horizontal | Row, Column, \*\*Frame\*\* (any layout nodes) | fills the \*\*full width\*\* of its parent; height hugs its tallest child (≥ `minH`) |

| \*\*Column\*\* | vertical | Row, Column, \*\*Frame\*\* (any layout nodes) | takes a \*\*flex share of the main axis\*\* of its parent; width fills cross axis |

| \*\*Frame\*\* | vertical (content stack) | \*\*content items only\*\*: Text, Image | flex share of parent's main axis; a styled leaf "cell" |



\*\*Containment is strict and enforced by the `+` buttons — there is no drag-in:\*\*

\- Root level holds \*\*Rows\*\* only (the "+ Row" button in the Layers header).

\- A \*\*Row\*\* or \*\*Column\*\*'s `+` adds a \*\*Frame\*\* (the common case). \*(Optionally allow nested Row/Col here later; default to Frame.)\*

\- A \*\*Frame\*\*'s `+` adds a \*\*content item\*\* — Text or Image (offer both).

\- Free \*\*primitives can never enter a layout node\*\*, and layout nodes can never be freely positioned. The two layers never mix.



\### 8.2 How each node measures and lays out (the part the prototype got wrong)



Think of it exactly as CSS flexbox / Flutter `Row`+`Column`+`Expanded`. The bug to avoid: \*\*children of a Row must share the Row's width along the main axis; a Frame/Column inside a Row must be `Expanded` (flex) so siblings divide the row, instead of each trying to take full width and overflowing.\*\*



```

renderRoot:

&#x20; Column(                       // root: vertical stack of full-width Rows

&#x20;   mainAxisSize: min,

&#x20;   children: layoutRoot.map(renderNode)        // each root node is a Row

&#x20; )



renderNode(node) =>

&#x20; ROW:

&#x20;   Padding(pad, Row(

&#x20;     mainAxisAlignment: node.justify,          // start|center|end|spaceBetween

&#x20;     crossAxisAlignment: node.alignI,          // start|center|end|stretch

&#x20;     children: gapped(node.childIds.map(renderFlexChild))   // ← children are flex

&#x20;   ))



&#x20; COLUMN:                       // only meaningful as a child of a Row

&#x20;   Padding(pad, Column(

&#x20;     mainAxisAlignment: node.justify,

&#x20;     crossAxisAlignment: node.alignI,

&#x20;     children: gapped(node.childIds.map(renderNode))

&#x20;   ))                          // wrapped in Expanded(flex) by renderFlexChild



&#x20; FRAME:

&#x20;   Container(

&#x20;     padding: pad,

&#x20;     constraints: BoxConstraints(minHeight: node.minH),

&#x20;     decoration: fill + radius + border,

&#x20;     child: Column(            // content items stack vertically

&#x20;       crossAxisAlignment: stretch,

&#x20;       children: gapped(node.contentItems.map(renderContentItem))   // text/image

&#x20;     )

&#x20;   )                           // wrapped in Expanded(flex) by renderFlexChild



renderFlexChild(child):         // ← THE FIX: every Row/Col child is flexible

&#x20; Expanded(flex: (child.flex\*100).round().clamp(1,∞), child: renderNode(child))



gapped(widgets, axis): interleave SizedBox(gap) between siblings (no trailing gap).

```



Rules that make it behave:

\- \*\*A Row distributes its children across its width\*\* by `flex` (default 1 each → equal columns). Two Frames in a Row each get half the width; set one Frame's `flex` to 2 to make it twice as wide.

\- \*\*A Column inside a Row\*\* is itself an `Expanded` slice of that Row's width, and stacks its own children vertically.

\- \*\*`justify`\*\* = main-axis distribution (a Row's horizontal, a Column's vertical). \*\*`alignI`\*\* = cross-axis alignment. `stretch` makes children fill the cross axis.

\- \*\*`minH`\*\* gives an empty Frame/Column a visible height so it's selectable and droppable-into.

\- \*\*A Frame never lays out siblings\*\* — it only stacks its own Text/Image content items vertically with `gap`.

\- Width is always inherited from the parent chain (root Row = paper width minus page padding); you never set an explicit width on a layout node. Only `flex`, `gap`, `pad`, `minH`, `justify`, `alignI` are authored.



\### 8.3 Worked example



> "A header band, then a two-column body."



```

Root

└─ Row  (gap 16, pad 24)                     // full paper width

&#x20;  ├─ Frame  flex 1   → \[Text "{{company.name}}", Text "INVOICE"]

&#x20;  └─ (second root Row for the body:)

Root

├─ Row (header)  → Frame flex 1

└─ Row  (gap 24, pad 24)                      // body band, full width

&#x20;  ├─ Frame  flex 2  → \[Text "Bill to", Text "{{customer.name}}", Text "{{customer.address}}"]

&#x20;  └─ Frame  flex 1  → \[Text "{{order.total}}"]

```

Result: header row spans the page; body row splits into a 2:1 pair of frames that always divide the available width — never overflow, never collapse. That is the behavior to implement.



\### 8.4 Selection, building, deleting (unchanged from prototype UI)

\- Tapping a layout node selects it (`selKind:'layout'`); tapping a Frame's content item selects it (`selKind:'layoutItem'`). Stop propagation so the parent doesn't also fire.

\- Building is \*\*`+`-driven only\*\* (see 8.1). No element is ever dragged between layers.

\- Delete removes the node and \*\*recursively all descendants\*\* (collect ids; filter the flat pool, `layoutRoot`, and every `childIds`).

\- \*\*Properties for a selected layout node:\*\* Gap, Padding, Flex grow, Min height, Justify (Start/Center/End/Space between), Align (Start/Center/End/Stretch), Fill, Stroke, Radius (frame). A Frame's content item shows the Text or Image property groups instead.



\---



\## 9. Variables / data binding (`{{ … }}`)



The whole point of the editor: text and code payloads contain tokens like `{{customer.name}}` that resolve from a backend record.



\- \*\*Field catalog\*\* (`GROUPS`): `Product` (name/price/sku), `Customer` (name/company/email/address/city), `Order` (number/date/total/items), `Shipping` (service/tracking/weight), `Company` (name/address).

\- \*\*Sample records\*\* (`RECORDS`): two demo rows ("Aurora Lamp", "Field Notebook") — a `Map<String,String>` each. The Data tab lets you switch the preview record; Page/preview re-renders with that row's values.

\- \*\*Resolution:\*\* `resolve(s) = s.replaceAll(/{{ key }}/, record\[key] ?? '{{key}}')`.

\- \*\*Edit vs Preview:\*\*

&#x20; - \*Edit mode:\* render tokens as \*\*chips\*\* — an inline pill (`accent@12%` bg, `accent` text, mono, 1px `accent@25%` border) reading `customer.name`.

&#x20; - \*Preview mode (top-bar toggle):\* render the resolved value inline. The same toggle drives the print output (always resolved).

\- \*\*Inserting fields:\*\*

&#x20; 1. \*\*Left Fields rail\*\* — search + grouped list; clicking a field inserts it into the selected text element (or sets `value` for qr/barcode/image, or spawns a new text primitive if nothing suitable is selected).

&#x20; 2. \*\*Typing `{{`\*\* inside an inline-editing text box opens an \*\*autocomplete popover\*\* (frosted card) filtered by what you type; ↑/↓ to move, ↵/Tab to insert a chip, Esc to dismiss.



For Flutter inline editing, the cleanest approach is a custom `TextField`/`EditableText` where tokens are kept in the raw string and re-parsed; for the chip \*display\* (non-edit), build a `RichText` with `WidgetSpan` chips. Editing-in-place can be simplified to: tap-to-edit opens a focused field showing raw `{{…}}` text with autocomplete; on blur, store raw and render chips/resolved.



\---



\## 10. Panels — exact contents



\### Top bar

`‹ back` · \*\*Stencil\*\* (serif) · centered tool cluster · right actions `Preview · Print · Save`.

Tool cluster: `Select` | label "PRIMITIVES" + `T ▭ ◯ ╱ 🖼 ▦ |||` | label "LAYOUT" + Row/Col/Frame | `↶ ↷` undo/redo. Active tool = `accent@10%` bg + accent icon. Undo/redo dim when unavailable. Selecting a tool then clicking the canvas places that element (primitives at the click point; layout tools add a root Row).



\### Left rail — Fields (240px, collapsible)

Header "Fields" + hint. Search box (focus ring = `accent@13%`). Grouped list; each row: accent dot · mono `path` · right-aligned truncated sample value. Click inserts.



\### Right inspector (294px, collapsible) — 4 tabs

\- \*\*Properties\*\* — context-sensitive to selection:

&#x20; - \*Header:\* type name + Duplicate (primitives) + Delete.

&#x20; - \*Position\* (primitives): X Y W H grid, Rotation slider (−180..180), Opacity slider (0..100).

&#x20; - \*Auto layout\* (layout nodes): Gap, Padding, Flex grow, Min height, Justify, Align.

&#x20; - \*Text:\* font select, size, weight select, Italic/Underline toggles, align segmented (Left/Center/Right), line-height, letter-spacing.

&#x20; - \*Fill / Text color:\* Solid|Gradient segmented. Solid → color well + hex + 8 swatches. Gradient → live preview bar, one row per stop (color well + hex + remove), \*\*+ Add color\*\* (max 6), angle slider.

&#x20; - \*Stroke:\* color + width (shapes/frames).

&#x20; - \*Corner radius:\* slider + number (rect/image/frame).

&#x20; - \*Image:\* URL field + "bind to field".

&#x20; - \*QR/Barcode:\* value field (+ ink color).

&#x20; - Empty state: "Nothing selected."

\- \*\*Layers\*\* — two sections:

&#x20; - \*Layout\* tree: hierarchical, indent per depth, ▸/▾ expanders, per-row `+` (context-aware add) and `✕`. "\*\*+ Row\*\*" header button.

&#x20; - \*Primitives\* list: flat, reverse paint order, with raise ▲ / lower ▼ / delete ✕.

\- \*\*Data\*\* — "Connected · Postgres" card, preview-record picker (avatar, name, sample), and the full field catalog (same insert behavior as left rail).

\- \*\*Page\*\* — Template switcher (Invoice/Label/Sticker mini-thumbnails), Printer select + status line, \*\*Media size\*\* list (printer-filtered) + Custom (mm W/H), Orientation segmented, Background color, Snap toggle + Grid size (8/16/24).



\### Floating zoom pill (bottom-center of viewport)

Frosted rounded bar: `−` · `100%` (tap = Fit) · `+` · divider · `Fit` · `Snap` (accent-tinted when on).



\---



\## 11. Templates (starting documents)



Three built-ins seed `els` (all as \*\*primitives\*\* in the current build). Loading a template also sets its printer + media:



\- \*\*Invoice\*\* → printer `laser`, page `letter`, portrait. Logo rect (gradient), company name (serif), address, "INVOICE" + number + date, "BILLED TO" block, line-item table (description/amount rows), total with gradient accent, footer. Several fields are `{{tokens}}`.

\- \*\*Label\*\* → printer `zebra`, page `ship4x6`. Service + weight, rule, "SHIP TO", name, address block, Code128 barcode of `{{ship.tracking}}`.

\- \*\*Sticker\*\* → printer `dymo`, page `sticker3`. Product name (serif), price (gradient), barcode of `{{product.sku}}`.



Exact coordinates are in the prototype's `invoiceEls()/labelEls()/stickerEls()` — port them 1:1 for pixel-faithful starts, or treat as a starting arrangement and let users rebuild with layout nodes.



\---



\## 12. Interactions \& history



\- \*\*Place:\*\* tool selected → tap canvas → create element at point (snap applied), then auto-switch to Select and select it.

\- \*\*Move:\*\* drag a selected primitive; live-update x/y (snap + guides). Commit to history on pointer-up.

\- \*\*Resize:\*\* drag a handle; clamp min 12px.

\- \*\*Inline text edit:\*\* double-tap a text primitive (or a frame's text item) → focused editor with `{{`-autocomplete.

\- \*\*Keyboard:\*\* `V` select, `T` text, `Delete/Backspace` remove selection, `Esc` deselect, `⌘/Ctrl+Z` undo, `⇧⌘/Ctrl+Z` redo.

\- \*\*History:\*\* push a deep copy of `{els, layout, layoutRoot}` after every committed mutation (place/move-end/resize-end/style change/structure change). Undo/redo restore and clear selection. Use a simple list + index.

\- \*\*Print/PDF:\*\* compose an offscreen render at true page pixel size: layout layer (document-flow) under an absolutely-positioned primitive layer, page background, circle-clip for round media, all tokens \*\*resolved\*\*. In Flutter use the `printing` + `pdf` packages: build the page from the same model into `pw.Widget`s (or rasterize the canvas `RepaintBoundary` at `pixelRatio = dpi/96` for a faithful screenshot-style export). `@page size` = the media's pixel dims.



\---



\## 13. Suggested Flutter package map



| Need | Package |

|---|---|

| QR | `qr\_flutter` |

| Barcode (Code128) | `barcode\_widget` |

| PDF / print | `printing`, `pdf` |

| Color picker | `flutter\_colorpicker` (or a custom Apple-style well + hex) |

| Gradients on text | built-in `ShaderMask` |

| State | your choice — `flutter\_riverpod` recommended |

| Drag/resize | `GestureDetector` + `Stack`/`Positioned` (no package needed) |



\---



\## 14. Build order (recommended)



1\. \*\*Shell:\*\* top bar + collapsible rails + viewport `Stack` + zoom pill. Tokens/theme first.

2\. \*\*Paper + zoom + scroll\*\*, page/media/printer model (Page tab). Get printer-driven sizing working early — it informs everything.

3\. \*\*Primitive model + render\*\* (text/rect/ellipse/line first), place/select/move/resize, handles, snap + guides.

4\. \*\*Properties panel\*\* for primitives (position, fill solid, text). Then gradients (multi-stop), stroke, radius.

5\. \*\*Tokens:\*\* chip rendering, left rail insert, preview toggle + Data records, then `{{`-autocomplete.

6\. \*\*QR + barcode + image\*\* primitives.

7\. \*\*Layout layer:\*\* Row/Col/Frame model, flow render, Layers tree with `+`-driven structure, layout properties.

8\. \*\*History (undo/redo)\*\*, keyboard shortcuts.

9\. \*\*Print/PDF export.\*\*

10\. \*\*Templates\*\* (seed arrangements) + polish (animations, hover states, empty states).



\---



\## 15. Things people get wrong (guardrails)



\- ❌ Letting primitives drop into layout nodes. ✅ Structure is `+`-only; primitives are a separate free layer on top. And row and cols are layouts that are section based with align self. Children added with + can justify self or align self but its not possible for a parent to justify or align children.

\- ❌ Gradient filling the text's bounding box. ✅ `ShaderMask` clips gradient to glyphs.

\- ❌ A global page-size list. ✅ Sizes come from the selected printer's media set.

\- ❌ Centering an overflowing paper (clips left). ✅ Start-aligned scroll.

\- ❌ Handles that grow with zoom. ✅ Divide handle border/size by zoom.

\- ❌ Storing resolved text. ✅ Store raw `{{tokens}}`; resolve only at render/preview/print.

\- ❌ Over-busy chrome. ✅ Hairlines, soft shadows, one accent, lots of air.



\---



\*Reference prototype: `Stencil Editor.dc.html` in this project. Every constant (MEDIA, PRINTERS, GROUPS, RECORDS, template coordinates, exact paddings) can be lifted verbatim from its logic class.\*



