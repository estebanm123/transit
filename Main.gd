class_name Main extends Node2D

const ZoomMin: float = 0.15
const ZoomMax: float = 5.0
const ZoomStepFactor: float = 1.15
const TrackpadScrollPixelsPerStep: float = 20.0
const SimulationRateNormal: int = 1
const SimulationRateMax: int = 8

var _generator: CityGenerator
var _city: City
var _traffic: Traffic
var _subwaySystem: SubwaySystem
var _abilityManager: AbilityManager
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
var _hoverTileLabel: Label
var _abilityStatusLabel: Label
var _controlsContainer: HBoxContainer
var _speedButton: Button
var _abilityButtons: Array[Button] = []
var _debugShiftHeld: bool = false
var _debugMouseScreenPos: Vector2 = Vector2.ZERO
var _debugRadius: float = 16.7
var _paused: bool = false
var _simulationRate: int = SimulationRateNormal
var _subwayConnectionDragActive: bool = false
var _subwayConnectionDragSourceIndex: int = -1
var _heatmapVisible: bool = false


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

    _hoverTileLabel = Label.new()
    hudCanvas.add_child(_hoverTileLabel)

    _abilityStatusLabel = Label.new()
    _abilityStatusLabel.position = Vector2(8.0, 108.0)
    hudCanvas.add_child(_abilityStatusLabel)

    _controlsContainer = HBoxContainer.new()
    _controlsContainer.position = Vector2(8.0, 36.0)
    _controlsContainer.add_theme_constant_override("separation", 8)
    hudCanvas.add_child(_controlsContainer)

    _speedButton = Button.new()
    _speedButton.pressed.connect(_incrementSimulationRate)
    _controlsContainer.add_child(_speedButton)

    _addAbilityButton("Subway Station (S)", "Subway Station")
    _addAbilityButton("Add Subway (V)", "Add Subway")

    get_viewport().size_changed.connect(queue_redraw)
    get_viewport().size_changed.connect(_hudNode.queue_redraw)

    _generateCity()
    _updateSpeedButton()
    queue_redraw()
    _hudNode.queue_redraw()


func _generateCity() -> void:
    _city = _generator.generate()
    _traffic = Traffic.new()
    _subwaySystem = SubwaySystem.new()
    _subwaySystem.init(_city)
    _traffic.init(_city, _subwaySystem)
    _cityLayer.setup(_city)
    _trafficLayer.setup(_traffic, _city, _subwaySystem)
    _trafficLayer.paused = _paused
    _trafficLayer.simulationRate = _simulationRate
    _debugger = TrafficDebugger.new()
    _debugger.init(_traffic)
    _abilityManager = AbilityManager.new()
    _abilityManager.init(_city, _subwaySystem, _traffic)
    _subwayConnectionDragActive = false
    _subwayConnectionDragSourceIndex = -1
    _updateAbilityStatus()
    _applyViewMode()
    _updateLayerTransforms()


func _incrementSimulationRate() -> void:
    if _simulationRate >= SimulationRateMax:
        _simulationRate = SimulationRateNormal
    else:
        _simulationRate *= 2
    _trafficLayer.simulationRate = _simulationRate
    _updateSpeedButton()
    _hudNode.queue_redraw()


func _updateSpeedButton() -> void:
    _speedButton.text = "Speed x%d (F)" % _simulationRate


func _toggleHeatmapView() -> void:
    _heatmapVisible = not _heatmapVisible
    _applyViewMode()
    _refreshCommuteVisualization()


func _applyViewMode() -> void:
    var nextCityLayerMode: int = CityLayer.ViewModeCommuteHeatmap \
            if _heatmapVisible else CityLayer.ViewModeLandUse
    _cityLayer.setViewMode(nextCityLayerMode)
    _trafficLayer.setShowTrafficOverlay(not _heatmapVisible)


