class_name Traffic extends RefCounted

const CarCount: int = 200
const CarSpeedMin: float = 25.0
const CarSpeedMax: float = 55.0
const CarLength: float = 3.5
const CarWidth: float = 1.8

const CarColors: Array = [
	Color("#d8d8d8"),
	Color("#f0c040"),
	Color("#e05828"),
	Color("#3898d8"),
	Color("#58c058"),
	Color("#c858c8"),
]

var _cars: Array = []
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


func init(city: City) -> void:
	_rng.seed = 99991
	_cars.clear()
	var attempts: int = 0
	while _cars.size() < CarCount and attempts < CarCount * 30:
		attempts += 1
		var car: Dictionary = _spawnCar(city)
		if not car.is_empty():
			_cars.append(car)


func tick(city: City, delta: float) -> void:
	for car in _cars:
		_advanceCar(city, car, delta)


func drawCars(canvas: Node2D, city: City) -> void:
	for car in _cars:
		var segStart := Vector2(
				_vertStreetCenterX(city, car.fromVertStreet),
				_horzStreetCenterY(city, car.fromHorzStreet))
		var segEnd := Vector2(
				_vertStreetCenterX(city, car.toVertStreet),
				_horzStreetCenterY(city, car.toHorzStreet))
		var center: Vector2 = segStart.lerp(segEnd, car.t) + car.laneOffset
		var forward: Vector2 = car.forward
		var sideways: Vector2 = Vector2(-forward.y, forward.x)
		canvas.draw_colored_polygon(PackedVector2Array([
			center + forward * (CarLength * 0.5) + sideways * (CarWidth * 0.5),
			center + forward * (CarLength * 0.5) - sideways * (CarWidth * 0.5),
			center - forward * (CarLength * 0.5) - sideways * (CarWidth * 0.5),
			center - forward * (CarLength * 0.5) + sideways * (CarWidth * 0.5),
		]), car.color)


# X position of the center of vertical street vertStreetIdx (0..Cols).
func _vertStreetCenterX(city: City, vertStreetIdx: int) -> float:
	if vertStreetIdx < City.Cols:
		return city._colXPositions[vertStreetIdx] - city.vertStreetWidths[vertStreetIdx] * 0.5
	return city._colXPositions[City.Cols - 1] + city._colWidths[City.Cols - 1] \
			+ city.vertStreetWidths[City.Cols] * 0.5


# Y position of the center of horizontal street horzStreetIdx (0..Rows).
func _horzStreetCenterY(city: City, horzStreetIdx: int) -> float:
	if horzStreetIdx < City.Rows:
		return city._rowYPositions[horzStreetIdx] - city.horzStreetWidths[horzStreetIdx] * 0.5
	return city._rowYPositions[City.Rows - 1] + city._rowHeights[City.Rows - 1] \
			+ city.horzStreetWidths[City.Rows] * 0.5


# Is the horizontal segment from intersection (vertStreetIdx, horzStreetIdx)
# to (vertStreetIdx+1, horzStreetIdx) passable?
func _horzSegmentUsable(city: City, vertStreetIdx: int, horzStreetIdx: int) -> bool:
	if vertStreetIdx < 0 or vertStreetIdx >= City.Cols \
			or horzStreetIdx < 0 or horzStreetIdx > City.Rows:
		return false
	if city.horzStreetWidths[horzStreetIdx] < 0.5:
		return false
	var hasBlockAbove: bool = horzStreetIdx > 0 \
			and city.zones[horzStreetIdx - 1][vertStreetIdx] != Zone.Empty
	var hasBlockBelow: bool = horzStreetIdx < City.Rows \
			and city.zones[horzStreetIdx][vertStreetIdx] != Zone.Empty
	if not hasBlockAbove and not hasBlockBelow:
		return false
	if horzStreetIdx == 0 or horzStreetIdx == City.Rows:
		return true
	return city.parcelOwner[horzStreetIdx - 1][vertStreetIdx] \
			!= city.parcelOwner[horzStreetIdx][vertStreetIdx]


# Is the vertical segment from intersection (vertStreetIdx, horzStreetIdx)
# to (vertStreetIdx, horzStreetIdx+1) passable?
func _vertSegmentUsable(city: City, vertStreetIdx: int, horzStreetIdx: int) -> bool:
	if vertStreetIdx < 0 or vertStreetIdx > City.Cols \
			or horzStreetIdx < 0 or horzStreetIdx >= City.Rows:
		return false
	if city.vertStreetWidths[vertStreetIdx] < 0.5:
		return false
	var hasBlockLeft: bool = vertStreetIdx > 0 \
			and city.zones[horzStreetIdx][vertStreetIdx - 1] != Zone.Empty
	var hasBlockRight: bool = vertStreetIdx < City.Cols \
			and city.zones[horzStreetIdx][vertStreetIdx] != Zone.Empty
	if not hasBlockLeft and not hasBlockRight:
		return false
	if vertStreetIdx == 0 or vertStreetIdx == City.Cols:
		return true
	return city.parcelOwner[horzStreetIdx][vertStreetIdx - 1] \
			!= city.parcelOwner[horzStreetIdx][vertStreetIdx]


func _calcLaneOffset(forward: Vector2, streetWidth: float) -> Vector2:
	return Vector2(-forward.y, forward.x) * streetWidth * 0.22


