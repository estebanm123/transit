class_name TransportAbility extends RefCounted

var displayName: String = ""
var hotkey: int = KEY_NONE
var requiresTile: bool = true


func canApplyAtTile(city: City, tile: Vector2i) -> bool:
	if not requiresTile:
		return true
	if tile == City.NoTile:
		return false
	if tile.x < 0 or tile.x >= City.Cols or tile.y < 0 or tile.y >= City.Rows:
		return false
	return city.zones[tile.y][tile.x] != Zone.Empty


func applyAtTile(_city: City, _transitSystem: TransitSystem, _traffic: Traffic,
		_tile: Vector2i) -> bool:
	return false