func _refreshCommuteVisualization() -> void:
    _cityLayer.queue_redraw()
    _hudNode.queue_redraw()


func _addAbilityButton(buttonText: String, abilityName: String) -> void:
    var button := Button.new()
    button.text = buttonText
    button.pressed.connect(_activateAbilityByName.bind(abilityName))
    _controlsContainer.add_child(button)
    _abilityButtons.append(button)


func _activateAbilityByName(abilityName: String) -> void:
    if _abilityManager == null:
        return
    _abilityManager.selectAbilityByName(abilityName)
    if _abilityManager.selectedAbility != null \
            and _abilityManager.selectedAbility.appliesImmediately:
        _abilityManager.applySelectedAtTile(City.NoTile)
        _abilityManager.selectedAbility = null
    _updateAbilityStatus()
    _trafficLayer.queue_redraw()


func _updateAbilityStatus() -> void:
    if _abilityManager == null or _abilityManager.selectedAbility == null:
        _abilityStatusLabel.text = ""
        if _trafficLayer != null:
            _trafficLayer.clearSubwayStationPreview()
            _trafficLayer.clearSubwayConnectionPreview()
        return
    _abilityStatusLabel.text = "Placing: %s" % _abilityManager.selectedAbility.displayName
    _updatePlacementPreview()


func _getMouseWorldPosition() -> Vector2:
    return (get_viewport().get_mouse_position() - _pan) / _zoom


func _updatePlacementPreview() -> void:
    if _abilityManager == null or _trafficLayer == null:
        return
    if _abilityManager.selectedAbility == null:
        _trafficLayer.clearSubwayStationPreview()
        return
    if _subwayConnectionDragActive:
        _trafficLayer.clearSubwayStationPreview()
        return
    var preview: SubwaySystem.SubwayStationPlacement = (
            _abilityManager.getSubwayStationPlacementPreview(_getMouseWorldPosition()))
    if preview == null:
        _trafficLayer.clearSubwayStationPreview()
        return
    _trafficLayer.setSubwayStationPreview(preview.worldPosition, preview.isValid)


func _handleSubwayStationPressed(worldPosition: Vector2) -> void:
    var sourceStationIndex: int = _subwaySystem.getSubwayStationIndexAtWorldPosition(worldPosition)
    if sourceStationIndex >= 0:
        if _subwaySystem.canConnectFromStation(sourceStationIndex):
            _startSubwayConnectionDrag(sourceStationIndex, worldPosition)
        return
    if _abilityManager.applySelectedAtWorldPosition(worldPosition):
        _trafficLayer.queue_redraw()
        _refreshCommuteVisualization()
    _updateAbilityStatus()


func _tryStartSubwayConnectionDrag(worldPosition: Vector2) -> bool:
    var sourceStationIndex: int = _subwaySystem.getSubwayStationIndexAtWorldPosition(worldPosition)
    if sourceStationIndex < 0:
        return false
    if not _subwaySystem.canConnectFromStation(sourceStationIndex):
        return false
    _startSubwayConnectionDrag(sourceStationIndex, worldPosition)
    return true


func _startSubwayConnectionDrag(sourceStationIndex: int, worldPosition: Vector2) -> void:
    _subwayConnectionDragActive = true
    _subwayConnectionDragSourceIndex = sourceStationIndex
    _trafficLayer.clearSubwayStationPreview()
    _updateSubwayConnectionPreview(worldPosition)


func _updateSubwayConnectionPreview(worldPosition: Vector2) -> void:
    if not _subwayConnectionDragActive:
        return
    var placement: SubwaySystem.SubwayStationPlacement = _subwaySystem.getSubwayStationPlacement(
            _city, worldPosition)
    var isValid: bool = _canFinishSubwayConnection(worldPosition, placement)
    var previewPosition: Vector2 = _getSubwayConnectionPreviewPosition(worldPosition, placement)
    _trafficLayer.setSubwayConnectionPreview(
            _subwayConnectionDragSourceIndex, previewPosition, isValid)