func _spawnCar(city: City) -> Dictionary:
	var isHorizontalSegment: bool = _rng.randf() < 0.5
	var fromVertStreet: int
	var fromHorzStreet: int
	var toVertStreet: int
	var toHorzStreet: int

	if isHorizontalSegment:
		fromVertStreet = _rng.randi_range(0, City.Cols - 1)
		fromHorzStreet = _rng.randi_range(0, City.Rows)
		if not _horzSegmentUsable(city, fromVertStreet, fromHorzStreet):
			return {}
		toVertStreet = fromVertStreet + 1
		toHorzStreet = fromHorzStreet
	else:
		fromVertStreet = _rng.randi_range(0, City.Cols)
		fromHorzStreet = _rng.randi_range(0, City.Rows - 1)
		if not _vertSegmentUsable(city, fromVertStreet, fromHorzStreet):
			return {}
		toVertStreet = fromVertStreet
		toHorzStreet = fromHorzStreet + 1

	var segStart := Vector2(
			_vertStreetCenterX(city, fromVertStreet),
			_horzStreetCenterY(city, fromHorzStreet))
	var segEnd := Vector2(
			_vertStreetCenterX(city, toVertStreet),
			_horzStreetCenterY(city, toHorzStreet))
	var segLength: float = segStart.distance_to(segEnd)
	if segLength < 0.5:
		return {}

	var forward: Vector2 = (segEnd - segStart) / segLength
	var streetWidth: float = city.horzStreetWidths[fromHorzStreet] \
			if isHorizontalSegment else city.vertStreetWidths[fromVertStreet]

	return {
		"fromVertStreet": fromVertStreet,
		"fromHorzStreet": fromHorzStreet,
		"toVertStreet": toVertStreet,
		"toHorzStreet": toHorzStreet,
		"t": _rng.randf(),
		"speed": _rng.randf_range(CarSpeedMin, CarSpeedMax),
		"segLength": segLength,
		"forward": forward,
		"laneOffset": _calcLaneOffset(forward, streetWidth),
		"color": CarColors[_rng.randi() % CarColors.size()],
	}


func _advanceCar(city: City, car: Dictionary, delta: float) -> void:
	car.t += car.speed * delta / car.segLength
	if car.t < 1.0:
		return

	var overflow: float = car.t - 1.0
	var arrivedVertStreet: int = car.toVertStreet
	var arrivedHorzStreet: int = car.toHorzStreet

	var neighbors: Array = _getExitSegments(
			city, arrivedVertStreet, arrivedHorzStreet,
			car.fromVertStreet, car.fromHorzStreet)
	var nextToVertStreet: int
	var nextToHorzStreet: int
	if neighbors.is_empty():
		nextToVertStreet = car.fromVertStreet
		nextToHorzStreet = car.fromHorzStreet
	else:
		var chosen: Array = neighbors[_rng.randi() % neighbors.size()]
		nextToVertStreet = chosen[0]
		nextToHorzStreet = chosen[1]

	car.fromVertStreet = arrivedVertStreet
	car.fromHorzStreet = arrivedHorzStreet
	car.toVertStreet = nextToVertStreet
	car.toHorzStreet = nextToHorzStreet

	var segStart := Vector2(
			_vertStreetCenterX(city, arrivedVertStreet),
			_horzStreetCenterY(city, arrivedHorzStreet))
	var segEnd := Vector2(
			_vertStreetCenterX(city, nextToVertStreet),
			_horzStreetCenterY(city, nextToHorzStreet))
	car.segLength = segStart.distance_to(segEnd)
	if car.segLength < 0.5:
		car.segLength = 0.5

	car.forward = (segEnd - segStart) / car.segLength

	var isHorizontalSegment: bool = (nextToHorzStreet == arrivedHorzStreet)
	var streetWidth: float = city.horzStreetWidths[arrivedHorzStreet] \
			if isHorizontalSegment else city.vertStreetWidths[arrivedVertStreet]
	car.laneOffset = _calcLaneOffset(car.forward, streetWidth)

	car.t = overflow / car.segLength


func _getExitSegments(city: City, vertStreetIdx: int, horzStreetIdx: int,
		cameFromVertStreet: int, cameFromHorzStreet: int) -> Array:
	var exits: Array = []
	# East
	if not (cameFromVertStreet == vertStreetIdx + 1 and cameFromHorzStreet == horzStreetIdx) \
			and _horzSegmentUsable(city, vertStreetIdx, horzStreetIdx):
		exits.append([vertStreetIdx + 1, horzStreetIdx])
	# West
	if not (cameFromVertStreet == vertStreetIdx - 1 and cameFromHorzStreet == horzStreetIdx) \
			and _horzSegmentUsable(city, vertStreetIdx - 1, horzStreetIdx):
		exits.append([vertStreetIdx - 1, horzStreetIdx])
	# South
	if not (cameFromVertStreet == vertStreetIdx and cameFromHorzStreet == horzStreetIdx + 1) \
			and _vertSegmentUsable(city, vertStreetIdx, horzStreetIdx):
		exits.append([vertStreetIdx, horzStreetIdx + 1])
	# North
	if not (cameFromVertStreet == vertStreetIdx and cameFromHorzStreet == horzStreetIdx - 1) \
			and _vertSegmentUsable(city, vertStreetIdx, horzStreetIdx - 1):
		exits.append([vertStreetIdx, horzStreetIdx - 1])
	return exits
