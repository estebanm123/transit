class_name TrafficLayer extends Node2D

var _traffic: Traffic
var _city: City
var _transitSystem: TransitSystem
var paused: bool = false
var simulationRate: int = 1


func setup(traffic: Traffic, city: City, transitSystem: TransitSystem) -> void:
    _traffic = traffic
    _city = city
    _transitSystem = transitSystem


func _process(delta: float) -> void:
    if _traffic == null or paused:
        return
    for _i in range(simulationRate):
        _traffic.tick(_city, delta)
        if _transitSystem != null:
            _transitSystem.tick(_city, delta)
    queue_redraw()


func _draw() -> void:
    if _traffic == null or _city == null:
        return
    _traffic.drawCars(self)
    if _transitSystem != null:
        _transitSystem.drawTransit(self, _city)