func _finishSubwayConnectionDrag(worldPosition: Vector2) -> void:
    var placement: SubwaySystem.SubwayStationPlacement = _subwaySystem.getSubwayStationPlacement(
            _city, worldPosition)
    var didConnect: bool = false
    if _canFinishSubwayConnection(worldPosition, placement):
        var targetStationIndex: int = (
                _subwaySystem.getSubwayStationIndexAtWorldPosition(worldPosition))
        if targetStationIndex >= 0:
            didConnect = _subwaySystem.connectSubwayStations(
                    _subwayConnectionDragSourceIndex, targetStationIndex)
        else:
            var station: RefCounted = _subwaySystem.addConnectedSubwayStation(
                    _city, _subwayConnectionDragSourceIndex, placement.worldPosition)
            didConnect = station != null
    if didConnect:
        _traffic.refreshTransitImpacts()
        _refreshCommuteVisualization()
    _subwayConnectionDragActive = false
    _subwayConnectionDragSourceIndex = -1
    _trafficLayer.clearSubwayConnectionPreview()
    _trafficLayer.queue_redraw()
    _updateAbilityStatus()


func _canFinishSubwayConnection(worldPosition: Vector2,
        placement: SubwaySystem.SubwayStationPlacement) -> bool:
    if not placement.isValid:
        return false
    if not _subwaySystem.canConnectFromStation(_subwayConnectionDragSourceIndex):
        return false
    var targetStationIndex: int = _subwaySystem.getSubwayStationIndexAtWorldPosition(worldPosition)
    if targetStationIndex >= 0:
        return _subwaySystem.canConnectStations(
                _subwayConnectionDragSourceIndex, targetStationIndex)
    var sourceStation: SubwaySystem.SubwayStation = (
            _subwaySystem.subwayStations[_subwayConnectionDragSourceIndex])
    var minimumDistanceSquared: float = SubwaySystem.StationHitRadius \
            * SubwaySystem.StationHitRadius
    return sourceStation.worldPosition.distance_squared_to(worldPosition) > minimumDistanceSquared


func _getSubwayConnectionPreviewPosition(worldPosition: Vector2,
        placement: SubwaySystem.SubwayStationPlacement) -> Vector2:
    var targetStationIndex: int = _subwaySystem.getSubwayStationIndexAtWorldPosition(worldPosition)
    if targetStationIndex >= 0:
        return _subwaySystem.subwayStations[targetStationIndex].worldPosition
    return placement.worldPosition


func _updateLayerTransforms() -> void:
    _cityLayer.position = _pan
    _cityLayer.scale = Vector2(_zoom, _zoom)
    _trafficLayer.position = _pan
    _trafficLayer.scale = Vector2(_zoom, _zoom)


func _getTransportDistributionText() -> String:
    var distribution: Dictionary = _city.getOverallTransportDistribution()
    return "Transport modes: Cars %.0f%%  Subway %.0f%%  Bikes %.0f%%  Walking %.0f%%" % [
        distribution.get(City.TransportCar, 0.0) * 100.0,
        distribution.get(City.TransportSubway, 0.0) * 100.0,
        distribution.get(City.TransportBike, 0.0) * 100.0,
        distribution.get(City.TransportWalk, 0.0) * 100.0,
    ]


