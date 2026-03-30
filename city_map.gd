extends Node2D

const MapW: int = 2560
const MapH: int = 1440
const Margin: int = 20
const Cols: int = 20
const Rows: int = 12
const StreetW: int = 14

enum Zone { Park, Residential, Commercial, Industrial }

const CStreet: Color = Color("#3b3b40")
const CRoadMark: Color = Color(0.72, 0.68, 0.42, 0.50)

const CPark := [
    Color("#3d6b4a"),
    Color("#548a5c"),
    Color("#6aaa6e"),
]

const CRes := [
    Color("#2a4f6e"),
    Color("#3a6888"),
    Color("#4e82a4"),
    Color("#66a0c0"),
]

const CCom := [
    Color("#c09030"),
    Color("#d4a840"),
]

const CInd := [
    Color("#585860"),
    Color("#747478"),
    Color("#90909a"),
]

const ZoomMin: float = 0.15
const ZoomMax: float = 5.0

var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var colWidths: Array[float] = []
var rowHeights: Array[float] = []
var streetW_v: Array[float] = []
var streetW_h: Array[float] = []
var _colX: Array[float] = []
var _rowY: Array[float] = []
var _origin: Vector2 = Vector2(Margin, Margin)

var _zones: Array
var _colors: Array
var _details: Array
var _font: Font

var _zoom: float = 1.0
var _pan: Vector2 = Vector2.ZERO
var _dragging: bool = false
var _dragOrigin: Vector2 = Vector2.ZERO
var _panOrigin: Vector2 = Vector2.ZERO

func _ready() -> void:
    rng.seed = 42
    _font = ThemeDB.fallback_font
    _computeLayout()
    _buildMap()
    queue_redraw()


func _input(event: InputEvent) -> void:
    if event is InputEventMouseButton:
        match event.button_index:
            MOUSE_BUTTON_LEFT, MOUSE_BUTTON_MIDDLE:
                if event.pressed:
                    _dragging = true
                    _dragOrigin = event.position
                    _panOrigin = _pan
                else:
                    _dragging = false
            MOUSE_BUTTON_WHEEL_UP:
                _zoomAt(event.position, 1.15)
            MOUSE_BUTTON_WHEEL_DOWN:
                _zoomAt(event.position, 1.0 / 1.15)
    elif event is InputEventMouseMotion and _dragging:
        _pan = _panOrigin + (event.position - _dragOrigin)
        queue_redraw()
    elif event is InputEventKey and event.pressed and event.keycode == KEY_R:
        rng.seed = rng.randi()
        _computeLayout()
        _buildMap()
        queue_redraw()


func _zoomAt(screenPos: Vector2, factor: float) -> void:
    var newZoom: float = clamp(_zoom * factor, ZoomMin, ZoomMax)
    if newZoom == _zoom:
        return
    _pan = screenPos + (_pan - screenPos) * (newZoom / _zoom)
    _zoom = newZoom
    queue_redraw()


func _randomStreetW() -> float:
    var r: float = rng.randf()
    if r < 0.08:
        return 32.0
    elif r < 0.35:
        return 18.0
    else:
        return 8.0


func _computeLayout() -> void:
    streetW_v.clear()
    for _i in Cols + 1:
        streetW_v.append(_randomStreetW())

    streetW_h.clear()
    for _i in Rows + 1:
        streetW_h.append(_randomStreetW())

    var totalStreetW: float = 0.0
    for sw in streetW_v:
        totalStreetW += sw
    var totalStreetH: float = 0.0
    for sh in streetW_h:
        totalStreetH += sh

    var aw: float = MapW - Margin * 2 - totalStreetW
    var ah: float = MapH - Margin * 2 - totalStreetH

    var wWeights: Array[float] = []
    var wSum: float = 0.0
    for _i in Cols:
        var w: float = rng.randf_range(0.7, 1.4)
        wWeights.append(w)
        wSum += w
    colWidths.clear()
    for w in wWeights:
        colWidths.append(aw * w / wSum)

    var hWeights: Array[float] = []
    var hSum: float = 0.0
    for _i in Rows:
        var h: float = rng.randf_range(0.7, 1.4)
        hWeights.append(h)
        hSum += h
    rowHeights.clear()
    for h in hWeights:
        rowHeights.append(ah * h / hSum)

    _colX.clear()
    var cx2: float = _origin.x + streetW_v[0]
    for col in Cols:
        _colX.append(cx2)
        cx2 += colWidths[col] + streetW_v[col + 1]

    _rowY.clear()
    var cy2: float = _origin.y + streetW_h[0]
    for row in Rows:
        _rowY.append(cy2)
        cy2 += rowHeights[row] + streetW_h[row + 1]


func _blockRect(col: int, row: int) -> Rect2:
    return Rect2(_colX[col], _rowY[row], colWidths[col], rowHeights[row])


