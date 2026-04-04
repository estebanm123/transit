class_name TrafficLayer extends Node2D

var _traffic: Traffic
var _city: City


func setup(traffic: Traffic, city: City) -> void:
	_traffic = traffic
	_city = city


func _process(delta: float) -> void:
	if _traffic == null:
		return
	_traffic.tick(_city, delta)
	queue_redraw()


func _draw() -> void:
	if _traffic == null or _city == null:
		return
	_traffic.drawCars(self)
