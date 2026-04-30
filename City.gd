class_name City extends RefCounted

const MapW: int = 335 * 7
const MapH: int = 187 * 7
const Margin: int = 8 
const Cols: int = 8 * 15
const Rows: int = 8 * 15

const WArterial: float = 10.1
const WCollector: float = 6.1
const WLocal: float = 3.6

const CCountryside: Color = Palette.CGreenDark
const CStreet: Color = Palette.CGrayDeep

const CPark: Color = Palette.CGreen
const TransportCar: String = "car"
const TransportBus: String = "bus"
const TransportBike: String = "bike"
const TransportWalk: String = "walk"
const TransportModes: Array[String] = [
	TransportCar,
	TransportBus,
	TransportBike,
	TransportWalk,
]
const NoTile: Vector2i = Vector2i(-1, -1)

const CRes: Array[Color] = [
	Palette.CBlueDark,
	Palette.CBlue,
	Palette.CSkyBlue,
	Palette.CCyan,
]

const CCom: Array[Color] = [
	Palette.COrange,
	Palette.CAmber,
]

const CInd: Array[Color] = [
	Palette.CGrayDeep,
	Palette.CGrayDark,
	Palette.CGrayMid,
]


class TileCommuteProfile extends RefCounted:
	var population: int = 0
	var commuteCostByMode: Dictionary = {}
	var baseTransportDistribution: Dictionary = {}
	var transportDistribution: Dictionary = {}
	var transitSuppression: float = 0.0
	var currentCarCommuteMinutes: float = 0.0


var vertStreetWidths: Array[float] = []
var horzStreetWidths: Array[float] = []
var _colXPositions: Array[float] = []
var _rowYPositions: Array[float] = []
var _colWidths: Array[float] = []
var _rowHeights: Array[float] = []

var zones: Array = []
var colors: Array = []
var parcelOwner: Array = []
var parcelExtent: Array = []
var commuteProfiles: Array = []
var totalPopulation: int = 0


func blockRect(col: int, row: int) -> Rect2:
	return Rect2(_colXPositions[col], _rowYPositions[row], _colWidths[col], _rowHeights[row])


func mergedBlockRect(col: int, row: int) -> Rect2:
	var extent: Vector2i = parcelExtent[row][col]
	var x: float = _colXPositions[col]
	var y: float = _rowYPositions[row]
	var w: float = _colXPositions[extent.x] + _colWidths[extent.x] - x
	var h: float = _rowYPositions[extent.y] + _rowHeights[extent.y] - y
	return Rect2(x, y, w, h)


func getCommuteProfile(col: int, row: int) -> TileCommuteProfile:
	if row < 0 or row >= commuteProfiles.size():
		return null
	if col < 0 or col >= commuteProfiles[row].size():
		return null
	return commuteProfiles[row][col]


func getTileAtWorldPosition(worldPos: Vector2) -> Vector2i:
	# Randomized block sizes and variable-width streets make arithmetic grid lookup inexact.
	var col: int = _findBlockAxisIndex(worldPos.x, _colXPositions, _colWidths)
	var row: int = _findBlockAxisIndex(worldPos.y, _rowYPositions, _rowHeights)
	if col < 0 or row < 0:
		return NoTile
	return Vector2i(col, row)


func _findBlockAxisIndex(pos: float, starts: Array[float], sizes: Array[float]) -> int:
	var lo: int = 0
	var hi: int = starts.size() - 1
	while lo <= hi:
		var mid: int = (lo + hi) / 2
		var start: float = starts[mid]
		var end: float = start + sizes[mid]
		if pos < start:
			hi = mid - 1
		elif pos >= end:
			lo = mid + 1
		else:
			return mid
	return -1


func getOverallTransportDistribution() -> Dictionary:
	var totals: Dictionary = {
		TransportCar: 0.0,
		TransportBus: 0.0,
		TransportBike: 0.0,
		TransportWalk: 0.0,
	}
	var tripTotal: float = 0.0
	for row in commuteProfiles:
		for profile: TileCommuteProfile in row:
			if profile == null:
				continue
			var population: float = float(profile.population)
			tripTotal += population
			for mode: String in TransportModes:
				totals[mode] += population * profile.transportDistribution.get(mode, 0.0)
	if tripTotal <= 0.0:
		return totals
	for mode: String in TransportModes:
		totals[mode] /= tripTotal
	return totals
