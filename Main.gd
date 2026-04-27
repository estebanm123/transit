class_name Main extends Node2D

const ZoomMin: float = 0.15
const ZoomMax: float = 5.0
const SimulationRateNormal: int = 1
const SimulationRateMax: int = 8

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
var _debugger: TrafficDebugger
var _hudNode: Node2D
var _fpsLabel: Label
var _commuteLabel: Label
var _transportDistributionLabel: Label
var _controlsContainer: HBoxContainer
var _speedButton: Button
var _congestedButton: Button
var _debugShiftHeld: bool = false
var _debugMouseScreenPos: Vector2 = Vector2.ZERO
var _debugRadius: float = 16.7
var _paused: bool = false
var _simulationRate: int = SimulationRateNormal


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
    _hudNode.draw.connect(_drawDebugOverlay)
    hudCanvas.add_child(_hudNode)

    _fpsLabel = Label.new()
    _fpsLabel.position = Vector2(8.0, 8.0)
    hudCanvas.add_child(_fpsLabel)

    _commuteLabel = Label.new()
    _commuteLabel.position = Vector2(8.0, 64.0)
    hudCanvas.add_child(_commuteLabel)

    _transportDistributionLabel = Label.new()
    _transportDistributionLabel.position = Vector2(8.0, 86.0)
    hudCanvas.add_child(_transportDistributionLabel)

    _controlsContainer = HBoxContainer.new()
    _controlsContainer.position = Vector2(8.0, 36.0)
    _controlsContainer.add_theme_constant_override("separation", 8)
    hudCanvas.add_child(_controlsContainer)

    _speedButton = Button.new()
    _speedButton.pressed.connect(_incrementSimulationRate)
    _controlsContainer.add_child(_speedButton)

    _congestedButton = Button.new()
    _congestedButton.text = "Congested Start (C)"
    _congestedButton.pressed.connect(_generateCongestedCity)
    _controlsContainer.add_child(_congestedButton)

    get_viewport().size_changed.connect(queue_redraw)
    get_viewport().size_changed.connect(_hudNode.queue_redraw)

    _generateCity()
    _updateSpeedButton()
    queue_redraw()
    _hudNode.queue_redraw()


func _generateCity(startCongested: bool = false) -> void:
    _city = _generator.generate()
    _traffic = Traffic.new()
    _traffic.init(_city, startCongested)
    _cityLayer.setup(_city)
    _trafficLayer.setup(_traffic, _city)
    _trafficLayer.simulationRate = _simulationRate
    _debugger = TrafficDebugger.new()
    _debugger.init(_traffic)
    _updateLayerTransforms()


func _incrementSimulationRate() -> void:
    if _simulationRate >= SimulationRateMax:
        _simulationRate = SimulationRateNormal
    else:
        _simulationRate *= 2
    _trafficLayer.simulationRate = _simulationRate
    _updateSpeedButton()
    _hudNode.queue_redraw()


func _generateCongestedCity() -> void:
    _generateCity(true)
    queue_redraw()
    _hudNode.queue_redraw()


func _updateSpeedButton() -> void:
    _speedButton.text = "Speed x%d (F)" % _simulationRate


func _updateLayerTransforms() -> void:
    _cityLayer.position = _pan
    _cityLayer.scale = Vector2(_zoom, _zoom)
    _trafficLayer.position = _pan
    _trafficLayer.scale = Vector2(_zoom, _zoom)


func _getTransportDistributionText() -> String:
    var distribution: Dictionary = _city.getOverallTransportDistribution()
    return "Transport modes: Cars %.0f%%  Bikes %.0f%%  Walking %.0f%%" % [
        distribution.get(City.TransportCar, 0.0) * 100.0,
        distribution.get(City.TransportBike, 0.0) * 100.0,
        distribution.get(City.TransportWalk, 0.0) * 100.0,
    ]


func _process(_delta: float) -> void:
    _fpsLabel.text = "FPS: %d" % Engine.get_frames_per_second()
    if _traffic != null:
        _commuteLabel.text = "Commute happiness: %.1f / 10" % _traffic.getCommuteHappiness()
    if _city != null:
        _transportDistributionLabel.text = _getTransportDistributionText()
    var shiftNow: bool = Input.is_key_pressed(KEY_SHIFT)
    if shiftNow != _debugShiftHeld:
        _debugShiftHeld = shiftNow
        _hudNode.queue_redraw()
    if _debugShiftHeld:
        var mouseScreen: Vector2 = get_viewport().get_mouse_position()
        if mouseScreen != _debugMouseScreenPos:
            _debugMouseScreenPos = mouseScreen
            _hudNode.queue_redraw()


func _input(event: InputEvent) -> void:
    if event is InputEventMouseButton:
        if _controlsContainer.get_global_rect().has_point(event.position):
            return
        match event.button_index:
            MOUSE_BUTTON_LEFT:
                if event.pressed and event.shift_pressed:
                    var worldPos: Vector2 = (event.position - _pan) / _zoom
                    _debugger.debugCarsNear(worldPos, _debugRadius)
                elif event.pressed:
                    _dragging = true
                    _dragOrigin = event.position
                    _panOrigin = _pan
                else:
                    _dragging = false
            MOUSE_BUTTON_MIDDLE:
                if event.pressed:
                    _dragging = true
                    _dragOrigin = event.position
                    _panOrigin = _pan
                else:
                    _dragging = false
            MOUSE_BUTTON_WHEEL_UP:
                if event.shift_pressed:
                    _debugRadius = maxf(5.0, _debugRadius * (1.0 / 1.15))
                    _hudNode.queue_redraw()
                else:
                    _zoomAt(event.position, 1.15)
            MOUSE_BUTTON_WHEEL_DOWN:
                if event.shift_pressed:
                    _debugRadius = minf(500.0, _debugRadius * 1.15)
                    _hudNode.queue_redraw()
                else:
                    _zoomAt(event.position, 1.0 / 1.15)
    elif event is InputEventMouseMotion:
        _debugMouseScreenPos = event.position
        if _debugShiftHeld:
            _hudNode.queue_redraw()
        if _dragging:
            _pan = _panOrigin + (event.position - _dragOrigin)
            _updateLayerTransforms()
    elif event is InputEventKey and event.pressed and not event.echo:
        match event.keycode:
            KEY_SPACE:
                _paused = not _paused
                _trafficLayer.paused = _paused
                _hudNode.queue_redraw()
            KEY_R:
                _generator.rng.seed = _generator.rng.randi()
                _generateCity()
            KEY_F:
                _incrementSimulationRate()
            KEY_C:
                _generator.rng.seed = _generator.rng.randi()
                _generateCongestedCity()


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
        {"c": City.CRes[0], "lbl": "Residential"},
        {"c": City.CRes[2], "lbl": "Medium Residential"},
        {"c": City.CRes[3], "lbl": "High-rise Residential"},
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


func _drawDebugOverlay() -> void:
    if _paused:
        var vpSize: Vector2 = get_viewport_rect().size
        _hudNode.draw_string(_font, Vector2(vpSize.x * 0.5 - 30.0, 36.0),
                "PAUSED", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(1.0, 0.85, 0.2, 0.9))
    if not _debugShiftHeld:
        return
    var screenRadius: float = _debugRadius * _zoom
    _hudNode.draw_arc(_debugMouseScreenPos, screenRadius,
            0.0, TAU, 64, Color(1.0, 1.0, 0.0, 0.85), 1.5)
    _hudNode.draw_arc(_debugMouseScreenPos, 4.0,
            0.0, TAU, 16, Color(1.0, 1.0, 0.0, 0.85), 2.0)
