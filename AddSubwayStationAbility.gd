class_name AddSubwayStationAbility extends TransportAbility


func _init() -> void:
	displayName = "Subway Station"
	hotkey = KEY_S
	requiresTile = false
	clearsAfterApply = false


func canApplyAtWorldPosition(city: City, subwaySystem: SubwaySystem,
		worldPosition: Vector2) -> bool:
	return subwaySystem.getSubwayStationPlacement(city, worldPosition).isValid


func applyAtWorldPosition(city: City, subwaySystem: SubwaySystem, traffic: Traffic,
		worldPosition: Vector2) -> bool:
	var station: RefCounted = subwaySystem.addSubwayStation(city, worldPosition)
	if station == null:
		return false
	traffic.refreshTransitImpacts()
	return true


func getSubwayStationPlacementPreview(city: City, subwaySystem: SubwaySystem,
		worldPosition: Vector2) -> SubwaySystem.SubwayStationPlacement:
	return subwaySystem.getSubwayStationPlacement(city, worldPosition)
