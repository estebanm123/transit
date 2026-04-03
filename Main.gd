class_name Main extends Node2D

const ZoomMin: float = 0.15
const ZoomMax: float = 5.0

var _generator: CityGenerator
var _city: City
var _traffic: Traffic
var _zoom: float = 1.0
var _pan: Vector2 = Vector2.ZERO
var _dragging: bool = false
var _dragOrigin: Vector2 = Vector2.ZERO
var _panOrigin: Vector2 = Vector2.ZERO
var _font: Font
var _cityLayer: CityLayer
var _trafficLayer: TrafficLayer
var _hudNode: Node2D
var _fpsLabel: Label


func _ready() -> void:
	_font = ThemeDB.fallback_font
	_generator = CityGenerator.new()
	_generator.rng.seed = 42

	_cityLayer = CityLayer.new()
	add_child(_cityLayer)

	_trafficLayer = TrafficLayer.new()
	add_child(_trafficLayer)

	var hudCanvas := CanvasLayer.new()
	hudCanvas.layer = 1
	add_child(hudCanvas)

	_hudNode = Node2D.new()
	_hudNode.draw.connect(_drawLegend)
	hudCanvas.add_child(_hudNode)

	_fpsLabel = Label.new()
	_fpsLabel.position = Vector2(8.0, 8.0)
	hudCanvas.add_child(_fpsLabel)

	get_viewport().size_changed.connect(queue_redraw)
	get_viewport().size_changed.connect(_hudNode.queue_redraw)

	_generateCity()
	queue_redraw()
	_hudNode.queue_redraw()


func _generateCity() -> void:
	_city = _generator.generate()
	_traffic = Traffic.new()
	_traffic.init(_city)
	_cityLayer.setup(_city)
	_trafficLayer.setup(_traffic, _city)
	_updateLayerTransforms()


func _updateLayerTransforms() -> void:
	_cityLayer.position = _pan
	_cityLayer.scale = Vector2(_zoom, _zoom)
	_trafficLayer.position = _pan
	_trafficLayer.scale = Vector2(_zoom, _zoom)


func _process(_delta: float) -> void:
	_fpsLabel.text = "FPS: %d" % Engine.get_frames_per_second()


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
		_updateLayerTransforms()
	elif event is InputEventKey and event.pressed and event.keycode == KEY_R:
		_generator.rng.seed = _generator.rng.randi()
		_generateCity()


func _zoomAt(screenPos: Vector2, factor: float) -> void:
	var newZoom: float = clamp(_zoom * factor, ZoomMin, ZoomMax)
	if newZoom == _zoom:
		return
	_pan = screenPos + (_pan - screenPos) * (newZoom / _zoom)
	_zoom = newZoom
	_updateLayerTransforms()


func _draw() -> void:
	var vpSize: Vector2 = get_viewport_rect().size
	draw_rect(Rect2(Vector2.ZERO, vpSize), Color(0.08, 0.08, 0.08))


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

	_hudNode.draw_rect(
		Rect2(legendX - Pad, legendY - Pad,
				LegendWidth + Pad * 2, items.size() * ItemHeight + Pad * 2),
		Color(0.0, 0.0, 0.0, 0.60))

	for i in items.size():
		var itemY: float = legendY + i * ItemHeight
		_hudNode.draw_rect(Rect2(legendX, itemY, SwatchW, SwatchH), items[i]["c"])
		_hudNode.draw_rect(Rect2(legendX, itemY, SwatchW, SwatchH), Color(1, 1, 1, 0.25), false)
		if _font:
			_hudNode.draw_string(_font,
				Vector2(legendX + SwatchW + 8.0, itemY + SwatchH - 3.0),
				items[i]["lbl"],
				HORIZONTAL_ALIGNMENT_LEFT, -1, FontSize,
				Color.WHITE)
