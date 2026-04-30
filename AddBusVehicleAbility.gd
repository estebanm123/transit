class_name AddBusVehicleAbility extends TransportAbility


func _init() -> void:
	displayName = "Add Bus"
	hotkey = KEY_V
	requiresTile = false


func applyAtTile(city: City, transitSystem: TransitSystem, _traffic: Traffic,
		_tile: Vector2i) -> bool:
	return transitSystem.addBusVehicle(city) != null
