class_name AbilityManager extends RefCounted

var abilities: Array[TransportAbility] = []
var selectedAbility: TransportAbility = null

var _city: City
var _transitSystem: TransitSystem
var _traffic: Traffic


func init(city: City, transitSystem: TransitSystem, traffic: Traffic) -> void:
	_city = city
	_transitSystem = transitSystem
	_traffic = traffic
	abilities = [
		AddBusStationAbility.new(),
		CreateBusLineAbility.new(),
		AddBusVehicleAbility.new(),
	]
	selectedAbility = null


func selectAbilityByName(displayName: String) -> void:
	for ability: TransportAbility in abilities:
		if ability.displayName == displayName:
			selectedAbility = ability
			return


func selectAbilityByHotkey(keycode: int) -> bool:
	for ability: TransportAbility in abilities:
		if ability.hotkey == keycode:
			selectedAbility = ability
			return true
	return false


func applySelectedAtTile(tile: Vector2i) -> bool:
	if selectedAbility == null:
		return false
	if not selectedAbility.canApplyAtTile(_city, tile):
		return false
	var didApply: bool = selectedAbility.applyAtTile(_city, _transitSystem, _traffic, tile)
	if didApply and selectedAbility.requiresTile:
		selectedAbility = null
	return didApply