func _updateHoverTileLabel() -> void:
    var viewportSize: Vector2 = get_viewport_rect().size
    _hoverTileLabel.position = Vector2(8.0, viewportSize.y - 58.0)
    if _city == null:
        _hoverTileLabel.text = ""
        return
    var worldPos: Vector2 = _getMouseWorldPosition()
    var tile: Vector2i = _city.getTileAtWorldPosition(worldPos)
    if tile == City.NoTile:
        _hoverTileLabel.text = ""
        return
    var profile: City.TileCommuteProfile = _city.getCommuteProfile(tile.x, tile.y)
    if profile == null:
        _hoverTileLabel.text = ""
        return
    var distribution: Dictionary = profile.transportDistribution
    _hoverTileLabel.text = (
        "Tile commute: %.1f / 10  Cars %.0f%%  Subway %.0f%%  Bikes %.0f%%  Walking %.0f%%\n"
        + "Population: %d  Avg commute: %.1f min"
    ) % [
        City.getTileCommuteHappiness(profile),
        distribution.get(City.TransportCar, 0.0) * 100.0,
        distribution.get(City.TransportSubway, 0.0) * 100.0,
        distribution.get(City.TransportBike, 0.0) * 100.0,
        distribution.get(City.TransportWalk, 0.0) * 100.0,
        profile.population,
        City.getTileAverageCommuteMinutes(profile),
    ]


func _process(_delta: float) -> void:
    _fpsLabel.text = "FPS: %d" % Engine.get_frames_per_second()
    if _traffic != null:
        _commuteLabel.text = "Commute happiness: %.1f / 10" % _traffic.getCommuteHappiness()
    if _city != null:
        _transportDistributionLabel.text = _getTransportDistributionText()
    _updateHoverTileLabel()
    _updatePlacementPreview()
    var shiftNow: bool = Input.is_key_pressed(KEY_SHIFT)
    if shiftNow != _debugShiftHeld:
        _debugShiftHeld = shiftNow
        _hudNode.queue_redraw()
    if _debugShiftHeld:
        var mouseScreen: Vector2 = get_viewport().get_mouse_position()
        if mouseScreen != _debugMouseScreenPos:
            _debugMouseScreenPos = mouseScreen
            _hudNode.queue_redraw()
    if _heatmapVisible and not _paused and _cityLayer != null and _city != null:
        _cityLayer.queue_redraw()


func _input(event: InputEvent) -> void:
    if event is InputEventMouseButton:
        if _controlsContainer.get_global_rect().has_point(event.position):
            return
        match event.button_index:
            MOUSE_BUTTON_LEFT:
                if event.pressed and event.shift_pressed:
                    var worldPos: Vector2 = (event.position - _pan) / _zoom
                    _debugger.debugCarsNear(worldPos, _debugRadius)
                elif event.pressed and _abilityManager != null \
                        and _abilityManager.selectedAbility != null:
                    var worldPos: Vector2 = (event.position - _pan) / _zoom
                    _handleSubwayStationPressed(worldPos)
                elif not event.pressed and _subwayConnectionDragActive:
                    var worldPos: Vector2 = (event.position - _pan) / _zoom
                    _finishSubwayConnectionDrag(worldPos)
                elif event.pressed:
                    var worldPos: Vector2 = (event.position - _pan) / _zoom
                    if not _tryStartSubwayConnectionDrag(worldPos):
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
                    _adjustDebugRadius(-1.0)
                else:
                    _zoomBySteps(event.position, 1.0)
            MOUSE_BUTTON_WHEEL_DOWN:
                if event.shift_pressed:
                    _adjustDebugRadius(1.0)
                else:
                    _zoomBySteps(event.position, -1.0)
    elif event is InputEventMouseMotion:
        _debugMouseScreenPos = event.position
        if _debugShiftHeld:
            _hudNode.queue_redraw()
        if _subwayConnectionDragActive:
            var worldPos: Vector2 = (event.position - _pan) / _zoom
            _updateSubwayConnectionPreview(worldPos)
        elif _dragging:
            _pan = _panOrigin + (event.position - _dragOrigin)
            _updateLayerTransforms()
    elif event is InputEventPanGesture:
        var mouseScreenPos: Vector2 = get_viewport().get_mouse_position()
        if _controlsContainer.get_global_rect().has_point(mouseScreenPos):
            return
        if absf(event.delta.y) <= absf(event.delta.x):
            return
        var scrollSteps: float = -event.delta.y / TrackpadScrollPixelsPerStep
        if event.shift_pressed:
            _adjustDebugRadius(scrollSteps)
        else:
            _zoomBySteps(mouseScreenPos, scrollSteps)
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
            KEY_H:
                _toggleHeatmapView()
            _:
                if _abilityManager != null and _abilityManager.selectAbilityByHotkey(event.keycode):
                    if _abilityManager.selectedAbility != null \
                            and _abilityManager.selectedAbility.appliesImmediately:
                        _abilityManager.applySelectedAtTile(City.NoTile)
                        _abilityManager.selectedAbility = null
                    _updateAbilityStatus()
                    _trafficLayer.queue_redraw()


