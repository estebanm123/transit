class_name CreateBusLineAbility extends TransportAbility


func _init() -> void:
	displayName = "New Bus Line"
	hotkey = KEY_N
	requiresTile = true


func applyAtTile(city: City, transitSystem: TransitSystem, traffic: Traffic,
		tile: Vector2i) -> bool:
	var station: RefCounted = transitSystem.addBusStation(city, tile, true)
	if station == null:
		return false
	traffic.refreshTransitImpacts()
	return true
