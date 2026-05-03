class_name AbilityManager extends RefCounted

var abilities: Array[TransportAbility] = []
var selectedAbility: TransportAbility = null

var _city: City
var _subwaySystem: SubwaySystem
var _traffic: Traffic


func init(city: City, subwaySystem: SubwaySystem, traffic: Traffic) -> void:
	_city = city
	_subwaySystem = subwaySystem
	_traffic = traffic
	abilities = [
		AddSubwayStationAbility.new(),
		AddSubwayVehicleAbility.new(),
	]
	selectedAbility = null


func selectAbilityByName(displayName: String) -> void:
	for ability: TransportAbility in abilities:
		if ability.displayName == displayName:
			if selectedAbility == ability and not ability.appliesImmediately:
				selectedAbility = null
				return
			selectedAbility = ability
			return


func selectAbilityByHotkey(keycode: int) -> bool:
	for ability: TransportAbility in abilities:
		if ability.hotkey == keycode:
			if selectedAbility == ability and not ability.appliesImmediately:
				selectedAbility = null
				return true
			selectedAbility = ability
			return true
	return false


func applySelectedAtTile(tile: Vector2i) -> bool:
	if selectedAbility == null:
		return false
	if not selectedAbility.canApplyAtTile(_city, tile):
		return false
	var didApply: bool = selectedAbility.applyAtTile(_city, _subwaySystem, _traffic, tile)
	if didApply and selectedAbility.clearsAfterApply:
		selectedAbility = null
	return didApply


func applySelectedAtWorldPosition(worldPosition: Vector2) -> bool:
	if selectedAbility == null:
		return false
	if not selectedAbility.canApplyAtWorldPosition(_city, _subwaySystem, worldPosition):
		return false
	var didApply: bool = selectedAbility.applyAtWorldPosition(
			_city, _subwaySystem, _traffic, worldPosition)
	if didApply and selectedAbility.clearsAfterApply:
		selectedAbility = null
	return didApply


func getSubwayStationPlacementPreview(
		worldPosition: Vector2) -> SubwaySystem.SubwayStationPlacement:
	if selectedAbility == null:
		return null
	return selectedAbility.getSubwayStationPlacementPreview(_city, _subwaySystem, worldPosition)
