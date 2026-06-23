# Papercraft — Specification Part 2: All Screen Layouts & Components

> Part 2 of 3. See SPEC_PART1_DESIGN_DATA.md and SPEC_PART3_BEHAVIORS.md for the rest.

---

## Table of Contents (Part 2)

1. [Application Routes](#1-application-routes)
2. [Dashboard Screen](#2-dashboard-screen)
3. [Editor Screen — Layout Overview](#3-editor-screen--layout-overview)
4. [Editor — Toolbar](#4-editor--toolbar)
5. [Editor — Left Sidebar (Data Panel)](#5-editor--left-sidebar-data-panel)
6. [Editor — Canvas Workspace](#6-editor--canvas-workspace)
7. [Editor — CanvasElement (Absolute)](#7-editor--canvaselement-absolute)
8. [Editor — FlexContainer & FlexChild](#8-editor--flexcontainer--flexchild)
9. [Editor — Right Sidebar (Properties Panel)](#9-editor--right-sidebar-properties-panel)
10. [Editor — Layers Tree (WidgetTree)](#10-editor--layers-tree-widgettree)
11. [Editor — Page Settings Panel](#11-editor--page-settings-panel)
12. [Editor — ViewportNav (Floating Bottom Bar)](#12-editor--viewportnav-floating-bottom-bar)
13. [Preview Modal](#13-preview-modal)
14. [Batch Print Modal](#14-batch-print-modal)
15. [New Template Modal](#15-new-template-modal)

---

## 1. Application Routes

| Path | Screen | Auth Required |
|---|---|---|
| `/` | Dashboard | Yes |
| `/editor/:id` | Editor | Yes |
| `/login` | Login | No |
| `/register` | Register | No |
| `/forgot-password` | Forgot Password | No |
| `/reset-password` | Reset Password | No |

Unauthenticated access to protected routes → redirect to `/login`.

---

## 2. Dashboard Screen

### Overall Layout
```
min-height: 100vh
background: hsl(--background)

┌─────────────────────────────────────────────────┐
│  NAVBAR  sticky top, z=20, h=64px               │
├─────────────────────────────────────────────────┤
│  CONTENT  max-width=1280px, px=24px, py=40px    │
│    Hero heading (mb=40px)                        │
│    Filter bar (mb=32px)                          │
│    Template grid                                 │
└─────────────────────────────────────────────────┘
```

### Navbar
```
height: 64px
background: rgba(255,255,255,0.98)
backdrop-filter: blur(4px)
border-bottom: 1px solid hsl(--border)
sticky top=0, z-index=20

Left group (gap=12px):
  Logo square: 32×32px, bg=hsl(--primary), border-radius=8px
    FileText icon 16px, color=hsl(--primary-foreground)
  App name: "Papercraft"
    font=Playfair Display, size=20px, weight=600, color=hsl(--foreground)

Right group (gap=12px):
  User name/email: text=14px, color=hsl(--muted-foreground), hidden on mobile

  "New Template" button:
    px=16px, py=8px, border-radius=12px
    bg=hsl(--accent), color=hsl(--accent-foreground)
    font-weight=600, text=14px
    Plus icon 16px (left of text)
    hover: bg=hsl(--accent/90%), shadow-sm
```

### Hero Section
```
mb=40px

"Your Templates"
  font=Playfair Display, size=36px, weight=600, color=hsl(--foreground), mb=8px

"Design beautiful labels and documents connected to live data."
  font=Inter, size=16px, color=hsl(--muted-foreground)
```

### Filter Bar
```
flex-row (wraps on mobile), gap=12px, mb=32px

Search input:
  flex=1, max-width=384px
  position=relative
  Search icon 14px: absolute left=12px, vertically centered, color=muted-foreground
  input:
    width=100%, text=14px
    border=1px hsl(--border), border-radius=12px
    pl=36px, pr=16px, py=10px
    bg=hsl(--background)
    focus: outline-none, ring=2px hsl(--ring/40%)
    placeholder="Search templates…"

Filter buttons (flex-row, gap=8px):
  ['all'→'All', 'label'→'Labels', 'document'→'Documents']
  Each: px=16px, py=8px, border-radius=12px, text=14px, font-weight=500
  Active:   bg=hsl(--primary), color=hsl(--primary-foreground)
  Inactive: border=1px hsl(--border), color=hsl(--muted-foreground)
             hover: bg=hsl(--secondary), color=hsl(--foreground)
```

### Template Grid
```
display: grid
columns: 2 (default) / 3 (≥640px) / 4 (≥1024px)
gap: 20px

Loading (8 skeleton cards):
  aspect-ratio=4/3, bg=hsl(--secondary), border-radius=16px
  animate: pulse (opacity 1→0.5→1, ~1.5s)

Empty (search/filter no results):
  text-center, py=80px
  "No templates match your search." — text=14px, muted

Empty (no templates at all):
  flex-col, items-center, justify-center, py=96px, text-center
  Icon box: 80×80px, bg=hsl(--secondary), border-radius=16px, shadow-sm, mb=24px
    Sparkles icon 32px, color=hsl(--accent)
  "Create your first template" — font-heading, 24px, semibold, mb=12px
  Description: text=14px, muted, max-width=384px, line-height=1.6, mb=32px
  CTA button: "New Template" — px=24px, py=12px, bg=accent, border-radius=12px
              font-semibold, text=14px, shadow-md, Plus icon 16px

"New Template" add card (at grid end):
  aspect-ratio=4/3, border-radius=16px
  border=2px dashed hsl(--border)
  flex-col, items-center, justify-center, gap=12px
  hover: border-color=accent, bg=accent/5%
  
  Circle container: 40×40px, bg=hsl(--secondary), border-radius=full
    hover: bg=hsl(--accent/15%)
    Plus icon 20px, color=muted-foreground → accent on hover
  
  Label: "New Template", text=14px, color=muted → accent on hover, font-weight=500
```

### Template Card
```
Container:
  bg=hsl(--card), border-radius=16px, border=1px hsl(--border)
  overflow=hidden, cursor=pointer
  hover: box-shadow=lg, translateY(-2px)
  transition: all 200ms

Preview area (aspect-ratio=4/3):
  bg=hsl(--workspace-bg)
  padding=16px, overflow=hidden, position=relative
  
  If thumbnail_url:
    <img> width/height=100%, object-fit=contain, border-radius=8px, shadow-md
  
  Else (placeholder):
    white box: border-radius=8px, shadow-md, width/height=100%
    flex-col, items-center, justify-center, gap=8px
    Icon 28px: Tag (label) or FileText (document), color=muted-foreground/40%
    Size label: text=10px, color=muted-foreground/50%, font-medium
  
  Type badge (absolute, top=12px, left=12px):
    px=8px, py=2px, border-radius=full
    text=9px, font-weight=600, uppercase, letter-spacing=0.05em
    label:    bg=hsl(--accent/15%), color=hsl(--accent)
    document: bg=hsl(--primary/10%), color=hsl(--primary)
    text: "Label" or "Document"

Footer (px=16px, py=12px):
  flex-row, justify-between, gap=8px
  
  Left (flex=1, min-width=0):
    Name: text=14px, font-weight=600, color=hsl(--foreground), truncate
    
    Rename mode (inline):
      input: width=100%, text=14px, font-weight=600
      border-bottom=1px hsl(--accent), bg=transparent, no outline
      blur/Enter → commit, Escape → cancel
    
    Meta row (flex-row, gap=4px, mt=4px):
      Clock icon 9px
      time-ago string
      if connected_entity:
        "·" separator
        entity name: color=hsl(--accent), font-weight=500
      text=10px, color=muted-foreground
  
  Right (context menu):
    Trigger: MoreHorizontal icon 14px, p=6px, border-radius=8px
             opacity=0, group-hover: opacity=100
             hover: bg=hsl(--secondary)
    
    Dropdown (absolute, right-0, top-full, mt=4px):
      bg=hsl(--popover), border=1px hsl(--border), border-radius=12px
      shadow-xl, z-index=10, width=160px, overflow=hidden, py=4px
      
      "Duplicate" — Copy icon 12px, px=12px, py=8px, text=12px, hover: bg=secondary
      "Rename"    — Pencil icon 12px, same
      [separator: 1px bg=hsl(--border), my=4px]
      "Delete"    — Trash2 icon 12px, color=destructive, hover: bg=destructive/10%

Batch Print button (if connected_entity):
  absolute, bottom=8px, left=8px
  opacity=0 → 100 on card hover, transition
  px=10px, py=6px, bg=hsl(--accent), color=hsl(--accent-foreground)
  border-radius=8px, text=12px, font-semibold, shadow-md
  Printer icon 11px
  hover: bg=accent/90%
  onClick: opens BatchPrintModal
```

---

## 3. Editor Screen — Layout Overview

```
height: 100vh, overflow: hidden, flex-col, bg=hsl(--background)

┌────────────────────────────────────────────────────────────────────┐
│  TOOLBAR  h=44px, border-bottom=1px rgba(0,0,0,0.06)              │
├──────────┬─────────────────────────────────────────┬──────────────┤
│  LEFT    │                                         │  RIGHT       │
│ SIDEBAR  │       CANVAS WORKSPACE                  │  SIDEBAR     │
│  224px   │       (flex=1)                          │  240px       │
│ (or 20px)│                                         │ (or 20px)    │
└──────────┴─────────────────────────────────────────┴──────────────┘

Sidebar open/close transitions: width 200ms ease
```

---

## 4. Editor — Toolbar

```
height: 44px
bg: hsl(--background/98%)
backdrop-filter: blur(16px)
border-bottom: 1px solid rgba(0,0,0,0.06)
padding: 0 12px
flex-row, items-center, gap=8px
user-select: none, shrink=0

--- LEFT ---

Back button (flex-row, gap=4px):
  ChevronLeft icon 14px, strokeWidth=2
  Template name text (hidden on mobile, font-medium)
  text=12px, color=muted-foreground
  px=6px, py=4px, border-radius=8px
  hover: text-foreground, bg=secondary

[flex=1 spacer]

--- CENTER ---

Insert tools pill:
  bg=hsl(--secondary/70%), border-radius=12px, px=8px, py=4px
  flex-row, gap=2px

  Each ToolButton: 32×32px, border-radius=8px
    Icon: 14px, strokeWidth=1.8
    default: color=hsl(--foreground/60%)
    hover:   color=hsl(--foreground), bg=rgba(0,0,0,0.08)

  Buttons (left to right):
    Type icon       → "Text"
    Square icon     → "Rectangle"
    Circle icon     → "Circle"
    Minus icon      → "Line"
    Image icon      → "Image"
    QrCode icon     → "QR Code"
    BarChart2 icon  → "Barcode"
    [DIVIDER: 1px wide, h=16px, bg=rgba(0,0,0,0.10), mx=4px]
    Rows2 icon      → "Row"
    Columns icon    → "Column"

[flex=1 spacer]

--- RIGHT ---

Undo2 icon button  (disabled=!canUndo, opacity=0.2 when disabled)
Redo2 icon button  (disabled=!canRedo)
[DIVIDER]
ZoomOut icon button
"{zoom}%" text: 11px, tabular-nums, w=32px, text-center, color=muted-foreground
ZoomIn icon button
[DIVIDER]
Eye icon button     → "Preview"
Download icon button → "Export PDF"
Save button:
  ml=4px, text=12px, px=12px, py=6px, border-radius=8px
  bg=hsl(--foreground), color=hsl(--background)
  hover: bg=hsl(--foreground/85%)
  disabled (saving): opacity=0.4
  text: "Save" | "Saving…"
```

---

## 5. Editor — Left Sidebar (Data Panel)

### Shell
```
Transitions: width 200ms ease
Open:  width=224px, flex-col, border-right=1px hsl(--border), bg=hsl(--background)
Closed: width=20px, shows vertical tab strip

Closed tab strip:
  20px wide, full height, border-right=1px hsl(--border)
  flex, items-center, justify-center
  hover: bg=hsl(--secondary)
  
  "DATA" label:
    font=9px, font-weight=600, letter-spacing=0.08em
    color=muted-foreground → foreground on hover
    writing-mode: vertical-rl, transform: rotate(180deg)

Open — Header:
  px=12px, py=8px, border-bottom=1px hsl(--border), shrink=0
  flex-row, justify-between
  
  "Data / Variables" — text=11px, font-semibold, color=foreground
  
  ✕ button: 20×20px, border-radius=4px, hover: bg=secondary
    text=12px, color=muted-foreground → foreground
```

### Entity Selector
```
px=12px, py=12px, border-bottom=1px hsl(--border)

"DATA SOURCE" label: text=10px, font-semibold, uppercase, tracking-widest, muted, mb=8px

flex-row, gap=6px:
  Input: flex=1, text=11px, border=1px hsl(--border), border-radius=6px
         px=8px, py=6px, bg=hsl(--background)
         focus: ring=1px hsl(--ring)
         placeholder="Entity name (e.g. Order)"
         onKeyDown Enter → connect

  "Connect" button:
    px=12px, py=6px, text=11px, font-semibold
    bg=hsl(--accent), color=hsl(--accent-foreground)
    border-radius=6px, hover: bg=accent/90%

If connected:
  mt=6px, flex-row, items-center, gap=6px
  CheckCircle2 icon 10px, color=accent
  "Connected to {entityName}" — text=10px, font-medium, color=accent
  entity name in bold
```

### Tabs
```
flex-row, border-bottom=1px hsl(--border)
Each: flex=1, py=8px, text=11px, font-medium, transition

Active tab:   border-bottom=2px hsl(--accent), color=hsl(--accent)
Inactive tab: border-bottom=2px transparent, color=muted-foreground, hover: foreground

"Computed" tab: Calculator icon 9px inline before label text
```

### Fields Tab
```
Search input section (px=12px, py=8px):
  position=relative
  Search icon 10px: absolute left=8px, vertically centered, color=muted-foreground
  input: w=full, text=11px, border, border-radius=6px, pl=24px, pr=8px, py=6px
         focus: ring=1px hsl(--ring)
         placeholder="Search fields…"

Loading state: centered 16×16px spinner, py=24px

Field list (max-height=192px, overflow-y=auto, px=8px, pb=8px, gap=2px):
  Each field button (w=full, text-left, px=10px, py=6px, border-radius=6px):
    If text element selected (canInsert=true):
      hover: bg=accent/10%, color=accent, cursor=pointer
      flex-row, justify-between
      Field name: text=11px, font-mono, color=foreground
      ChevronRight icon 9px: opacity=0 → 100 on hover, color=accent
    Else: opacity=40%, cursor=not-allowed

  Empty: "No fields found" — text=10px, muted, centered, pt=16px

No-insert note (below list, if !canInsert, border-top):
  "Select a Text element to insert" — text=10px, muted, centered, py=8px
```

### Computed Tab
```
Computed fields list (max-height=160px, overflow-y=auto, px=8px, pt=8px, gap=4px):
  Each field (group, flex-row, px=8px, py=6px, border-radius=6px, hover: bg=secondary):
    Left button (if canInsert: cursor=pointer, else: cursor=not-allowed, opacity=50%):
      Name: text=11px, font-semibold, color=foreground
      Formula: text=9px, font-mono, color=muted-foreground, truncate
    Right: Trash2 icon 9px, 20×20px
      opacity=0 → group-hover: 100
      hover: bg=destructive/10%, color=destructive

  Empty: "No computed fields yet" — text=10px, muted, centered, py=12px

Add new field section (border-top, px=12px, py=12px, gap=8px vertical):
  "NEW COMPUTED FIELD" label — text=10px, uppercase, tracking-widest, muted, font-semibold
  Name input: placeholder='Name, e.g. "Total"', text=11px, border, border-radius=6px
  Formula input: same styling + font-mono
                 placeholder='e.g. {{order.quantity}} * {{order.price}}'
  Error text: text=10px, color=destructive (shown on validation failure)
  Help text: text=9px, muted — "Use field tokens + operators: + − * / and ( )"
  "Add field" button: w=full, py=6px, bg=accent, color=accent-foreground
                      border-radius=6px, text=11px, font-semibold
                      flex-row, justify-center, gap=6px, Plus icon 11px
```

---

## 6. Editor — Canvas Workspace

### Container
```
flex=1, overflow=hidden, position=relative
background: hsl(--workspace-bg) + dot grid (24px spacing, rgba(0,0,0,0.14))
cursor: grab (panMode) | default

Mouse events:
  mousedown → pan if panMode or spaceHeld or middle-click
  click on background → deselect
  wheel + ctrl/meta → zoom
```

### Canvas Positioning & Scale
```
Scroll container (absolute inset=0, flex, items-start, justify-center):
  padding-top=48px, padding-bottom=48px
  transform: translate({panOffset.x}px, {panOffset.y}px)

Outer size wrapper:
  width = canvasPx * scale
  height = canvasPx * scale
  position=relative, flex-shrink=0

Canvas div (#print-canvas):
  width = canvasPx (ACTUAL, not scaled)
  height = canvasPx (ACTUAL, not scaled)
  background = template.background_color || 'white'
  box-shadow: 0 2px 24px rgba(0,0,0,0.10), 0 8px 40px rgba(0,0,0,0.06)
  position=relative
  transform-origin: top left
  transform: scale({zoom/100})
  border-radius=2px
  overflow=hidden

Canvas label (below the document):
  position=absolute, top = canvasPx*scale + 8px
  left=0, right=0, text-align=center
  font=11px Inter, color=rgba(0,0,0,0.35)
  user-select=none, pointer-events=none
  "{SIZE_KEY} · {width}×{height} mm"
```

### Canvas Contents (render order)
```
1. Grid overlay (if gridEnabled):
   absolute inset=0, z-index=0, pointer-events=none
   dot grid 10px spacing, rgba(0,0,0,0.12)

2. Section containers (if any isSection elements):
   absolute top=0, left=0, right=0, z-index=50
   flex-col (SectionContainer for each)

3. Free absolute elements (sorted by zIndex):
   row/col → FlexContainer (AbsoluteContainer)
   others  → CanvasElement

4. SnapGuides (absolute lines, on top)
```

---

## 7. Editor — CanvasElement (Absolute)

### Container
```
position: absolute
left: el.x, top: el.y, width: el.width, height: el.height
opacity: el.opacity
transform: rotate({el.rotation}deg) [if rotation ≠ 0]
cursor: 'text' (text editing) | 'move'
box-sizing: border-box
z-index: (el.zIndex || 1) + (selected ? 100 : 0)
box-shadow: el.boxShadow (if set)

CSS class "canvas-element" (always) + "selected" (when selected)

Hover outline (via CSS, not selected):
  outline: 1px dashed hsl(--foreground / 20%)
  outline-offset: 1px

Selected outline (via CSS):
  outline: 1.5px solid hsl(--foreground / 70%)
  outline-offset: 1px
```

### Text Rendering (not editing)
```
Inner div (width/height 100%):
  font-family, font-size, font-weight, font-style, text-align
  line-height, white-space=pre-wrap, overflow=hidden
  user-select=none

Normal text: color = el.color
Token chips: content rendered via innerHTML (token → styled span)
Gradient text (if textGradient):
  color: transparent
  background-image: {gradientToCss(el.textGradient)}
  background-clip: text
  -webkit-background-clip: text
  -webkit-text-fill-color: transparent
```

### Text Editing Mode (doubleClick)
```
<textarea>
  autoFocus, position fills container
  Same font styles as display mode
  border: none, outline: none, resize: none
  background: transparent, padding: 0
  color: el.color (no gradient in edit mode)
onBlur: commit new content, exit editing
```

### Shape Rendering
```
Inner div (100% width/height):
  background: gradient CSS | el.fill
  border: {el.strokeWidth}px solid {el.stroke}
  border-radius: '50%' (circle) | '{el.borderRadius}px'
```

### Image Rendering
```
If src: <img> width/height=100%, object-fit=el.objectFit, border-radius=el.borderRadius
If no src: placeholder div
  bg=#F0EFed, border=1.5px dashed #C4A882
  flex center, "Image" text, color=#9E9890, font=12px Inter
```

### QR Rendering
```
<img> using api.qrserver.com
src = "https://api.qrserver.com/v1/create-qr-code/?data={encoded}&size={size}x{size}&margin=0"
size = Math.min(el.width, el.height)
width/height=100%, image-rendering=pixelated
```

### Barcode Rendering
```
<BarcodeRenderer el={el} width={el.width} height={el.height} />
Uses HTML5 Canvas internally (see Part 3 §5 for algorithm)
```

### Resize Handles (8 handles, shown when selected and not editing)
```
Each handle: 7×7px, bg=white, border=1.5px solid hsl(--foreground/60%)
             border-radius=50%, position=absolute, z-index=10
             box-shadow=0 1px 3px rgba(0,0,0,0.15)

Positions (handle-specific cursors):
  nw: top=-4, left=-4,     cursor=nw-resize
  n:  top=-4, left=50%,    cursor=n-resize,  marginLeft=-4
  ne: top=-4, right=-4,    cursor=ne-resize
  e:  top=50%, right=-4,   cursor=e-resize,  marginTop=-4
  se: bottom=-4, right=-4, cursor=se-resize
  s:  bottom=-4, left=50%, cursor=s-resize,  marginLeft=-4
  sw: bottom=-4, left=-4,  cursor=sw-resize
  w:  top=50%, left=-4,    cursor=w-resize,  marginTop=-4
```

---

## 8. Editor — FlexContainer & FlexChild

### SectionContainer (isSection=true)
```
width: 100%
min-height: el.minHeight || el.height || 60
opacity: el.opacity

display: flex
flex-direction: row (type='row') | column (type='col')
flex-wrap: nowrap
gap: el.gap ?? 8
padding: el.padding ?? 8
align-items: el.alignItems || (isRow ? 'center' : 'flex-start')
justify-content: flex-start

background: gradientToCss(el.gradient) | el.background | 'transparent'
border-radius: el.borderRadius || 0
position: relative
cursor: pointer
box-sizing: border-box

Selection outline:
  selected:     outline=1.5px solid hsl(--foreground/70%), offset=1
  not selected: outline=1px dashed rgba(0,0,0,0.1), offset=-1

Row/Col badge (absolute, top=2px, right=4px):
  9px Inter, rgba(0,0,0,0.25), pointer-events=none, user-select=none
  bg=rgba(255,255,255,0.7), border-radius=3px, padding=1px 4px, line-height=1.4
  text: "ROW" or "COL"

Empty state (no children):
  flex=1, align-self=stretch
  border=1.5px dashed rgba(0,0,0,0.12), border-radius=4px
  flex center, 10px Inter rgba(0,0,0,0.2)
  min-height=32px, min-width=60px
  text: "+ add children via tree"
```

### AbsoluteContainer (isSection=false)
```
position: absolute
left: el.x, top: el.y, width: el.width, height: el.height
opacity: el.opacity
transform: rotate if rotation
z-index: el.zIndex || 1
display: flex, flex-direction (row/col), flex-wrap: nowrap
gap, padding, align-items, justify-content: flex-start
background (gradient or flat)
border-radius, box-shadow
overflow: VISIBLE  ← children can exceed bounds and grow container
cursor: default (locked) | move (unlocked)

CSS classes: canvas-element + selected

Empty state:
  border=1.5px dashed rgba(0,0,0,0.15), border-radius=4px
  flex=1, align-self=stretch, min-height=24px, min-width=40px
  10px Inter rgba(0,0,0,0.25)
  text: "row" or "col"
```

### FlexChild Base Styles
```
box-sizing: border-box
flex: child.flex ?? 0
flex-shrink: 0 (leaf) | 1 (container)
align-self: child.alignSelf || 'auto'
opacity: child.opacity ?? 1
min-width: 0
cursor: pointer

Selected: outline=1.5px solid hsl(--foreground/70%), outline-offset=1
```

### FlexChild — Container (nested row/col)
```
display: flex, flex-direction (row/col), flex-wrap: nowrap
gap, padding, align-items, justify-content: flex-start
background (gradient or flat), border-radius
width: fixed | undefined (auto)
height: fixed | undefined (auto)
min-height: 20px
flex-shrink: 1
NO overflow:hidden — content must grow container

Empty: 1px dashed rgba(0,0,0,0.12), border-radius=3px, min-height=16px
```

### FlexChild — Text
```
font-family, font-size, font-weight, font-style, text-align
color (or transparent for gradient)
line-height
white-space: pre-wrap
overflow-wrap: break-word
width: fixed | undefined(auto)
height: fixed | undefined(auto)

Gradient: same technique as absolute text
```

### FlexChild — Shape
```
width: child.width || 60
height: child.height || 40
background: gradient | fill
border: strokeWidth solid stroke
border-radius: 50% (circle) | borderRadius px
boxShadow if set
```

### FlexChild — Image
```
width: fixed or fallback 60
height: fixed or fallback 40
object-fit, display: block
Empty: same placeholder as absolute image
crossOrigin="anonymous" for PDF export
```

### FlexChild — QR / Barcode
```
Wrapper div: flex child dimensions
Inside: same QRCodeBox / BarcodeRenderer as absolute
```

---

## 9. Editor — Right Sidebar (Properties Panel)

### Shell
```
Transitions: width 200ms ease
Open:  width=240px, flex-col, border-left=1px hsl(--border), bg=hsl(--background)
Closed: width=20px, vertical "PROPS" tab (writing-mode=vertical-rl, no rotation)
  Hover: bg=hsl(--secondary)

Open — Header (px=12px, py=8px, border-bottom, shrink=0):
  Left: element type capitalized (or "Properties") — text=11px, font-semibold
  Right: ✕ button 20×20px, rounded, hover: bg=secondary

Content areas (from top to bottom in open state):
  1. Properties Panel — flex=1, overflow-y=auto, min-height=0
  2. Layers Tree — border-top, max-height=176px, overflow-y=auto, shrink=0
  3. Page Settings — border-top, shrink=0
```

### Properties Panel — Empty State
```
h=full, flex, items-center, justify-center, px=24px

32×32px circle: bg=hsl(--secondary), border-radius=full, mx-auto, mb=12px
  "↖" arrow text, text-base, color=muted-foreground

"Select an element\nto inspect"
  text=12px, muted-foreground, line-height=relaxed, text-center
```

### Properties Section Component
```
Collapsible section container:
  border-bottom (last section: none)
  
  Toggle header (button):
    width=100%, flex-row, justify-between, items-center
    px=16px, py=10px
    hover: bg=hsl(--secondary/40%), transition
    
    Left: section title — text=10px, font-semibold, uppercase, tracking-wider, muted-foreground
    Right: "›" character, text=12px, muted — rotated 180° when open
  
  Content (when open): px=16px, pb=12px, gap=8px vertical
```

### Lock Toggle (row/col top-level only)
```
Positioned above all sections, px=16px, py=8px, border-bottom=1px hsl(--border)
flex-row, items-center, justify-between

"Lock position" — text=11px, color=muted-foreground

Lock/Unlock button:
  flex-row, gap=6px, px=10px, py=4px, border-radius=6px, border=1px, text=11px
  
  Locked state:
    bg=#FFFBEB (amber-50), border=#FCA5A5→#D97706 (amber-300)
    color=#B45309 (amber-700)
    Lock icon 11px + "Locked"
  
  Unlocked state:
    border=hsl(--border), color=muted-foreground
    hover: border=hsl(--foreground)
    Unlock icon 11px + "Unlocked"
```

### Section: Position & Size
```
4-input grid (2×2), labels X/Y/W/H
NumInput for each (W/H: min=10)

Row 2: Rotation (-180 to 180) + Opacity % (0-100, stored as 0.0-1.0 internally)
Same 2-col grid
```

### Section: Size & Flex (flex children)
```
Width + Height: text inputs ('auto' allowed, or number)
Flex grow (NumInput, 0–10, step=1) + Align self (Select)

Align self options: auto/flex-start (Start)/center/flex-end (End)/stretch
```

### Section: Text
```
Font: full-width <select>, each option styled with its own font
  options: all FONT_FAMILIES list

Size (NumInput 6–200) + Leading (NumInput 0.8–4, step=0.1)
Weight (Select) + Style (Select: normal/italic)
Align: 4 buttons [L C R J], each flex=1, py=4px, rounded, border
  Active: bg=hsl(--foreground), color=hsl(--background), border=foreground
  Inactive: border=hsl(--border), hover: border=muted-foreground, color=muted-foreground
Color: ColorInput
Text Gradient: GradientEditor

Weight options: 300(Light), normal(Regular), 500(Medium), 600(Semibold), bold(Bold), 800(ExtraBold)
```

### Section: Shape
```
Fill: ColorInput
Gradient: GradientEditor
Stroke: ColorInput
Stroke Width (NumInput 0–20) + Radius (NumInput 0–200)  [2-col grid]
```

### Section: Image
```
URL: full-width text input, placeholder="https://…"
Fit: Select (cover/contain/fill/none)
Radius: NumInput (0–200)
```

### Section: QR Code
```
Content/URL: full-width text input, placeholder="https://…"
```

### Section: Barcode
```
Value/Field: text input, placeholder="1234567890 or {{field}}"
Format: Select (BARCODE_FORMATS: CODE128/CODE39/EAN13/EAN8/UPC/ITF14/MSI/pharmacode)
Color: ColorInput
BG: ColorInput
Show text: toggle button
  On: bg=hsl(--foreground), color=hsl(--background), border=foreground
  Off: border=hsl(--border), color=muted-foreground
```

### Section: Layout (containers)
```
Gap (0–100) + Padding (0–80)  [2-col]
Align: Select (flex-start→Start, center, flex-end→End, stretch)
BG: ColorInput
Gradient: GradientEditor
Radius: NumInput (0–200)
```

### Section: Elevation (absolute only, defaultOpen=false)
```
5-button grid: None / Sm / Md / Lg / XL
  Active: bg=accent, color=accent-foreground, border=accent
  Inactive: border=hsl(--border), color=muted-foreground, hover: border=foreground

Custom shadow CSS input (full-width)
  placeholder="0 4px 12px rgba(0,0,0,0.1)"
```

### Section: Layer (absolute only, defaultOpen=false)
```
2 buttons: "Forward" (ChevronUp 11px) + "Back" (ChevronDown 11px)
  flex=1, flex-row justify-center, gap=4px, text=11px
  border=1px hsl(--border), border-radius=6px, py=6px
  hover: bg=secondary, text=muted-foreground → foreground

Delete button (full-width):
  flex-row, justify-center, gap=6px, text=11px
  color=destructive, border=1px destructive/20%
  border-radius=6px, py=6px
  hover: bg=destructive/5%
  Trash2 icon 11px + "Delete element"
```

### Delete button (flex children — below all sections)
```
px=16px, py=12px
Same red delete button as above but text "Delete element"
```

### ColorInput Component
```
flex-row, gap=6px

Swatch: 28×28px, border-radius=6px, border=1px hsl(--border), cursor=pointer
  Position=relative
  <input type="color"> absolute, inset=0, opacity=0 (click triggers swatch)
  Color div: 100% fill, background=current value

Text input: font-mono, uppercase, same as standard input
```

### NumInput Component
```
<input type="number">
value displayed as Math.round(value * 10) / 10 (1 decimal max)
text=11px, border=1px hsl(--border), border-radius=6px, px=8px, py=6px, bg=hsl(--background)
focus: ring=1px hsl(--ring)
```

### GradientEditor Component
```
Header row:
  "Gradient" label — text=11px, muted
  On/Off toggle button:
    On:  bg=accent, color=accent-foreground, border=accent, px=8px, py=2px, text=10px, rounded
    Off: border=hsl(--border), color=muted-foreground, hover: border=foreground

When enabled:
  Preview strip: h=20px, border-radius=6px, border=1px hsl(--border), bg=gradientCSS

  Type buttons [Linear][Radial] — flex-row, gap=6px:
    Active: bg=accent, text=accent-foreground, border=accent
    Inactive: border=hsl(--border), color=muted-foreground, py=4px, text=10px, flex=1, rounded

  Angle (linear only): NumInput 0–360 labeled "Angle"

  Color stops section:
    "Color stops" — text=10px, muted, mb=4px
    
    Each stop row (flex-row, items-center, gap=6px):
      Color swatch: 24×24px (smaller version of ColorInput)
      Position input: NumInput 0–100, width=56px
      "%" label — text=10px, muted
      Trash2 9px button: hover destructive, ml=auto
    
    "+ Add stop" — text=10px, color=accent, hover: underline (button styled as link)

Default when toggled on:
  {type:'linear', angle:90, stops:[{color:'#6366f1',pos:0}, {color:'#ec4899',pos:100}]}
```

---

## 10. Editor — Layers Tree (WidgetTree)

### Shell
```
border-top=1px hsl(--border), max-height=176px, overflow-y=auto, shrink=0

Section header: px=12px, py=6px, border-bottom=1px hsl(--border)
  "LAYERS" — text=10px, font-semibold, muted, uppercase, tracking-wider

List: py=4px, px=4px
  Elements displayed sorted by zIndex DESCENDING (highest zIndex = top of list)
```

### TreeNode
```
Row (group):
  flex-row, items-center, gap=4px, py=4px, border-radius=6px, cursor=pointer
  padding-left = 8px + (depth * 14px)
  
  Selected: bg=hsl(--secondary), color=hsl(--foreground)
  Hover:    bg=hsl(--secondary/60%), color=hsl(--foreground)
  Default:  color=hsl(--muted-foreground)

Left:
  Container with children: chevron toggle button (10px)
    ChevronDown (expanded) | ChevronRight (collapsed)
    click: toggle collapse without changing selection
  Container empty / leaf: 10px spacer

Type icon: TYPE_ICONS[el.type] 11px, shrink=0

Name (flex=1, text=11px, truncate):
  text: first 18 chars of content (text) | shape type | "Row" | "Col" | "Image" | "QR Code" | type

Lock icon: Lock 9px, color=amber-500, mr=2px (only if el.locked)

Action buttons (opacity=0, group-hover|selected: opacity=100):
  Add child (+ icon 9px, 20×20px):
    Only for containers
    border-radius=4px, hover: bg=accent/10%, color=accent
    Shows AddChildMenu on click

  Delete (Trash2 9px, 20×20px):
    border-radius=4px, hover: bg=destructive/10%, color=destructive
```

### AddChildMenu Dropdown
```
Absolute, right-0, top-full, mt=2px, z-index=50
bg=hsl(--background), border=1px hsl(--border), border-radius=8px
shadow-lg, py=4px, min-width=100px

Options (text=11px, px=12px, py=6px, hover: bg=secondary):
  Text / Rectangle / Circle / Image / QR Code / Barcode / Row / Col
```

---

## 11. Editor — Page Settings Panel

```
Collapsible, at bottom of right sidebar

Toggle button (full-width):
  flex-row, justify-between, items-center, px=12px, py=8px
  hover: bg=hsl(--secondary/50%), text=foreground
  
  Left: "Page · {SIZE_KEY}" — text=11px, font-semibold
  Right: "{width}×{height}" — text=10px, muted

Content (when open, border-top, px=12px, py=12px, gap=12px vertical):
```

### Printer Preset Select
```
"PRINTER / FORMAT" label — text=10px, uppercase, tracking-widest, muted, mb=6px
<select> (full-width, same input style):
  Generic / PDF
  Letter (8.5×11")
  A4 (210×297 mm)
  A5 (148×210 mm)
  Legal (8.5×14")
  Tabloid (11×17")
  4×6 Label
  2×2 Sticker
  Custom

onChange: update W/H inputs (respecting current orientation)
```

### Orientation Buttons
```
"ORIENTATION" label
flex-row, gap=6px:
  "portrait" button + "landscape" button
  Active: bg=accent, color=accent-foreground, border=accent
  Inactive: border=hsl(--border), muted, hover: border=muted-foreground
  text=11px, py=6px, flex=1, border-radius=6px, capitalize
```

### Dimension Inputs
```
"SIZE (MM)" label
flex-row, gap=6px, items-center:
  Width column (flex=1): "Width" label (text=9px), NumInput (min=10, max=1000)
  "×" separator (muted, mt=16px)
  Height column (flex=1): "Height" label, NumInput

"Current: {W}×{H} mm" — text=9px, muted, mt=4px
```

### Background Color
```
"BACKGROUND" label
ColorInput component (same as PropertiesPanel)
Note: "Applies to the entire document surface." — text=9px, muted, mt=4px
onChange: immediate update (no Apply needed)
```

### Apply Button
```
Shown ONLY when pendingW !== currentW || pendingH !== currentH
width=100%, py=8px, bg=accent, color=accent-foreground
border-radius=6px, text=11px, font-semibold
disabled during apply: opacity=50%
text: "Apply & rescale elements" | "Applying…"
```

---

## 12. Editor — ViewportNav (Floating Bottom Bar)

```
position: absolute, bottom=20px, left=50%, translateX(-50%)
z-index: 50
flex-row, items-center, gap=2px, px=8px, py=6px
border-radius=16px, shadow-lg
border=1px rgba(0,0,0,0.08)
background: rgba(255,255,255,0.97)
backdrop-filter: blur(12px)
user-select: none

NavButton: 32×32px, border-radius=8px, icon 14px, strokeWidth=1.8
  Active:   bg=hsl(--accent), color=hsl(--accent-foreground), shadow-sm
  Inactive: color=hsl(--foreground/55%), hover: foreground, hover: bg=rgba(0,0,0,0.08)
  Disabled: opacity=30%, cursor=not-allowed

Divider: 1px wide, h=16px, bg=rgba(0,0,0,0.10), mx=2px

Buttons (left to right):
  [Pan/Select] — Hand icon (pan off) | MousePointer2 (pan on) — active when panMode=true
  [DIVIDER]
  [Zoom Out]   — ZoomOut icon
  "{zoom}%"   — text=11px, tabular-nums, color=foreground/60%, w=36px, text-center, font-medium
  [Zoom In]    — ZoomIn icon
  [Fit View]   — Maximize2 icon
  [DIVIDER]
  [Grid]       — Grid3x3 icon — active when gridEnabled=true
  [Snap]       — Magnet icon — active when snapEnabled=true
  [DIVIDER]
  [Print]      — Printer icon (triggers window.print())
```

---

## 13. Preview Modal

### Shell
```
Fixed overlay: inset=0, z-index=50, flex, items-center, justify-center
Backdrop: bg=rgba(0,0,0,0.50), backdrop-filter=blur(4px)
Click backdrop: close modal

Modal:
  bg=hsl(--background), border-radius=16px, shadow-2xl
  flex-col, overflow=hidden
  max-width=768px, width=100%, mx=16px
  max-height=90vh
  stopPropagation on modal click
```

### Header
```
px=24px, py=16px, border-bottom=1px hsl(--border)
flex-row, items-center, justify-between

Left:
  Eye icon 16px, color=accent
  "Preview" — font-heading, text-lg

Right (flex-row, gap=12px, items-center):
  Record navigator (if entity + records):
    flex-row, gap=8px, items-center, text=12px, muted
    ChevronLeft button 14px (disabled if idx=0, opacity=30%)
    "{idx+1} / {total}"
    ChevronRight button 14px (disabled if last)

  Export PDF button:
    flex-row, gap=6px, px=16px, py=6px
    bg=hsl(--primary), color=hsl(--primary-foreground)
    text=12px, border-radius=8px, font-medium
    Download icon 12px
    disabled during export: opacity=60%
    text: "Export PDF" | "Exporting…"

  Close: p=6px, border-radius=8px, hover: bg=secondary, X icon 16px
```

### Record Picker Bar
```
Shown if connected entity + records exist
px=24px, py=8px, border-bottom=1px hsl(--border), bg=hsl(--secondary/30%)

flex-row, items-center, gap=8px:
  "RECORD:" — text=10px, muted, uppercase, tracking-widest, font-semibold
  <select>: text=12px, border=1px hsl(--border), border-radius=6px, px=8px, py=4px, bg=background
    Options: name || title || full_name || id.slice(0,8) || "Record {i+1}"
  Loading spinner (if loading records)
```

### Preview Canvas Area
```
flex=1, overflow=auto
flex, items-center, justify-center
padding=32px, bg=hsl(--workspace-bg)

Outer wrapper: width=canvasPx*scale, height=canvasPx*scale, flex-shrink=0

Scale wrapper: transform-origin=top-left, transform=scale({scale})
  scale = min(1, 560/canvasWidthPx, 600/canvasHeightPx)

Canvas div (ref=canvasRef, used for PDF export):
  width=canvasPx, height=canvasPx (ACTUAL, unscaled)
  background=template.background_color || 'white'
  position=relative, overflow=hidden
  box-shadow only if scale >= 1

Renders: PreviewCanvas component (all element types, tokens resolved)
```

---

## 14. Batch Print Modal

### Shell
```
Same overlay as Preview Modal
Modal: max-width=512px, max-height=80vh

Header:
  Printer icon 16px (accent) + "Batch Print — {templateName}" (font-heading, text-lg)
  Close X button
```

### States

**No entity:**
```
flex=1, flex-center, p=40px, text-center
"No data source connected." — text=14px, muted, mb=4px
"Open the template in the editor..." — text=12px, muted
```

**Loading:**
```
flex=1, flex-center, p=40px
Loader2 icon 20px, animate-spin, color=muted-foreground
```

**No records:**
```
flex=1, flex-center, p=40px
"No records found in {entity}." — text=14px, muted
entity name in bold
```

**Records list:**
```
Select-all bar (px=16px, py=8px, border-bottom, bg=secondary/30%):
  flex-row, justify-between

  Left button: flex-row, gap=8px, text=12px, muted, hover: foreground
    CheckSquare 14px (accent, all selected) | Square 14px (none/partial)
    "Deselect all" | "Select all ({n})"

  Right: "{n} selected" — text=12px, muted

Records list (flex=1, overflow-y=auto, divide-y):
  Each record row (button):
    width=100%, flex-row, gap=12px, px=16px, py=12px, text-left
    hover: bg=hsl(--secondary/50%)

    CheckSquare 15px (accent, if selected) | Square 15px (muted, if not)
    Record label — text=14px, truncate
    ID prefix — text=10px, muted, ml=auto, font-mono, shrink=0

Footer (px=24px, py=16px, border-top, flex-row, items-center, gap=12px):
  Progress/count:
    If printing: Loader2 12px animate-spin + "{i}/{total}…" — text=12px, muted
    Else: "{n} page(s) in PDF" — text=12px, muted

  Button group (ml=auto, flex-row, gap=8px):
    Cancel: px=16px, py=8px, text=14px, border=1px hsl(--border), border-radius=12px
            hover: bg=secondary
    Print PDF: px=16px, py=8px, text=14px, bg=accent, color=accent-foreground
              border-radius=12px, font-semibold
              disabled: 0 selected OR printing → opacity=40%
              text: "Generating…" | "Print {n} PDF"
              Printer icon 14px
```

---

## 15. New Template Modal

### Shell
```
Overlay: bg=rgba(0,0,0,0.40), backdrop-blur=4px, z-index=50
Modal: bg=background, border-radius=16px, shadow-2xl, max-width=512px, overflow=hidden
stopPropagation on modal click
```

### Header
```
px=32px, pt=32px, pb=24px, border-bottom=1px hsl(--border)
flex-row, justify-between, items-start

Left:
  "New Template" — font-heading, 24px, weight=600, color=foreground
  "Choose a type and size to get started." — text=14px, muted, mt=4px

Right:
  X button: p=8px, border-radius=8px, hover: bg=secondary
```

### Content
```
px=32px, py=24px, gap=24px vertical
```

### Template Name
```
Label: "TEMPLATE NAME" — text=12px, font-semibold, uppercase, tracking-widest, muted, mb=8px

Input:
  width=100%, text=14px, border=1px hsl(--border), border-radius=12px
  px=16px, py=12px, bg=background, autoFocus
  focus: ring=2px hsl(--ring/50%)
  placeholder="e.g. Shipping Label, Invoice…"
  onKeyDown Enter → create
```

### Document Type
```
Label: "DOCUMENT TYPE"

2-column grid, gap=12px:
  Each option button: p=16px, border-radius=12px, border-2px, text-left
    Active:   border=accent, bg=accent/5%
    Inactive: border=hsl(--border), hover: border=muted-foreground

  Icon 20px (mb=8px):
    Active:   color=accent
    Inactive: color=muted-foreground

  Title: text=14px, font-semibold
  Desc:  text=11px, muted, mt=2px

  label:    Tag icon, "Label / Sticker", "Free-position canvas for labels and stickers"
  document: FileText icon, "Formal Document", "Letter, invoice, certificate, or report"

onChange type: also update default canvas size
  label → sizeKey='4x6'
  document → sizeKey='A4'
```

### Canvas Size
```
Label: "CANVAS SIZE"

3-column grid, gap=8px:
  Sizes filtered by docType category (show matching + 'both')
  
  Each size button: py=8px, px=12px, border-radius=8px, border=1px, text=12px, text-center
    Active:   border=accent, bg=accent, color=accent-foreground
    Inactive: border=hsl(--border), hover: border=muted-foreground
    
    Size name: font-semibold
    Dimensions: text=9px, opacity=70%, mt=2px (hidden for 'custom')

If 'custom' selected:
  mt=12px, 2-column grid, gap=12px:
    Width (mm): label text=10px muted + number input
    Height (mm): same
  Input style: text=12px, border=1px hsl(--border), border-radius=8px, px=12px, py=8px
               focus: ring=1px hsl(--accent)
```

### Footer
```
px=32px, pb=32px, flex-row, gap=12px, justify-end

Cancel button: px=20px, py=10px, text=14px, border=1px hsl(--border), border-radius=12px
               hover: bg=secondary

Create Template button: px=24px, py=10px, text=14px, bg=accent, color=accent-foreground
                        border-radius=12px, font-semibold
                        disabled: !name.trim() → opacity=40%
``