func _buildMap() -> void:
    var cx: float = (Cols - 1) / 2.0
    var cy: float = (Rows - 1) / 2.0
    _zones = []
    _colors = []
    _details = []

    for row in Rows:
        var zr: Array = []
        var cr: Array = []
        var dr: Array = []
        for col in Cols:
            var dx: float = col - cx
            var dy: float = row - cy
            var d: float = sqrt(dx * dx + dy * dy)
            var corner: bool = (col == 0 or col == Cols - 1) and (row == 0 or row == Rows - 1)

            var z: Zone
            if corner and rng.randf() < 0.72:
                z = Zone.Park
            elif rng.randf() < 0.11:
                z = Zone.Park
            elif d < 1.6:
                z = Zone.Commercial
            elif d < 3.0:
                z = Zone.Residential
            elif rng.randf() < 0.52:
                z = Zone.Industrial
            else:
                z = Zone.Residential

            var c: Color
            match z:
                Zone.Park:
                    c = CPark[rng.randi() % CPark.size()]
                Zone.Residential:
                    var idx: int = clamp(int(d), 0, CRes.size() - 1)
                    c = CRes[CRes.size() - 1 - idx]
                Zone.Commercial:
                    c = CCom[rng.randi() % CCom.size()]
                Zone.Industrial:
                    c = CInd[rng.randi() % CInd.size()]
                _:
                    c = Color.WHITE

            zr.append(z)
            cr.append(c)
            dr.append(_genDetails(z, c, col, row))

        _zones.append(zr)
        _colors.append(cr)
        _details.append(dr)


func _genDetails(z: Zone, _c: Color, col: int, row: int) -> Dictionary:
    var rect: Rect2 = _blockRect(col, row)
    var d: Dictionary = {}

    match z:
        Zone.Park:
            d["paths"] = [
                Rect2(rect.position.x + rect.size.x * 0.44,
                      rect.position.y + 4,
                      rect.size.x * 0.12,
                      rect.size.y - 8),
                Rect2(rect.position.x + 4,
                      rect.position.y + rect.size.y * 0.44,
                      rect.size.x - 8,
                      rect.size.y * 0.12),
            ]
            var trees: Array = []
            for _i in rng.randi_range(6, 16):
                trees.append({
                    "p": Vector2(
                        rect.position.x + rng.randf_range(8.0, rect.size.x - 8.0),
                        rect.position.y + rng.randf_range(8.0, rect.size.y - 8.0)),
                    "r": rng.randf_range(4.0, 11.0),
                })
            d["trees"] = trees

        Zone.Residential:
            var blds: Array = []
            for _i in rng.randi_range(3, 9):
                var bw2: float = rng.randf_range(10.0, min(34.0, rect.size.x * 0.33))
                var bh2: float = rng.randf_range(10.0, min(34.0, rect.size.y * 0.33))
                blds.append(Rect2(
                    rect.position.x + rng.randf_range(5.0, rect.size.x - bw2 - 5.0),
                    rect.position.y + rng.randf_range(5.0, rect.size.y - bh2 - 5.0),
                    bw2, bh2))
            d["blds"] = blds

        Zone.Commercial:
            var blds: Array = []
            for _i in rng.randi_range(2, 5):
                var bw2: float = rng.randf_range(22.0, min(56.0, rect.size.x * 0.52))
                var bh2: float = rng.randf_range(22.0, min(56.0, rect.size.y * 0.52))
                blds.append(Rect2(
                    rect.position.x + rng.randf_range(4.0, rect.size.x - bw2 - 4.0),
                    rect.position.y + rng.randf_range(4.0, rect.size.y - bh2 - 4.0),
                    bw2, bh2))
            d["blds"] = blds

        Zone.Industrial:
            var blds: Array = []
            var stacks: Array = []
            for _i in rng.randi_range(1, 4):
                var bw2: float = rng.randf_range(26.0, min(80.0, rect.size.x * 0.70))
                var bh2: float = rng.randf_range(16.0, min(60.0, rect.size.y * 0.60))
                var br: Rect2 = Rect2(
                    rect.position.x + rng.randf_range(4.0, rect.size.x - bw2 - 4.0),
                    rect.position.y + rng.randf_range(4.0, rect.size.y - bh2 - 4.0),
                    bw2, bh2)
                blds.append(br)
                if rng.randf() < 0.40:
                    stacks.append(Vector2(br.position.x + br.size.x * 0.72, br.position.y))
            var lines: Array = []
            for i in 3:
                var ly: float = rect.position.y + (i + 1) * rect.size.y / 4.0
                lines.append([
                    Vector2(rect.position.x + 4.0, ly),
                    Vector2(rect.position.x + rect.size.x - 4.0, ly),
                ])
            d["blds"] = blds
            d["stacks"] = stacks
            d["lines"] = lines

    return d