func _zoomBySteps(screenPos: Vector2, zoomSteps: float) -> void:
    if is_zero_approx(zoomSteps):
        return
    _zoomAt(screenPos, pow(ZoomStepFactor, zoomSteps))


func _adjustDebugRadius(radiusSteps: float) -> void:
    if is_zero_approx(radiusSteps):
        return
    _debugRadius = clamp(_debugRadius * pow(ZoomStepFactor, radiusSteps), 5.0, 500.0)
    _hudNode.queue_redraw()


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
    const LegendWidth: float = 220.0
    const ItemHeight: float = 26.0
    const Pad: float = 6.0
    const SwatchW: float = 18.0
    const SwatchH: float = 18.0
    const FontSize: int = 14

    var items: Array = _getLegendItems()
    var legendTitle: String = "Commute Heatmap (H)" if _heatmapVisible else "Land Use"

    var vpSize: Vector2 = get_viewport_rect().size
    var panelHeight: float = items.size() * ItemHeight + Pad * 2 + 24.0
    var legendX: float = vpSize.x - LegendWidth - 12.0
    var legendY: float = vpSize.y - panelHeight - 12.0

    _hudNode.draw_rect(
        Rect2(legendX - Pad, legendY - Pad,
                LegendWidth + Pad * 2, panelHeight + Pad * 2),
        Color(0.0, 0.0, 0.0, 0.60))
    if _font:
        _hudNode.draw_string(
                _font,
                Vector2(legendX, legendY + 14.0),
                legendTitle,
                HORIZONTAL_ALIGNMENT_LEFT,
                -1,
                FontSize,
                Color.WHITE)

    for i in items.size():
        var itemY: float = legendY + 24.0 + i * ItemHeight
        _hudNode.draw_rect(Rect2(legendX, itemY, SwatchW, SwatchH), items[i]["c"])
        _hudNode.draw_rect(Rect2(legendX, itemY, SwatchW, SwatchH), Color(1, 1, 1, 0.25), false)
        if _font:
            _hudNode.draw_string(_font,
                Vector2(legendX + SwatchW + 8.0, itemY + SwatchH - 3.0),
                items[i]["lbl"],
                HORIZONTAL_ALIGNMENT_LEFT, -1, FontSize,
                Color.WHITE)


func _getLegendItems() -> Array:
    if _heatmapVisible:
        return [
            {"c": CityLayer.HeatmapLowColor, "lbl": "Low commute happiness"},
            {"c": CityLayer.HeatmapMidColor, "lbl": "Mid commute happiness"},
            {"c": CityLayer.HeatmapHighColor, "lbl": "High commute happiness"},
            {
                "c": City.CCom[0].lerp(City.CStreet, CityLayer.HeatmapLandUseMix),
                "lbl": "Non-residential land use",
            },
        ]
    return [
        {"c": City.CPark, "lbl": "Park"},
        {"c": City.CRes[0], "lbl": "Residential"},
        {"c": City.CRes[2], "lbl": "Medium Residential"},
        {"c": City.CRes[3], "lbl": "High-rise Residential"},
        {"c": City.CCom[0], "lbl": "Commercial"},
        {"c": City.CInd[1], "lbl": "Office/Industry"},
    ]


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
