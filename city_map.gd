extends Node2D

const MapW: int = 1280
const MapH: int = 720
const Margin: int = 20
const Cols: int = 100
const Rows: int = 60
const StreetW: int = 14

enum Zone { Empty, Park, Residential, Commercial, OfficeIndustry }

const WArterial: float = 8.0
const WCollector: float = 4.0
const WLocal: float = 1.5

const CCountryside: Color = Color("#1e3312")
const CStreet: Color = Color("#3b3b40")

const CPark: Color = Color("#548a5c")

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
var _parcelOwner: Array = []
var _parcelExtent: Array = []
var _font: Font

var _numArms: int = 0
var _armAngles: Array[float] = []

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


func _computeLayout() -> void:
    # 1. Decide arm angles first — these drive the arterial layout
    _numArms = rng.randi_range(4, 6)
    _armAngles.clear()
    var baseAngle: float = rng.randf() * TAU
    for i in _numArms:
        _armAngles.append(baseAngle + float(i) * TAU / float(_numArms)
                          + rng.randf_range(-0.12, 0.12))

    # 2. Start all streets as narrow local roads
    streetW_v.clear()
    for _i in Cols + 1:
        streetW_v.append(WLocal)
    streetW_h.clear()
    for _i in Rows + 1:
        streetW_h.append(WLocal)

    # 3. Place collectors at semi-regular spacing
    var colSpacing: int = rng.randi_range(7, 11)
    var rowSpacing: int = rng.randi_range(5, 8)
    for col in Cols + 1:
        if col % colSpacing == 0:
            streetW_v[col] = WCollector
    for row in Rows + 1:
        if row % rowSpacing == 0:
            streetW_h[row] = WCollector

    # 4. Upgrade streets near each arm direction to arterials
    var cxF: float = Cols * 0.5
    var cyF: float = Rows * 0.5
    for armAngle: float in _armAngles:
        var ci: int = clamp(int(round(cxF + cos(armAngle) * cxF * 0.65)), 1, Cols - 1)
        var ri: int = clamp(int(round(cyF + sin(armAngle) * cyF * 0.65)), 1, Rows - 1)
        streetW_v[ci] = WArterial
        streetW_h[ri] = WArterial
        # Also promote the nearest collector on each side of center along the arm
        var ci2: int = clamp(int(round(cxF + cos(armAngle) * cxF * 0.28)), 1, Cols - 1)
        var ri2: int = clamp(int(round(cyF + sin(armAngle) * cyF * 0.28)), 1, Rows - 1)
        if streetW_v[ci2] < WArterial:
            streetW_v[ci2] = WCollector
        if streetW_h[ri2] < WArterial:
            streetW_h[ri2] = WCollector

    # 5. Compute block sizes from remaining available space
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


func _mergedBlockRect(col: int, row: int) -> Rect2:
    var ext: Vector2i = _parcelExtent[row][col]
    var x: float = _colX[col]
    var y: float = _rowY[row]
    var w: float = _colX[ext.x] + colWidths[ext.x] - x
    var h: float = _rowY[ext.y] + rowHeights[ext.y] - y
    return Rect2(x, y, w, h)


func _isInsideCity(col: int, row: int) -> bool:
    var cx: float = (Cols - 1) / 2.0
    var cy: float = (Rows - 1) / 2.0
    var dx: float = (col - cx) / (Cols / 2.0)
    var dy: float = (row - cy) / (Rows / 2.0)
    var nd: float = sqrt(dx * dx + dy * dy)
    if nd < 0.55:
        return true
    var angle: float = atan2(dy, dx)
    for armAngle: float in _armAngles:
        var diff: float = angle - armAngle
        diff -= TAU * round(diff / TAU)
        var t: float = max(0.0, 1.0 - abs(diff) / 0.65)
        if nd < 0.55 + 0.18 * t:
            return true
    return false


