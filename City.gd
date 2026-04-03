class_name City extends RefCounted

const MapW: int = 1280
const MapH: int = 720
const Margin: int = 20
const Cols: int = 100
const Rows: int = 60
const StreetW: int = 14

const WArterial: float = 8.0
const WCollector: float = 4.0
const WLocal: float = 1.5

const CCountryside: Color = Color("#1c4d3f")
const CStreet: Color = Color("#323238")

const CPark: Color = Color("#31832f")

const CRes := [
	Color("#1e3a70"),
	Color("#2c6199"),
	Color("#358fb0"),
	Color("#55c6c6"),
]

const CCom := [
	Color("#eb7e17"),
	Color("#fab13c"),
]

const CInd := [
	Color("#323238"),
	Color("#68606b"),
	Color("#9e8b92"),
]

var vertStreetWidths: Array[float] = []
var horzStreetWidths: Array[float] = []
var _colXPositions: Array[float] = []
var _rowYPositions: Array[float] = []
var _colWidths: Array[float] = []
var _rowHeights: Array[float] = []

var zones: Array = []
var colors: Array = []
var details: Array = []
var parcelOwner: Array = []
var parcelExtent: Array = []


func blockRect(col: int, row: int) -> Rect2:
	return Rect2(_colXPositions[col], _rowYPositions[row], _colWidths[col], _rowHeights[row])


func mergedBlockRect(col: int, row: int) -> Rect2:
	var extent: Vector2i = parcelExtent[row][col]
	var x: float = _colXPositions[col]
	var y: float = _rowYPositions[row]
	var w: float = _colXPositions[extent.x] + _colWidths[extent.x] - x
	var h: float = _rowYPositions[extent.y] + _rowHeights[extent.y] - y
	return Rect2(x, y, w, h)
