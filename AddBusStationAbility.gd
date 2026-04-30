class_name AddBusStationAbility extends TransportAbility


func _init() -> void:
	displayName = "Bus Station"
	hotkey = KEY_B
	requiresTile = true


func applyAtTile(city: City, transitSystem: TransitSystem, traffic: Traffic,
		tile: Vector2i) -> bool:
	var station: RefCounted = transitSystem.addBusStation(city, tile, false)
	if station == null:
		return false
	traffic.refreshTransitImpacts()
	return true
