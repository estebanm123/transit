class_name TransportAbility extends RefCounted

var displayName: String = ""
var hotkey: int = KEY_NONE
var requiresTile: bool = true
var appliesImmediately: bool = false
var clearsAfterApply: bool = true


func canApplyAtTile(city: City, tile: Vector2i) -> bool:
	if not requiresTile:
		return true
	if tile == City.NoTile:
		return false
	if tile.x < 0 or tile.x >= City.Cols or tile.y < 0 or tile.y >= City.Rows:
		return false
	return city.zones[tile.y][tile.x] != Zone.Empty


func canApplyAtWorldPosition(city: City, _subwaySystem: SubwaySystem,
		worldPosition: Vector2) -> bool:
	var tile: Vector2i = city.getTileAtWorldPosition(worldPosition)
	return canApplyAtTile(city, tile)


func applyAtTile(_city: City, _subwaySystem: SubwaySystem, _traffic: Traffic,
		_tile: Vector2i) -> bool:
	return false


func applyAtWorldPosition(city: City, subwaySystem: SubwaySystem, traffic: Traffic,
		worldPosition: Vector2) -> bool:
	var tile: Vector2i = city.getTileAtWorldPosition(worldPosition)
	return applyAtTile(city, subwaySystem, traffic, tile)


func getSubwayStationPlacementPreview(_city: City, _subwaySystem: SubwaySystem,
		_worldPosition: Vector2) -> SubwaySystem.SubwayStationPlacement:
	return null