func _buildMap() -> void:
    var cx: float = (Cols - 1) / 2.0
    var cy: float = (Rows - 1) / 2.0
    _zones = []
    _colors = []
    _details = []
    _parcelOwner = []
    _parcelExtent = []

    var cityParkRatio: float = rng.randf_range(0.0, 0.043)
    var cityIndRatio: float = rng.randf_range(0.0, 0.25)
    var comCore: float = rng.randf_range(1.0, 5.0)
    var comFringe: float = comCore + rng.randf_range(0.6, 3.0)
    var cbdOfficeRatio: float = rng.randf_range(0.025, 0.25)

    for row in Rows:
        var zr: Array = []
        var cr: Array = []
        var po: Array = []
        var pe: Array = []
        for col in Cols:
            zr.append(null)
            cr.append(Color.WHITE)
            po.append(Vector2i(col, row))
            pe.append(Vector2i(col, row))
        _zones.append(zr)
        _colors.append(cr)
        _parcelOwner.append(po)
        _parcelExtent.append(pe)

    for row in Rows:
        for col in Cols:
            if _zones[row][col] != null:
                continue

            var dx: float = col - cx
            var dy: float = row - cy
            var d: float = sqrt(dx * dx + dy * dy)
            var corner: bool = (col == 0 or col == Cols - 1) and (row == 0 or row == Rows - 1)

            var z: Zone
            if not _isInsideCity(col, row):
                z = Zone.Empty
            elif d < comCore:
                if rng.randf() < cbdOfficeRatio:
                    z = Zone.OfficeIndustry
                else:
                    z = Zone.Commercial
            elif d < comFringe:
                if rng.randf() < 0.07:
                    z = Zone.Commercial
                elif rng.randf() < cityParkRatio * 0.5:
                    z = Zone.Park
                else:
                    z = Zone.Residential
            else:
                var parkChance: float = min(0.95, cityParkRatio * (3.0 if corner else 1.0))
                if rng.randf() < parkChance:
                    z = Zone.Park
                elif rng.randf() < 0.06:
                    z = Zone.Commercial
                elif rng.randf() < cityIndRatio:
                    z = Zone.OfficeIndustry
                else:
                    z = Zone.Residential

            var baseColor: Color
            match z:
                Zone.Park:
                    baseColor = CPark
                Zone.Residential:
                    var idx: int = clamp(int(d), 0, CRes.size() - 1)
                    baseColor = CRes[CRes.size() - 1 - idx]
                Zone.Commercial:
                    baseColor = CCom[rng.randi() % CCom.size()]
                Zone.OfficeIndustry:
                    baseColor = CInd[rng.randi() % CInd.size()]
                _:
                    baseColor = Color.WHITE

            _zones[row][col] = z
            _colors[row][col] = baseColor

            if (z == Zone.Park or z == Zone.OfficeIndustry) \
                    and rng.randf() <= (0.95 if z == Zone.Park else 0.55):
                var mergeLimit: int = 8 if z == Zone.Park else 1
                var maxC: int = col
                while maxC + 1 < Cols and maxC - col < mergeLimit:
                    var nc: int = maxC + 1
                    if _zones[row][nc] != null:
                        break
                    var ndx: float = nc - cx
                    var ndy: float = row - cy
                    var nd2: float = sqrt(ndx * ndx + ndy * ndy)
                    if not _isInsideCity(nc, row) or (z == Zone.Park and nd2 < comCore):
                        break
                    maxC += 1
                var maxR: int = row
                while maxR + 1 < Rows and maxR - row < mergeLimit:
                    var ok: bool = true
                    for nc in range(col, maxC + 1):
                        if _zones[maxR + 1][nc] != null:
                            ok = false
                            break
                        var ndx: float = nc - cx
                        var ndy: float = (maxR + 1) - cy
                        var nd2: float = sqrt(ndx * ndx + ndy * ndy)
                        if not _isInsideCity(nc, maxR + 1) \
                                or (z == Zone.Park and nd2 < comCore):
                            ok = false
                            break
                    if not ok:
                        break
                    maxR += 1
                if maxC > col or maxR > row:
                    for r in range(row, maxR + 1):
                        for c2 in range(col, maxC + 1):
                            _zones[r][c2] = z
                            _colors[r][c2] = baseColor
                            _parcelOwner[r][c2] = Vector2i(col, row)
                    _parcelExtent[row][col] = Vector2i(maxC, maxR)

    for row in Rows:
        var dr: Array = []
        for col in Cols:
            if _parcelOwner[row][col] != Vector2i(col, row):
                dr.append({})
                continue
            var dx: float = col - cx
            var dy: float = row - cy
            var d: float = sqrt(dx * dx + dy * dy)
            var z: Zone = _zones[row][col]
            var isOffice: bool = (z == Zone.OfficeIndustry and d < comCore)
            var nearCommercial: bool = false
            if z == Zone.Residential:
                var neighbors: Array[Vector2i] = [
                    Vector2i(col - 1, row), Vector2i(col + 1, row),
                    Vector2i(col, row - 1), Vector2i(col, row + 1),
                ]
                for nb: Vector2i in neighbors:
                    if nb.x >= 0 and nb.x < Cols and nb.y >= 0 and nb.y < Rows \
                            and _zones[nb.y][nb.x] == Zone.Commercial:
                        nearCommercial = true
                        break
            dr.append(_genDetails(z, _colors[row][col], _mergedBlockRect(col, row), d, isOffice, nearCommercial))
        _details.append(dr)


