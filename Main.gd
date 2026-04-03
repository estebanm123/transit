class_name Main extends Node2D

const ZoomMin: float = 0.15
const ZoomMax: float = 5.0

var _generator: CityGenerator
var _city: City
var _zoom: float = 1.0
var _pan: Vector2 = Vector2.ZERO
var _dragging: bool = false
var _dragOrigin: Vector2 = Vector2.ZERO
var _panOrigin: Vector2 = Vector2.ZERO
var _font: Font


func _ready() -> void:
    _generator = CityGenerator.new()
    _generator.rng.seed = 42
    _font = ThemeDB.fallback_font
    _city = _generator.generate()
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
        _generator.rng.seed = _generator.rng.randi()
        _city = _generator.generate()
        queue_redraw()


func _zoomAt(screenPos: Vector2, factor: float) -> void:
    var newZoom: float = clamp(_zoom * factor, ZoomMin, ZoomMax)
    if newZoom == _zoom:
        return
    _pan = screenPos + (_pan - screenPos) * (newZoom / _zoom)
    _zoom = newZoom
    queue_redraw()


func _draw() -> void:
    var vpSize: Vector2 = get_viewport_rect().size
    draw_rect(Rect2(Vector2.ZERO, vpSize), Color(0.08, 0.08, 0.08))

    draw_set_transform(_pan, 0.0, Vector2(_zoom, _zoom))

    draw_rect(Rect2(0, 0, City.MapW, City.MapH), City.CCountryside)

    for row in City.Rows:
        for col in City.Cols:
            var zone: int = _city.zones[row][col]
            if zone == Zone.Empty:
                continue
            if _city.parcelOwner[row][col] != Vector2i(col, row):
                continue
            var extent: Vector2i = _city.parcelExtent[row][col]
            var rect: Rect2 = _city.mergedBlockRect(col, row)
            var streetLeft: float = _city.vertStreetWidths[col]
            var streetRight: float = _city.vertStreetWidths[extent.x + 1]
            var streetTop: float = _city.horzStreetWidths[row]
            var streetBottom: float = _city.horzStreetWidths[extent.y + 1]
            draw_rect(Rect2(rect.position.x - streetLeft, rect.position.y - streetTop,
                    rect.size.x + streetLeft + streetRight,
                    rect.size.y + streetTop + streetBottom), City.CStreet)
            var color: Color = _city.colors[row][col]
            draw_rect(rect, color)
            _drawZoneDetail(zone, color, _city.details[row][col])

    draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
    _drawLegend()


func _drawZoneDetail(zone: int, color: Color, det: Dictionary) -> void:
    match zone:
        Zone.Park:
            for p: Rect2 in det.get("paths", []):
                draw_rect(p, color.darkened(0.20))
            for t2 in det.get("trees", []):
                draw_circle(t2["p"], t2["r"], color.darkened(0.30))
                draw_circle(t2["p"], t2["r"] * 0.55, color.lightened(0.10))

        Zone.Residential:
            var density: int = det.get("density", 3)
            for bld: Rect2 in det.get("blds", []):
                if density == 1:
                    var roofBaseY: float = bld.position.y + bld.size.y * 0.42
                    var bodyHeight: float = bld.size.y * 0.58
                    draw_colored_polygon(PackedVector2Array([
                        Vector2(bld.position.x - 1.0, roofBaseY),
                        Vector2(bld.end.x + 1.0, roofBaseY),
                        Vector2(bld.position.x + bld.size.x * 0.5, bld.position.y),
                    ]), color.darkened(0.22))
                    draw_rect(Rect2(bld.position.x, roofBaseY, bld.size.x, bodyHeight),
                            color.darkened(0.38))
                    var doorWidth: float = bld.size.x * 0.28
                    draw_rect(Rect2(bld.position.x + (bld.size.x - doorWidth) * 0.5,
                            bld.end.y - bodyHeight * 0.45, doorWidth, bodyHeight * 0.45),
                            color.darkened(0.60))
                else:
                    draw_rect(bld, color.darkened(0.38))
                    var floors: int = density
                    var floorHeight: float = bld.size.y / floors
                    var windowColor: Color = color.lightened(0.32)
                    for f in floors:
                        var floorY: float = bld.position.y + f * floorHeight + 1.5
                        var windowHeight: float = max(2.0, floorHeight - 3.5)
                        var winX: float = bld.position.x + 2.0
                        while winX + 3.5 < bld.end.x - 1.5:
                            draw_rect(Rect2(winX, floorY, 3.5, windowHeight), windowColor)
                            winX += 6.0

        Zone.Commercial:
            for bld: Rect2 in det.get("blds", []):
                draw_rect(bld, color.darkened(0.44))

        Zone.OfficeIndustry:
            for bld: Rect2 in det.get("blds", []):
                draw_rect(bld, color.darkened(0.30))


func _drawLegend() -> void:
    const LegendWidth: float = 180.0
    const ItemHeight: float = 26.0
    const Pad: float = 6.0
    const SwatchW: float = 18.0
    const SwatchH: float = 18.0
    const FontSize: int = 14

    var items: Array = [
        {"c": City.CPark,   "lbl": "Park"},
        {"c": City.CRes[2], "lbl": "Residential"},
        {"c": City.CCom[0], "lbl": "Commercial"},
        {"c": City.CInd[1], "lbl": "Office/Industry"},
    ]

    var vpSize: Vector2 = get_viewport_rect().size
    var legendX: float = vpSize.x - LegendWidth - 12.0
    var legendY: float = vpSize.y - items.size() * ItemHeight - Pad * 2 - 12.0

    draw_rect(
        Rect2(legendX - Pad, legendY - Pad,
                LegendWidth + Pad * 2, items.size() * ItemHeight + Pad * 2),
        Color(0.0, 0.0, 0.0, 0.60))

    for i in items.size():
        var itemY: float = legendY + i * ItemHeight
        draw_rect(Rect2(legendX, itemY, SwatchW, SwatchH), items[i]["c"])
        draw_rect(Rect2(legendX, itemY, SwatchW, SwatchH), Color(1, 1, 1, 0.25), false)
        if _font:
            draw_string(_font,
                Vector2(legendX + SwatchW + 8.0, itemY + SwatchH - 3.0),
                items[i]["lbl"],
                HORIZONTAL_ALIGNMENT_LEFT, -1, FontSize,
                Color.WHITE)
