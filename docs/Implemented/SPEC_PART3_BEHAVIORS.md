# Papercraft — Specification Part 3: All Behaviors, Logic & Algorithms

> Part 3 of 3. See SPEC_PART1_DESIGN_DATA.md and SPEC_PART2_SCREENS.md for the rest.

---

## Table of Contents (Part 3)

1. [Drag & Resize Interactions](#1-drag--resize-interactions)
2. [Snap System](#2-snap-system)
3. [History (Undo/Redo)](#3-history-undoredo)
4. [Token / Variable System](#4-token--variable-system)
5. [Barcode Encoding Algorithm](#5-barcode-encoding-algorithm)
6. [PDF Export Logic](#6-pdf-export-logic)
7. [Batch Print DOM Rendering](#7-batch-print-dom-rendering)
8. [Canvas Resize & Element Rescaling](#8-canvas-resize--element-rescaling)
9. [Keyboard Shortcuts](#9-keyboard-shortcuts)
10. [Panning & Zoom](#10-panning--zoom)
11. [Auto-Save](#11-auto-save)
12. [Template Load & Init](#12-template-load--init)
13. [Time-Ago Utility](#13-time-ago-utility)
14. [Formula Validation](#14-formula-validation)
15. [Selection Logic](#15-selection-logic)
16. [Add Element Logic](#16-add-element-logic)
17. [Preview Modal — Full Render Logic](#17-preview-modal--full-render-logic)
18. [Print CSS](#18-print-css)

---

## 1. Drag & Resize Interactions

### Dragging Absolute Elements (CanvasElement)
```
Trigger: mousedown (button=0) on element, not in text-editing mode

Start:
  record {startMx: e.clientX, startMy: e.clientY, startX: el.x, startY: el.y}
  call onDragStart() → activates snap system
  add window mousemove + mouseup listeners

On mousemove:
  dx = (e.clientX - startMx) / scale
  dy = (e.clientY - startMy) / scale
  rawPos = {x: startX+dx, y: startY+dy, width: el.width, height: el.height, id: el.id}
  snappedPos = snapEnabled ? snapFn(rawPos) : rawPos
  call onUpdate({x: round(snapped.x), y: round(snapped.y)})  ← live, no history

On mouseup:
  same calculation → call onCommit({x, y})  ← adds to history
  call onSnap(null) → clears snap guides
  remove listeners

Note: onUpdate is "live" (no history); onCommit adds to undo stack
```

### Dragging Flex Containers (AbsoluteContainer)
```
Same as above EXCEPT:
  Check el.locked before starting — if locked: select only, no drag
  No snap (containers snap not implemented; only leaf elements snap)
  onUpdate/onCommit update container's x/y
```

### Resizing Elements (CanvasElement)
```
Trigger: mousedown on a resize handle

Start:
  record {startMx, startMy, startX: el.x, startY: el.y, startW: el.width, startH: el.height,
          handleDx: handle.dx, handleDy: handle.dy}
  stopPropagation + preventDefault

On mousemove:
  deltaMx = (e.clientX - startMx) / scale
  deltaMy = (e.clientY - startMy) / scale
  newW = max(20, startW + deltaMx * handleDx)
  newH = max(20, startH + deltaMy * handleDy)
  newX = startX + (handleDx < 0 ? startW - newW : 0)
  newY = startY + (handleDy < 0 ? startH - newH : 0)
  call onUpdate({x, y, width, height}) all values rounded

On mouseup:
  same calculation → call onCommit({x, y, width, height})
  remove listeners

Handle dx/dy values determine which corner/edge moves:
  dx=-1 → left edge moves (x shifts)
  dx=0  → no horizontal resize
  dx=1  → right edge moves (no x shift)
  dy=-1 → top edge moves (y shifts)
  dy=0  → no vertical resize
  dy=1  → bottom edge moves (no y shift)
```

### Text Double-Click to Edit
```
doubleClick on text element → set editing=true
Renders <textarea> instead of display div
autoFocus
onBlur: call onUpdate({content: textarea.value}), set editing=false
While editing: drag disabled (editing check in handleMouseDown)
```

---

## 2. Snap System

### Constants
```
SNAP_THRESHOLD = 6px  (in canvas pixel space, before scale)
GRID_SIZE = 10px
```

### computeSnap(dragged, allElements, canvasW, canvasH)
```
dragged: {x, y, width, height, id}
allElements: all elements on canvas

Build candidate snap lines:
  Vertical (x-axis) candidates:
    Always: [0, canvasW/2, canvasW]
    From each element (skip if el.id === dragged.id or el.x is undefined):
      el.x, el.x + el.width/2, el.x + el.width

  Horizontal (y-axis) candidates:
    Always: [0, canvasH/2, canvasH]
    From each element:
      el.y, el.y + el.height/2, el.y + el.height

Find best X snap:
  dragged edges: left(offset=0), center(offset=width/2), right(offset=width)
  For each candidate × each edge:
    dist = |edge.val - candidate|
    if dist < bestDx AND dist < SNAP_THRESHOLD:
      bestDx = dist
      snapX = candidate - edge.offset
  
  If bestDx <= SNAP_THRESHOLD:
    Record active guide: {type:'v', pos: triggering candidate}
  Else:
    snapX = null

Find best Y snap: (same logic with y edges and h candidates)
  top(offset=0), center(offset=height/2), bottom(offset=height)

Apply grid snap (if snapEnabled):
  finalX = snapX !== null ? round(snapX) : round(snapToGrid(dragged.x))
  finalY = snapY !== null ? round(snapY) : round(snapToGrid(dragged.y))
  
  snapToGrid(val) = round(val / GRID_SIZE) * GRID_SIZE

Return: {x: finalX, y: finalY, guides: activeGuides}
```

### Snap Guide Lines
```
Rendered as absolute positioned lines on the canvas:
  Horizontal guide (type='h'): full-width, height=1px, top=guide.pos
  Vertical guide (type='v'): full-height, width=1px, left=guide.pos
  Color: hsl(--accent), z-index=9999, pointer-events=none
```

---

## 3. History (Undo/Redo)

```
MAX_HISTORY = 30
Storage: array of JSON strings
historyIdx: integer pointer (-1 = no history yet)

pushHistory(elements):
  If suppressHistory=true: return
  slice = history.slice(0, historyIdx + 1)
  slice.push(JSON.stringify(elements))
  if slice.length > MAX_HISTORY: slice.shift()
  history = slice
  historyIdx = slice.length - 1

undo():
  if historyIdx <= 0: return
  historyIdx--
  suppressHistory = true
  setElements(JSON.parse(history[historyIdx]))
  suppressHistory = false
  setSelectedId(null)

redo():
  if historyIdx >= history.length - 1: return
  historyIdx++
  suppressHistory = true
  setElements(JSON.parse(history[historyIdx]))
  suppressHistory = false

canUndo = historyIdx > 0
canRedo = historyIdx < history.length - 1

Operations that PUSH to history (via setElementsWithHistory):
  addElement, deleteElement
  commitUpdate (after drag/resize mouseup)
  addChildToContainer, updateChildNode, deleteChildNode
  handleCanvasResize
  lock/unlock shortcut

Operations that do NOT push (live visual feedback only):
  updateElement during drag/resize mousemove
```

---

## 4. Token / Variable System

### Token Formats
```
Direct field:   {{entityName.fieldName}}
Computed field: {{computed:computedName}}
```

### resolveTokens(text, record, entityName)
```
Input:
  text: string possibly containing {{...}} tokens
  record: data record object
  entityName: string (for computed field lookup)

Load computed fields from localStorage["computed_{entityName}"]

For each {{path}} match:
  If path.startsWith('computed:'):
    name = path.slice(9)
    cf = computedFields.find(c => c.name === name)
    if not found: return original match unchanged
    
    Resolve formula:
      Replace all {{fieldPath}} in formula with numeric values from record
        parts = fieldPath.split('.')
        traverse record via parts
        return Number(val) || 0 (numeric coercion)
    
    Evaluate (safe):
      if resolved matches /^[\d\s\+\-\*\/\(\)\.]+$/:
        result = eval("return (" + resolved + ")")
        return String(Math.round(result * 100) / 100)
      else: return original match
  
  Else (direct field):
    parts = path.split('.')
    traverse record via parts
    return String(value) if found, else original match unchanged
```

### Token Display in Editor (NOT preview)
```
Tokens shown as styled chips via innerHTML:
1. Escape HTML: & → &amp;  < → &lt;  > → &gt;
2. \n → <br/>
3. {{token}} → <span class="variable-token">{{token}}</span>

.variable-token CSS:
  display: inline-block
  background: hsl(245 72% 58% / 10%)
  color: hsl(245 72% 52%)
  font-family: DM Mono
  font-size: 0.78em
  padding: 0px 5px
  border-radius: 3px
  border: 1px solid hsl(245 72% 58% / 25%)
  vertical-align: baseline
  white-space: nowrap
  cursor: default
  user-select: none
  letter-spacing: -0.01em
```

### Token Insertion
```
User clicks a field in DataPanel while a text element is selected:
  token = "{{entityName.fieldName}}"
  or for computed: "{{computed:fieldName}}"
  
  onInsertVariable(token):
    find currently selected text element
    onUpdate({content: (el.content || '') + token})
    (appended to end of existing content)
```

---

## 5. Barcode Encoding Algorithm

### CODE128B Pure JS Implementation

```
Supported: ASCII 32–126 (space to tilde ~)
Invalid input: show "Invalid barcode" text in gray

Encoding:
  CODE128B_START = 104
  CODE128_STOP_PATTERN = '1100011101011'  (13 modules)
  
  chars = value.split('').map(c => charCode(c) - 32)
  if any char < 0 or > 94: return null (invalid)
  
  checksum:
    sum = 104  (START code value)
    for each char at index i (0-based):
      sum += chars[i] * (i + 1)
    checksum = sum % 103
  
  code sequence: [START=104, ...chars, checksum]
  
  binaryString = ''
  for each code in sequence:
    binaryString += PATTERNS[code]
  binaryString += STOP_PATTERN
  
  PATTERNS = array of 107 11-module binary strings (index 0–106)
  Each pattern is 11 characters of '0' and '1'
  START is index 104: '11010111100'
  STOP is always: '1100011101011'
```

### Canvas Rendering
```
Setup:
  canvas.width = width * devicePixelRatio
  canvas.height = height * devicePixelRatio
  ctx.scale(dpr, dpr)
  fill background: el.background || '#ffffff'

Bars:
  textH = displayValue ? 14 : 0
  barH = height - textH - 4   (4px top margin)
  barWidth = width / binaryString.length   (fractional)
  
  ctx.fillStyle = el.color || '#000000'
  for i in range(binaryString.length):
    if binaryString[i] === '1':
      ctx.fillRect(floor(i * barWidth), 2, ceil(barWidth), barH)

Human-readable text (if displayValue):
  ctx.font = '10px Inter'
  ctx.textAlign = 'center'
  ctx.textBaseline = 'bottom'
  ctx.fillText(content, width/2, height - 1)

Invalid barcode:
  ctx.fillStyle = '#cccccc'
  ctx.font = '10px Inter'
  ctx.textAlign = 'center'
  ctx.fillText('Invalid barcode', width/2, height/2)
```

---

## 6. PDF Export Logic

### Single Export (from Preview Modal)
```
Captures canvasRef.current (the unscaled preview canvas div)

html2canvas(canvasEl, {
  scale: 3,
  useCORS: true,
  backgroundColor: '#ffffff',
  width: canvasWidthPx,
  height: canvasHeightPx,
  windowWidth: canvasWidthPx,
  windowHeight: canvasHeightPx,
})

→ PNG data URL

jsPDF({
  orientation: widthMm > heightMm ? 'landscape' : 'portrait',
  unit: 'mm',
  format: [widthMm, heightMm],
})
pdf.addImage(imgData, 'PNG', 0, 0, widthMm, heightMm)
pdf.save('{templateName}.pdf')
```

### Batch PDF Export
```
For each selected record (in order):
  1. Create hidden container:
     div: position=fixed, left=-9999px, top=0
     width=canvasPx, height=canvasPx, background=white, overflow=hidden

  2. renderCanvasToDOM(container, elements, record, wPx, hPx)
     (see §7 below)

  3. Wait 2 requestAnimationFrame cycles (for images to load)

  4. html2canvas(container, {scale:2, useCORS:true, backgroundColor:'#ffffff', logging:false})
     → JPEG data at 0.92 quality

  5. if i > 0: pdf.addPage([wMm, hMm], orientation)
     pdf.addImage(imgData, 'JPEG', 0, 0, wMm, hMm)

  6. Remove hidden container from DOM

pdf.save('{name}-{n}records.pdf')
```

---

## 7. Batch Print DOM Rendering

### renderCanvasToDOM(container, elements, record, wPx, hPx)
```
sorted = elements.sort by zIndex ascending
skip isSection=true elements (sections not rendered in batch)

For each element:
  div with inline style:
    position:absolute
    left:{el.x}px, top:{el.y}px
    width:{el.width}px, height:{el.height}px
    opacity:{el.opacity ?? 1}
    box-sizing:border-box
    z-index:{el.zIndex || 1}
    transform:rotate({el.rotation}deg) if rotation

  By type:
  
  'text':
    text = resolveTokens(el.content, record)
    div.style: fontFamily, fontSize+'px', fontWeight, fontStyle, textAlign
               color, lineHeight, whiteSpace='pre-wrap', overflow='hidden'
    div.textContent = text
  
  'shape':
    div.style: background=el.fill, border={strokeWidth}px solid {stroke}
               border-radius: '50%' (circle) | '{borderRadius}px'
  
  'image' (if src):
    img = createElement('img')
    img.src = el.src, img.crossOrigin = 'anonymous'
    img.style: width/height 100%, object-fit, border-radius, display=block
    div.appendChild(img)
  
  'qr':
    content = resolveTokens(el.content, record)
    size = round(min(el.width, el.height))
    img.src = api.qrserver.com URL
    img.crossOrigin = 'anonymous'
    img.style: width/height 100%, display=block
    div.appendChild(img)
  
  else: continue (skip)
  
  container.appendChild(div)
```

---

## 8. Canvas Resize & Element Rescaling

```
Trigger: user applies new dimensions in PageSettingsPanel

Inputs: newWidthMm, newHeightMm

Calculate scale factors:
  oldWPx = mmToPx(template.canvas_width_mm)
  oldHPx = mmToPx(template.canvas_height_mm)
  newWPx = mmToPx(newWidthMm)
  newHPx = mmToPx(newHeightMm)
  scaleX = newWPx / oldWPx
  scaleY = newHPx / oldHPx

For each element:
  If isSection=true: skip (sections are flow-based, no position)
  
  Else:
    x         = round(el.x * scaleX)          if el.x != null
    y         = round(el.y * scaleY)          if el.y != null
    width     = round(el.width * scaleX)      if el.width != null
    height    = round(el.height * scaleY)     if el.height != null
    fontSize  = round(el.fontSize * min(scaleX, scaleY) * 10) / 10   if el.fontSize != null

Save rescaled elements to history
Update template dimensions locally and in database
```

---

## 9. Keyboard Shortcuts

All shortcuts ignored when focus is inside INPUT, TEXTAREA, or SELECT.

```
Space (keydown):   set panMode=true, spaceHeld=true, prevent default scroll
Space (keyup):     set panMode=false, spaceHeld=false

Delete/Backspace:  delete selected element or selected child

Cmd/Ctrl + Z:      undo (if !shiftKey)
Cmd/Ctrl + Shift+Z: redo
Cmd/Ctrl + Y:      redo
Cmd/Ctrl + S:      save template
Cmd/Ctrl + P:      window.print()

F or f:            fit to view
G or g:            toggle gridEnabled
S or s:            toggle snapEnabled
H/h or V/v:        toggle panMode
+ or =:            zoom in
-:                 zoom out

L or l:            if selected element is a row or col container:
                     toggle el.locked (true ↔ false)
                     calls commitUpdate (adds to history)
```

---

## 10. Panning & Zoom

### Pan by Mouse (pan mode active)
```
Pan mode activated by: space key held, panMode state=true, or middle mouse button

Trigger: mousedown on workspace

On mousedown:
  if button===1 OR panMode OR spaceHeld:
    preventDefault
    isPanning = true
    record {startX: e.clientX, startY: e.clientY, startOffX: panOffset.x, startOffY: panOffset.y}
    add window mousemove + mouseup

On mousemove:
  if !isPanning: return
  panOffset = {
    x: startOffX + (e.clientX - startX),
    y: startOffY + (e.clientY - startY)
  }

On mouseup:
  isPanning = false, remove listeners
```

### Zoom by Scroll
```
Trigger: wheel event on workspace
if e.ctrlKey OR e.metaKey:
  preventDefault
  if e.deltaY < 0: zoomIn()
  else: zoomOut()
```

### Fit to View
```
canvasWPx = mmToPx(template.canvas_width_mm)
canvasHPx = mmToPx(template.canvas_height_mm)
availW = workspaceRef.clientWidth - 80
availH = workspaceRef.clientHeight - 80
fitW = floor((availW / canvasWPx) * 100)
fitH = floor((availH / canvasHPx) * 100)
fit = min(fitW, fitH, 200)
zoom = nearest value in ZOOM_STEPS
panOffset = {x:0, y:0}
```

---

## 11. Auto-Save

```
Trigger: any change to elements array (when template loaded)
Timer: debounced 2000ms after last change

Logic:
  clearTimeout(autoSaveTimer)
  autoSaveTimer = setTimeout(() => {
    Template.update(id, {elements: JSON.stringify(elements)})
  }, 2000)

Manual save (Cmd+S or Save button):
  immediate Template.update
  sets saving=true → false
```

---

## 12. Template Load & Init

```
On editor mount (route /editor/:id):
1. Template.filter({id}) → take first result
2. If not found: navigate to '/'
3. setTemplate(result)
4. setElements(JSON.parse(result.elements || '[]'))
5. setLoading(false)

6. Compute initial zoom:
   availW = window.innerWidth - 360
   canvasPx = mmToPx(template.canvas_width_mm || 210)
   fit = floor(min(100, (availW / canvasPx) * 100))
   zoom = ZOOM_STEPS.reduce(nearest step)
```

---

## 13. Time-Ago Utility

```
input: ISO date string

diff = (Date.now() - new Date(dateStr).getTime()) / 1000  [seconds]

if diff < 60:    return "just now"
if diff < 3600:  return "{floor(diff/60)}m ago"
if diff < 86400: return "{floor(diff/3600)}h ago"
else:            return "{floor(diff/86400)}d ago"
```

---

## 14. Formula Validation

```
Used in DataPanel computed field creation

validateFormula(formula):
  1. Replace all {{...}} tokens with literal '1':
     sanitized = formula.replace(/\{\{[^}]+\}\}/g, '1')
  2. Test: /^[\d\s\+\-\*\/\(\)\.\,]+$/.test(sanitized)
  3. If fails: show error "Only + − × ÷ and field tokens are allowed"

Resolution at render time (resolveTokens):
  Replace {{tokens}} with numeric values (Number(val) || 0)
  Test result against /^[\d\s\+\-\*\/\(\)\.]+$/
  If passes: evaluate safely using Function()
  Result: String(Math.round(result * 100) / 100)
```

---

## 15. Selection Logic

```
selectedId = top-level element id (or null)
selectedChildId = id of a node inside a container tree (or null)

Selected element (for properties panel):
  if selectedChildId: findNodeInTree(elements, selectedChildId)
  else if selectedId: elements.find(e => e.id === selectedId)
  else: null

isChild = selected element has no x/y properties (flex child)
isContainer = selected element type is 'row' or 'col'

Clicking on workspace background (not element):
  setSelectedId(null), setSelectedChildId(null)

Clicking on a tree node:
  if nodeId is top-level: setSelectedId(nodeId), setSelectedChildId(null)
  else: setSelectedChildId(nodeId) (selectedId stays = parent container id)

Clicking on an absolute element:
  setSelectedId(el.id), setSelectedChildId(null)

Clicking on a child in canvas:
  setSelectedChildId(child.id)
  (does NOT change selectedId)
```

---

## 16. Add Element Logic

```
addElement(el):
  if el.isSection:
    append to elements array (no zIndex needed)
  else:
    maxZ = max(el.zIndex of all elements) or 0
    append {…el, zIndex: maxZ + 1}
  
  setSelectedId(el.id)
  push to history

New elements are placed at x:40, y:40 (or x:20, y:20 for text)
```

---

## 17. Preview Modal — Full Render Logic

### PreviewCanvas renders ALL element types

```
Elements sorted by zIndex ascending

For each element:
  style = {position:absolute, left:x, top:y, width, height, opacity, transform:rotate, zIndex, boxShadow}
  
  'text':
    resolved = resolveTokens(el.content, record, entityName)
    Render as plain text div (NO token chips in preview)
    Apply textGradient if set

  'shape':
    background = gradient CSS | el.fill
    border = {strokeWidth}px solid {stroke}
    border-radius = 50% (circle) | {borderRadius}px

  'image':
    <img> with crossOrigin="anonymous" if src set

  'qr':
    resolved content = resolveTokens(el.content, record, entityName)
    <img> from api.qrserver.com with resolved content
    crossOrigin="anonymous"

  'barcode':
    resolved content = resolveTokens(el.content, record, entityName)
    <BarcodeRenderer el={{...el, content:resolved}} />

  'row'|'col' (absolute, not isSection):
    flex container with all children
    Children rendered via PreviewChild (see below)

  isSection rows/cols:
    Not individually rendered (sections are in flow, not absolute in preview)
    TODO: implement section rendering in preview if needed
```

### PreviewChild rendering (inside row/col preview)
```
For each child type:
  'text':
    resolveTokens for content
    width/height: fixed or auto (undefined)
    white-space: pre-wrap, overflow-wrap: break-word
    textGradient applied
  
  'shape': background, border, border-radius
  
  'image': <img> crossOrigin="anonymous", or placeholder
  
  'qr': wrapper + QRCodeBox (api.qrserver.com) with resolved content
  
  'barcode': wrapper + BarcodeRenderer with resolved content
  
  nested container: flex div, renders its own children recursively
```

---

## 18. Print CSS

```css
@media print {
  body * { visibility: hidden !important; }
  #print-canvas, #print-canvas * { visibility: visible !important; }
  #print-canvas {
    position: absolute !important;
    left: 0 !important;
    top: 0 !important;
    box-shadow: none !important;
    margin: 0 !important;
  }
  @page { margin: 0; }
}
```

The canvas is rendered with `id="print-canvas"`. When window.print() is called, only the canvas content is visible. The canvas renders at its full unscaled pixel size (not affected by the zoom transform).

---

## Appendix A: Data Loading Patterns

```
Template.filter({id: routeId}) → array → take [0]
Template.list('-updated_date', 100) → all user's templates
Entity.schema() → {type:'object', properties:{...}}
Entity.list('-updated_date', 50|200) → records array

System fields excluded from DataPanel field list:
  id, created_date, updated_date, owner_id, thumbnail_url,
  elements, doc_content, variable_mappings
```

## Appendix B: Auth Flow

```
Auth state loaded async on startup → loading spinner while checking
After load: if not authenticated → redirect to /login
User object: {id, email, full_name, role}

Templates are user-owned (owner_id = user.id on create)
Template.list() returns all templates for the current user
```

## Appendix C: Record Label Fallback Chain

For displaying a record's human-readable name:
```
r.name || r.title || r.full_name || r.label || r.id.slice(0, 8) || "Record {index+1}"
```

## Appendix D: Complete State Flow — Editor

```
┌─ Route: /editor/:id
│
├─ Load template → parse elements
│
├─ User actions:
│   ├─ Click toolbar button → addElement → pushHistory
│   ├─ Click element → setSelectedId → PropertiesPanel updates
│   ├─ Drag element → updateElement (live) → mouseup: commitUpdate → pushHistory
│   ├─ Resize element → same as drag
│   ├─ Edit text → inline textarea → onBlur: commitUpdate
│   ├─ Change property → handleUpdateSelected → commitUpdate → pushHistory
│   ├─ Add child to container → addChildToContainer → pushHistory
│   ├─ Delete → handleDeleteSelected → pushHistory
│   ├─ Undo → restores previous elements snapshot from history
│   ├─ Redo → moves forward in history
│   └─ Save → Template.update(id, {elements: JSON.stringify(elements)})
│
├─ Auto-save: debounced 2s after any elements change
│
└─ Preview → PreviewModal renders clean version with resolved tokens
    └─ Export PDF → html2canvas on clean canvas → jsPDF
```

## Appendix E: Flutter Implementation Notes

When implementing in Flutter:

1. **Canvas coordinate system**: Use a Stack widget with Positioned children. Canvas = Container with exact pixel dimensions.

2. **Scale (zoom)**: Wrap canvas in `Transform.scale(scale: zoom/100, alignment: Alignment.topLeft)` inside a sized box.

3. **Drag**: Use `GestureDetector` with `onPanUpdate` for dragging. Divide delta by scale factor.

4. **Text tokens**: Display with `TextSpan` / `RichText`. Chip styling via `WidgetSpan` with decorated `Container`.

5. **Flex containers**: Use `Row`/`Column` with `Flexible`/`Expanded` widgets for flex children.

6. **QR codes**: Use `qr_flutter` package or HTTP call to api.qrserver.com for simplicity.

7. **Barcodes**: Use `barcode_widget` package (CODE128 support).

8. **PDF export**: Use `pdf` package (dart) + `printing` package. Render elements to PDF page with their mm coordinates (not px).

9. **History**: Store snapshots as JSON strings in a List. Use `jsonEncode`/`jsonDecode`.

10. **Properties panel**: Use a `ListView` of expandable `ExpansionTile` sections.

11. **Gradients**: Flutter's `LinearGradient`/`RadialGradient` with `BoxDecoration`. For text: use `ShaderMask`.

12. **Resize handles**: 8 small `GestureDetector` widgets positioned around the selected element using a `Stack`.

13. **Key unit**: All canvas math in px (96dpi). Convert to mm for PDF: `mm = px / 3.7795275591`.

14. **Section containers**: Use a `Column` at top of the canvas Stack containing all `isSection=true` containers as full-width Rows.
``