func _genDetails(z: Zone, _c: Color, rect: Rect2, dist: float = 0.0, isOffice: bool = false, nearCommercial: bool = false) -> Dictionary:
    var tileScale: float = sqrt(rect.get_area()) / 7.5
    var d: Dictionary = {}

    match z:
        Zone.Park:
            var trees: Array = []
            for _i in rng.randi_range(max(1, int(2.0 * tileScale)), max(1, int(6.0 * tileScale))):
                trees.append({
                    "p": Vector2(
                        rect.position.x + rng.randf_range(3.0, max(3.0, rect.size.x - 3.0)),
                        rect.position.y + rng.randf_range(3.0, max(3.0, rect.size.y - 3.0))),
                    "r": rng.randf_range(1.5, 4.0),
                })
            d["trees"] = trees

        Zone.Residential:
            var floors: int
            if dist < 3.0:
                floors = rng.randi_range(6, 10)
            elif dist < 6.0:
                if nearCommercial and rng.randf() < 0.50:
                    floors = rng.randi_range(6, 10)
                elif rng.randf() < 0.08:
                    floors = rng.randi_range(6, 10)
                else:
                    floors = rng.randi_range(3, 5)
            else:
                if nearCommercial and rng.randf() < 0.50:
                    floors = rng.randi_range(6, 10)
                elif rng.randf() < 0.05:
                    floors = rng.randi_range(6, 10)
                else:
                    floors = 1
            d["density"] = floors
            var blds: Array = []
            if floors == 1:
                for _i in rng.randi_range(max(1, int(1.0 * tileScale)), max(1, int(3.0 * tileScale))):
                    var bw2: float = rng.randf_range(5.0, max(5.0, min(9.0, rect.size.x * 0.28)))
                    var bh2: float = rng.randf_range(6.0, max(6.0, min(10.0, rect.size.y * 0.28)))
                    blds.append(Rect2(
                        rect.position.x + rng.randf_range(0.5, max(0.5, rect.size.x - bw2 - 0.5)),
                        rect.position.y + rng.randf_range(0.5, max(0.5, rect.size.y - bh2 - 0.5)),
                        bw2, bh2))
            else:
                var towerH: float = min(float(floors) * 2.7 + 1.5, rect.size.y - 4.0)
                for _i in rng.randi_range(max(1, int(1.0 * tileScale)), max(1, int(3.0 * tileScale))):
                    var bw2: float = rng.randf_range(3.5, min(8.0, rect.size.x * 0.28))
                    blds.append(Rect2(
                        rect.position.x + rng.randf_range(2.0, max(2.0, rect.size.x - bw2 - 2.0)),
                        rect.position.y + rng.randf_range(2.0, max(2.0, rect.size.y - towerH - 2.0)),
                        bw2, towerH))
            d["blds"] = blds

        Zone.Commercial:
            var blds: Array = []
            for _i in rng.randi_range(max(1, int(1.0 * tileScale)), max(1, int(2.0 * tileScale))):
                var bw2: float = rng.randf_range(6.0, min(18.0, rect.size.x * 0.55))
                var bh2: float = rng.randf_range(4.0, min(rect.size.y * 0.80, rect.size.y - 3.0))
                blds.append(Rect2(
                    rect.position.x + rng.randf_range(1.5, max(1.5, rect.size.x - bw2 - 1.5)),
                    rect.position.y + rng.randf_range(1.5, max(1.5, rect.size.y - bh2 - 1.5)),
                    bw2, bh2))
            d["blds"] = blds

        Zone.OfficeIndustry:
            var blds: Array = []
            for _i in rng.randi_range(max(1, int(1.0 * tileScale)), max(1, int(2.0 * tileScale))):
                var bw2: float = rng.randf_range(9.0, min(27.0, rect.size.x * 0.70))
                var bh2: float = rng.randf_range(5.5, min(20.0, rect.size.y * 0.60))
                blds.append(Rect2(
                    rect.position.x + rng.randf_range(1.5, max(1.5, rect.size.x - bw2 - 1.5)),
                    rect.position.y + rng.randf_range(1.5, max(1.5, rect.size.y - bh2 - 1.5)),
                    bw2, bh2))
            d["blds"] = blds

    return d


