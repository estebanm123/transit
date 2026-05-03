class_name AddSubwayVehicleAbility extends TransportAbility


func _init() -> void:
	displayName = "Add Subway"
	hotkey = KEY_V
	requiresTile = false
	appliesImmediately = true


func applyAtTile(_city: City, subwaySystem: SubwaySystem, _traffic: Traffic,
		_tile: Vector2i) -> bool:
	return subwaySystem.addSubwayVehicle() != null
