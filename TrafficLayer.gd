class_name TrafficLayer extends Node2D

var _traffic: Traffic
var _city: City
var _subwaySystem: SubwaySystem
var paused: bool = false
var simulationRate: int = 1
var _subwayStationPreviewVisible: bool = false
var _subwayStationPreviewValid: bool = false
var _subwayStationPreviewPosition: Vector2 = Vector2.ZERO
var _subwayConnectionPreviewVisible: bool = false
var _subwayConnectionPreviewValid: bool = false
var _subwayConnectionPreviewSourceIndex: int = -1
var _subwayConnectionPreviewPosition: Vector2 = Vector2.ZERO
var showTrafficOverlay: bool = true


func setup(traffic: Traffic, city: City, subwaySystem: SubwaySystem) -> void:
    _traffic = traffic
    _city = city
    _subwaySystem = subwaySystem


func setSubwayStationPreview(worldPosition: Vector2, isValid: bool) -> void:
    _subwayStationPreviewVisible = true
    _subwayStationPreviewValid = isValid
    _subwayStationPreviewPosition = worldPosition
    queue_redraw()


func clearSubwayStationPreview() -> void:
    if not _subwayStationPreviewVisible:
        return
    _subwayStationPreviewVisible = false
    queue_redraw()


func setSubwayConnectionPreview(sourceStationIndex: int, worldPosition: Vector2,
        isValid: bool) -> void:
    _subwayConnectionPreviewVisible = true
    _subwayConnectionPreviewSourceIndex = sourceStationIndex
    _subwayConnectionPreviewPosition = worldPosition
    _subwayConnectionPreviewValid = isValid
    queue_redraw()


func clearSubwayConnectionPreview() -> void:
    if not _subwayConnectionPreviewVisible:
        return
    _subwayConnectionPreviewVisible = false
    queue_redraw()


func setShowTrafficOverlay(nextShowTrafficOverlay: bool) -> void:
    if showTrafficOverlay == nextShowTrafficOverlay:
        return
    showTrafficOverlay = nextShowTrafficOverlay
    queue_redraw()


func _process(delta: float) -> void:
    if _traffic == null or paused:
        return
    for _i in range(simulationRate):
        _traffic.tick(_city, delta)
        if _subwaySystem != null:
            _subwaySystem.tick(_city, delta)
    queue_redraw()


func _draw() -> void:
    if _traffic == null or _city == null:
        return
    if not showTrafficOverlay:
        return
    _traffic.drawCars(self)
    if _subwaySystem != null:
        _subwaySystem.drawSubway(self, _city)
        if _subwayStationPreviewVisible:
            _subwaySystem.drawSubwayStationPlacementPreview(
                    self, _subwayStationPreviewPosition, _subwayStationPreviewValid)
        if _subwayConnectionPreviewVisible:
            _subwaySystem.drawSubwayConnectionPreview(
                    self,
                    _subwayConnectionPreviewSourceIndex,
                    _subwayConnectionPreviewPosition,
                    _subwayConnectionPreviewValid)