func _draw() -> void:
    var vpSize: Vector2 = get_viewport_rect().size
    draw_rect(Rect2(Vector2.ZERO, vpSize), Color(0.08, 0.08, 0.08))

    draw_set_transform(_pan, 0.0, Vector2(_zoom, _zoom))

    draw_rect(Rect2(0, 0, MapW, MapH), CCountryside)

    for row in Rows:
        for col in Cols:
            var zone: Zone = _zones[row][col]
            if zone == Zone.Empty:
                continue
            if _parcelOwner[row][col] != Vector2i(col, row):
                continue
            var ext: Vector2i = _parcelExtent[row][col]
            var rect: Rect2 = _mergedBlockRect(col, row)
            var sl: float = streetW_v[col]
            var sr: float = streetW_v[ext.x + 1]
            var st: float = streetW_h[row]
            var sb: float = streetW_h[ext.y + 1]
            draw_rect(Rect2(rect.position.x - sl, rect.position.y - st,
                            rect.size.x + sl + sr, rect.size.y + st + sb), CStreet)
            var color: Color = _colors[row][col]
            draw_rect(rect, color)
            _drawZoneDetail(zone, color, _details[row][col])

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
            var density: int = det.get("density", 3)
            for b: Rect2 in det.get("blds", []):
                if density == 1:
                    var roofBaseY: float = b.position.y + b.size.y * 0.42
                    var bodyH: float = b.size.y * 0.58
                    draw_colored_polygon(PackedVector2Array([
                        Vector2(b.position.x - 1.0, roofBaseY),
                        Vector2(b.end.x + 1.0, roofBaseY),
                        Vector2(b.position.x + b.size.x * 0.5, b.position.y),
                    ]), c.darkened(0.22))
                    draw_rect(Rect2(b.position.x, roofBaseY, b.size.x, bodyH),
                              c.darkened(0.38))
                    var dw: float = b.size.x * 0.28
                    draw_rect(Rect2(b.position.x + (b.size.x - dw) * 0.5,
                                   b.end.y - bodyH * 0.45, dw, bodyH * 0.45),
                              c.darkened(0.60))
                else:
                    draw_rect(b, c.darkened(0.38))
                    var floors: int = density
                    var floorH: float = b.size.y / floors
                    var wc: Color = c.lightened(0.32)
                    for f in floors:
                        var fy: float = b.position.y + f * floorH + 1.5
                        var winH: float = max(2.0, floorH - 3.5)
                        var xi: float = b.position.x + 2.0
                        while xi + 3.5 < b.end.x - 1.5:
                            draw_rect(Rect2(xi, fy, 3.5, winH), wc)
                            xi += 6.0

        Zone.Commercial:
            for b: Rect2 in det.get("blds", []):
                draw_rect(b, c.darkened(0.44))

        Zone.OfficeIndustry:
            for b: Rect2 in det.get("blds", []):
                draw_rect(b, c.darkened(0.30))



func _drawLegend() -> void:
    const Lw: float = 180.0
    const ItemH: float = 26.0
    const Pad: float = 6.0
    const Sw: float = 18.0
    const Sh: float = 18.0
    const Fs: int = 14

    var items: Array = [
        {"c": CPark, "lbl": "Park"},
        {"c": CRes[2],  "lbl": "Residential"},
        {"c": CCom[0],  "lbl": "Commercial"},
        {"c": CInd[1],  "lbl": "Office/Industry"},
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
