# Papercraft — Specification Part 1: Design System, Data Model & Element Structures

> Part 1 of 3. See also SPEC_PART2_SCREENS.md and SPEC_PART3_BEHAVIORS.md

---

## Table of Contents (Part 1)

1. [Design System & Tokens](#1-design-system--tokens)
2. [Data Model](#2-data-model)
3. [Element Data Structures](#3-element-data-structures)
4. [Canvas Size Reference](#4-canvas-size-reference)
5. [Element Default Values](#5-element-default-values)

---

## 1. Design System & Tokens

### Color Tokens (Light Mode)
All colors are HSL. In CSS: `hsl(H S% L%)`.

| Token | HSL Value | Hex Approx |
|---|---|---|
| `--background` | 220 20% 98% | #F8F9FB |
| `--foreground` | 224 16% 12% | #1A1C23 |
| `--card` | 0 0% 100% | #FFFFFF |
| `--card-foreground` | 224 16% 12% | #1A1C23 |
| `--popover` | 0 0% 100% | #FFFFFF |
| `--primary` | 224 16% 12% | #1A1C23 |
| `--primary-foreground` | 0 0% 98% | #FAFAFA |
| `--secondary` | 220 14% 94% | #EEF0F4 |
| `--secondary-foreground` | 224 16% 18% | #262A34 |
| `--muted` | 220 13% 91% | #E5E8EE |
| `--muted-foreground` | 220 8% 46% | #6E7480 |
| `--accent` | 245 72% 58% | #6366F1 (indigo) |
| `--accent-foreground` | 0 0% 100% | #FFFFFF |
| `--destructive` | 0 84% 60% | #F04E4E |
| `--border` | 220 13% 87% | #DADDE5 |
| `--input` | 220 13% 87% | #DADDE5 |
| `--ring` | 245 72% 58% | #6366F1 |
| `--workspace-bg` | 220 16% 89% | #E0E3EB |
| `--panel-glass` | rgba(255,255,255,0.98) | — |

### Color Tokens (Dark Mode)

| Token | HSL Value |
|---|---|
| `--background` | 0 0% 6% |
| `--foreground` | 40 10% 94% |
| `--card` | 0 0% 8% |
| `--secondary` | 0 0% 12% |
| `--muted` | 0 0% 14% |
| `--muted-foreground` | 0 0% 55% |
| `--accent` | 18 64% 47% |
| `--border` | 0 0% 18% |
| `--workspace-bg` | 0 0% 10% |

### Typography

| Role | Font Family | Fallback |
|---|---|---|
| `--font-heading` | Playfair Display | Georgia, serif |
| `--font-body` | Inter | ui-sans-serif, system-ui, sans-serif |
| `--font-mono` | DM Mono | ui-monospace, monospace |

Google Fonts import:
```
Inter:wght@300;400;500;600;700
Playfair Display:ital,wght@0,400;0,500;0,600;0,700;1,400;1,500
Lora:ital,wght@0,400;0,500;0,600;1,400;1,500
DM Mono:wght@300;400;500
```

### Available Font Families (user-selectable in editor)
`Inter`, `Playfair Display`, `Lora`, `DM Mono`, `Georgia`, `Arial`, `Helvetica`, `Times New Roman`, `Courier New`

### Border Radius
- `--radius`: 0.5rem (8px)
- `md`: calc(radius - 2px) = 6px
- `sm`: calc(radius - 4px) = 4px

### Layout Constants
- Toolbar height: **44px**
- Left sidebar width (open): **224px** / (closed): **20px** — shows vertical "DATA" label
- Right sidebar width (open): **240px** / (closed): **20px** — shows vertical "PROPS" label
- Canvas padding top/bottom in workspace: **48px**
- Viewport nav pill bottom offset: **20px** from bottom, horizontally centered

### Workspace Dot Grid (background of workspace, not canvas)
```css
background-image: radial-gradient(circle, rgba(0,0,0,0.14) 1px, transparent 1px);
background-size: 24px 24px;
```

### Canvas Grid (overlay on canvas when enabled)
```css
background-image: radial-gradient(circle, rgba(0,0,0,0.12) 1px, transparent 1px);
background-size: 10px 10px;   /* GRID_SIZE = 10px */
```

### Shadow / Elevation Presets

| Label | CSS box-shadow |
|---|---|
| None | (no shadow) |
| Sm | `0 1px 3px rgba(0,0,0,0.12), 0 1px 2px rgba(0,0,0,0.08)` |
| Md | `0 4px 12px rgba(0,0,0,0.12), 0 2px 4px rgba(0,0,0,0.08)` |
| Lg | `0 8px 24px rgba(0,0,0,0.14), 0 4px 8px rgba(0,0,0,0.08)` |
| XL | `0 16px 48px rgba(0,0,0,0.18), 0 6px 12px rgba(0,0,0,0.10)` |

Canvas document shadow: `0 2px 24px rgba(0,0,0,0.10), 0 8px 40px rgba(0,0,0,0.06)`

---

## 2. Data Model

### Template Entity (database record)
```json
{
  "name":             "string (required)",
  "doc_type":         "enum: 'label' | 'document' (required)",
  "canvas_size":      "string — preset key e.g. 'A4', '4x6', 'custom'",
  "canvas_width_mm":  "number — canvas width in millimeters",
  "canvas_height_mm": "number — canvas height in millimeters",
  "background_color": "string — hex color e.g. '#ffffff'",
  "elements":         "string — JSON-serialized Element[]",
  "connected_entity": "string — name of linked data entity",
  "thumbnail_url":    "string — URL to preview image",
  "owner_id":         "string — user ID"
}
```

Built-in fields on every record (never declare): `id`, `created_date`, `updated_date`

**Unit conversion:** `1mm = 3.7795275591px` at 96 DPI
```
mmToPx(mm) = Math.round(mm * 3.7795275591)
```

---

## 3. Element Data Structures

All elements live in the `elements` array, serialized as JSON in `Template.elements`.

### 3.0 GradientDef Object
```typescript
{
  type:   'linear' | 'radial'
  angle:  number     // degrees, used only for linear, default 90
  stops:  Array<{
    color: string    // hex color
    pos:   number    // 0–100 (percent position)
  }>
}
```

Gradient → CSS:
```
Linear: linear-gradient({angle}deg, {stop.color} {stop.pos}%, ...)
Radial:  radial-gradient(circle, {stop.color} {stop.pos}%, ...)
Stops sorted by pos ascending before output.
```

---

### 3.1 Text Element (absolute)
```typescript
{
  id:           string     // "el_{timestamp}_{counter}"
  type:         'text'
  x:            number     // px from canvas left
  y:            number     // px from canvas top
  width:        number     // px
  height:       number     // px
  rotation:     number     // degrees, default 0
  content:      string     // may contain {{token}} syntax
  fontSize:     number     // px, default 16
  fontFamily:   string     // default 'Inter'
  fontWeight:   string     // '300'|'normal'|'500'|'600'|'bold'|'800', default 'normal'
  fontStyle:    string     // 'normal'|'italic', default 'normal'
  textAlign:    string     // 'left'|'center'|'right'|'justify', default 'left'
  color:        string     // hex, default '#1A1A1A'
  lineHeight:   number     // multiplier, default 1.4
  textGradient: GradientDef | null
  zIndex:       number     // default 1
  opacity:      number     // 0.0–1.0, default 1
  boxShadow?:   string     // CSS box-shadow
}
```

### 3.2 Shape Element (absolute)
```typescript
{
  id, type: 'shape'
  shape:        'rectangle' | 'circle' | 'line'
  x, y:         number
  width:        number     // default 120
  height:       number     // default 80 (line: height=2)
  rotation:     number
  fill:         string     // hex, default '#E8E6E1'
  stroke:       string     // hex, default '#1A1A1A'
  strokeWidth:  number     // px, default 1
  borderRadius: number     // px, default 4 (circle uses 50 → renders as 50%)
  gradient:     GradientDef | null
  zIndex, opacity, boxShadow?
}
```
Rendering rules:
- `circle` → `border-radius: 50%`
- `line` → fill='transparent', strokeWidth as border/background
- `rectangle` → `border-radius: {borderRadius}px`

### 3.3 Image Element (absolute)
```typescript
{
  id, type: 'image'
  x, y, width: 150, height: 100, rotation
  src:          string     // URL or empty string
  objectFit:    string     // 'cover'|'contain'|'fill'|'none', default 'cover'
  borderRadius: number     // px, default 0
  zIndex, opacity, boxShadow?
}
```
Empty state (src=''): `#F0EFed` background, `1.5px dashed #C4A882` border, "Image" label `#9E9890`.

### 3.4 QR Code Element (absolute)
```typescript
{
  id, type: 'qr'
  x, y, width: 80, height: 80, rotation
  content: string    // URL/text, may contain {{tokens}}, default 'https://example.com'
  zIndex, opacity
}
```
API: `https://api.qrserver.com/v1/create-qr-code/?data={encoded}&size={size}x{size}&margin=0`
where `size = Math.min(width, height)` in px.

### 3.5 Barcode Element (absolute)
```typescript
{
  id, type: 'barcode'
  x, y, width: 200, height: 80, rotation
  content:      string     // barcode value, may contain {{tokens}}, default '1234567890'
  format:       string     // 'CODE128' (only CODE128B implemented), default 'CODE128'
  displayValue: boolean    // show human-readable text below bars, default true
  color:        string     // bar color hex, default '#000000'
  background:   string     // background hex, default '#ffffff'
  zIndex, opacity
}
```
Format strings for UI dropdown: `CODE128`, `CODE39`, `EAN13`, `EAN8`, `UPC`, `ITF14`, `MSI`, `pharmacode`

### 3.6 Row/Col Container — Absolute (free-floating)
```typescript
{
  id, type: 'row' | 'col'
  isSection:    false | undefined
  x, y:         number     // absolute position on canvas
  width:        number     // px
  height:       number     // px
  rotation:     number
  gap:          number     // px gap between children, default 8
  padding:      number     // px padding inside, default 8
  alignItems:   'flex-start'|'center'|'flex-end'|'stretch'  // default 'flex-start'
  background:   string     // hex or 'transparent', default 'transparent'
  gradient:     GradientDef | null
  borderRadius: number     // px, default 0
  boxShadow?:   string
  locked:       boolean    // if true: no drag, default false
  opacity:      number     // default 1
  zIndex:       number     // default 1
  children:     FlexChild[]
}
```
- `row` → `flexDirection: row`
- `col` → `flexDirection: column`
- **`overflow: visible`** — children grow container, never clip

### 3.7 Row/Col Container — Section (full-width flow)
Same as 3.6 but:
```typescript
{
  isSection:    true
  // x, y, width: NOT PRESENT — section fills 100% canvas width
  minHeight:    number     // px, default 60
  // no zIndex — stacked by DOM order
}
```
Sections are rendered in a vertical flex column at the top of the canvas. Not draggable.

### 3.8 Flex Child Elements
Used inside Row/Col children arrays. No `x`, `y`, `zIndex`. Add flex props:

```typescript
// Flex positioning props (replace x/y/zIndex)
{
  flex:       number    // CSS flex-grow, default 0
  alignSelf:  'auto'|'flex-start'|'center'|'flex-end'|'stretch'  // default 'auto'
}
```

**Child Text:**
```typescript
{
  type: 'text'
  flex, alignSelf
  width:  number | 'auto'    // default 'auto'
  height: number | 'auto'    // default 'auto'
  content, fontSize: 14, fontFamily, fontWeight, fontStyle, textAlign, color, lineHeight
  textGradient: GradientDef | null
  opacity
}
// CSS: white-space: pre-wrap; overflow-wrap: break-word
```

**Child Shape:**
```typescript
{ type:'shape', flex, alignSelf, width:60, height:40, fill, stroke, strokeWidth, borderRadius, gradient, boxShadow?, opacity }
```

**Child Image:**
```typescript
{ type:'image', flex, alignSelf, width:80, height:60, src, objectFit, borderRadius, opacity }
```

**Child QR:**
```typescript
{ type:'qr', flex, alignSelf, width:60, height:60, content, opacity }
```

**Child Barcode:**
```typescript
{ type:'barcode', flex, alignSelf, width:160, height:60, content, format, displayValue, color, background, opacity }
```

**Child Row/Col (nested container):**
```typescript
{
  type: 'row'|'col'
  flex: 0, flexShrink: 1   // shrinks to content
  width: number | undefined, height: number | undefined
  gap, padding, alignItems, background, gradient, borderRadius
  children: FlexChild[]
  // NO overflow:hidden — content sizes the container
}
```

---

## 4. Canvas Size Reference

| Key | Label | Width mm | Height mm | Category |
|---|---|---|---|---|
| `A4` | A4 | 210 | 297 | document |
| `Letter` | Letter | 215.9 | 279.4 | document |
| `A5` | A5 | 148 | 210 | document |
| `4x6` | 4×6 Label | 101.6 | 152.4 | label |
| `2x2` | 2×2 Sticker | 50.8 | 50.8 | label |
| `3x1` | 3×1 Strip | 76.2 | 25.4 | label |
| `4x4` | 4×4 Square | 101.6 | 101.6 | label |
| `custom` | Custom | 100 | 100 | both |

---

## 5. Element Default Values

### ID Generation
```
Format: "el_{Date.now()}_{globalCounter++}"
Example: "el_1719000000000_0"
```

### Absolute Element Factories (defaults + override merging)

```
createTextElement:
  x:20, y:20, width:200, height:60, rotation:0
  content:'Double-click to edit', fontSize:16, fontFamily:'Inter'
  fontWeight:'normal', fontStyle:'normal', textAlign:'left'
  color:'#1A1A1A', lineHeight:1.4, opacity:1, zIndex:1

createShapeElement(shape):
  x:40, y:40, width:120, height:80, rotation:0
  fill:'#E8E6E1', stroke:'#1A1A1A', strokeWidth:1
  borderRadius: shape==='circle' ? 50 : 4
  opacity:1, zIndex:1

createImageElement:
  x:40, y:40, width:150, height:100, rotation:0
  src:'', objectFit:'cover', borderRadius:0, opacity:1, zIndex:1

createQRElement:
  x:40, y:40, width:80, height:80, rotation:0
  content:'https://example.com', opacity:1, zIndex:1

createBarcodeElement:
  x:40, y:40, width:200, height:80, rotation:0
  content:'1234567890', format:'CODE128', displayValue:true
  color:'#000000', background:'#ffffff', opacity:1, zIndex:1

createRowElement (Section):
  isSection:true, minHeight:60, gap:8, padding:8
  alignItems:'center', background:'transparent', borderRadius:0, opacity:1, children:[]

createColElement (Section):
  isSection:true, minHeight:60, gap:8, padding:8
  alignItems:'flex-start', background:'transparent', borderRadius:0, opacity:1, children:[]
```

### Flex Child Factories

```
createChildText:
  flex:0, alignSelf:'auto', width:'auto', height:'auto'
  content:'Text', fontSize:14, fontFamily:'Inter'
  fontWeight:'normal', fontStyle:'normal', textAlign:'left'
  color:'#1A1A1A', lineHeight:1.4, opacity:1

createChildShape(shape):
  flex:0, alignSelf:'auto', width:60, height:40
  fill:'#E8E6E1', stroke:'#1A1A1A', strokeWidth:1
  borderRadius: circle?50:4, opacity:1

createChildImage:
  flex:0, alignSelf:'auto', width:80, height:60
  src:'', objectFit:'cover', borderRadius:0, opacity:1

createChildQR:
  flex:0, alignSelf:'auto', width:60, height:60
  content:'https://example.com', opacity:1

createChildBarcode:
  flex:0, alignSelf:'auto', width:160, height:60
  content:'1234567890', format:'CODE128', displayValue:true
  color:'#000000', background:'#ffffff', opacity:1

Row child added from tree:
  {type:'row', flex:0, alignSelf:'auto', width:'100%', height:'auto',
   gap:8, padding:4, alignItems:'center', background:'transparent', borderRadius:0, children:[]}

Col child added from tree:
  {type:'col', flex:0, alignSelf:'auto', width:'auto', height:'auto',
   gap:8, padding:4, alignItems:'flex-start', background:'transparent', borderRadius:0, children:[]}
```

### Recursive Tree Operations (for nested children)
```
updateNodeInTree(nodes, nodeId, changes):
  map nodes — if id matches: merge changes; if has children: recurse

deleteNodeInTree(nodes, nodeId):
  filter out nodeId at any depth, recurse into children

findNodeInTree(nodes, nodeId):
  DFS — returns node or null

addChildDeep(nodes, containerId, child):
  map nodes — if id matches containerId: append to children array; if has children: recurse
``