func _draw() -> void:
    var vpSize: Vector2 = get_viewport_rect().size
    draw_rect(Rect2(Vector2.ZERO, vpSize), Color(0.08, 0.08, 0.08))

    draw_set_transform(_pan, 0.0, Vector2(_zoom, _zoom))

    draw_rect(Rect2(0, 0, MapW, MapH), CStreet)

    for row in Rows:
        for col in Cols:
            var rect: Rect2 = _blockRect(col, row)
            var zone: Zone = _zones[row][col]
            var color: Color = _colors[row][col]
            var details: Dictionary = _details[row][col]

            draw_rect(rect, color)
            _drawZoneDetail(zone, color, details)

    _drawRoadMarkings()

    draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
    _drawLegend()


func _drawZoneDetail(z: Zone, c: Color, det: Dictionary) -> void:
    match z:
        Zone.Park:
            for p: Rect2 in det.get("paths", []):
                draw_rect(p, c.darkened(0.20))
            for t in det.get("trees", []):
                draw_circle(t["p"], t["r"], c.darkened(0.30))
                draw_circle(t["p"], t["r"] * 0.55, c.lightened(0.10))

        Zone.Residential:
            for b: Rect2 in det.get("blds", []):
                draw_rect(b, c.darkened(0.38))
                draw_rect(Rect2(b.position.x, b.position.y, b.size.x, 2.0),
                          c.lightened(0.20))

        Zone.Commercial:
            for b: Rect2 in det.get("blds", []):
                draw_rect(b, c.darkened(0.44))
                var wc: Color = c.lightened(0.30)
                var xi: float = b.position.x + 2.0
                while xi + 4.0 < b.end.x:
                    var yi: float = b.position.y + 2.0
                    while yi + 6.0 < b.end.y:
                        draw_rect(Rect2(xi, yi, 4.0, 6.0), wc)
                        yi += 10.0
                    xi += 8.0

        Zone.Industrial:
            for b: Rect2 in det.get("blds", []):
                draw_rect(b, c.darkened(0.30))
                draw_rect(Rect2(b.position.x, b.position.y, b.size.x, 3.0),
                          c.lightened(0.12))
            for s: Vector2 in det.get("stacks", []):
                draw_rect(Rect2(s.x, s.y - 14.0, 6.0, 14.0), c.darkened(0.50))
                draw_rect(Rect2(s.x - 1.0, s.y - 15.0, 8.0, 3.0), c.darkened(0.40))
            for ln in det.get("lines", []):
                draw_line(ln[0], ln[1], c.darkened(0.24), 1.0)


func _drawRoadMarkings() -> void:
    var dash: float = 10.0
    var gap: float = 10.0

    var streetTopY: float = _origin.y
    for row in Rows + 1:
        var sw: float = streetW_h[row]
        if sw >= 2.0:
            var sy: float = streetTopY + sw * 0.5
            var x: float = _origin.x
            while x < MapW - Margin:
                draw_line(Vector2(x, sy),
                          Vector2(minf(x + dash, MapW - float(Margin)), sy),
                          CRoadMark, 1.0)
                x += dash + gap
        if row < Rows:
            streetTopY += sw + rowHeights[row]
        else:
            streetTopY += sw

    var streetLeftX: float = _origin.x
    for col in Cols + 1:
        var sw: float = streetW_v[col]
        if sw >= 2.0:
            var sx: float = streetLeftX + sw * 0.5
            var y: float = _origin.y
            while y < MapH - Margin:
                draw_line(Vector2(sx, y),
                          Vector2(sx, minf(y + dash, MapH - float(Margin))),
                          CRoadMark, 1.0)
                y += dash + gap
        if col < Cols:
            streetLeftX += sw + colWidths[col]
        else:
            streetLeftX += sw


func _drawLegend() -> void:
    const Lw: float = 180.0
    const ItemH: float = 26.0
    const Pad: float = 6.0
    const Sw: float = 18.0
    const Sh: float = 18.0
    const Fs: int = 14

    var items: Array = [
        {"c": CPark[1], "lbl": "Park"},
        {"c": CRes[2],  "lbl": "Residential"},
        {"c": CCom[0],  "lbl": "Commercial"},
        {"c": CInd[1],  "lbl": "Industrial"},
    ]

    var vpSize: Vector2 = get_viewport_rect().size
    var lx: float = vpSize.x - Lw - 12.0
    var ly0: float = vpSize.y - items.size() * ItemH - Pad * 2 - 12.0

    draw_rect(
        Rect2(lx - Pad, ly0 - Pad, Lw + Pad * 2, items.size() * ItemH + Pad * 2),
        Color(0.0, 0.0, 0.0, 0.60))

    for i in items.size():
        var ly: float = ly0 + i * ItemH
        draw_rect(Rect2(lx, ly, Sw, Sh), items[i]["c"])
        draw_rect(Rect2(lx, ly, Sw, Sh), Color(1, 1, 1, 0.25), false)
        if _font:
            draw_string(_font,
                Vector2(lx + Sw + 8.0, ly + Sh - 3.0),
                items[i]["lbl"],
                HORIZONTAL_ALIGNMENT_LEFT, -1, Fs,
                Color.WHITE)
