class_name SubwaySystem extends RefCounted

const SubwayStationRadius: float = 4.0
const SubwayStationPreviewRadius: float = 5.0
const SubwayLineWidth: float = 2.4
const SubwayStationInfluenceRadius: float = 165.0
const SubwayStationMaxSuppression: float = 0.72
const MaxStationConnections: int = 2
const StationHitRadius: float = 7.0
const SubwayVehicleSpeed: float = 35.0
const SubwayVehicleLength: float = 8.0
const SubwayVehicleWidth: float = 3.0

const SubwayLineColor: Color = Palette.CSkyBlue
const SubwayStationColor: Color = Palette.CAmber
const SubwayVehicleColor: Color = Palette.CPinkLight
const SubwayPreviewValidColor: Color = Palette.CGreenBright
const SubwayPreviewInvalidColor: Color = Palette.CRed


class SubwayStation extends RefCounted:
	var worldPosition: Vector2 = Vector2.ZERO
	var connections: Array[int] = []


class SubwayStationPlacement extends RefCounted:
	var isValid: bool = false
	var worldPosition: Vector2 = Vector2.ZERO


class SubwayVehicle extends RefCounted:
	var fromStationIndex: int = -1
	var toStationIndex: int = -1
	var progress: float = 0.0
	var worldPosition: Vector2 = Vector2.ZERO
	var forward: Vector2 = Vector2.RIGHT


var subwayStations: Array[SubwayStation] = []
var subwayVehicles: Array[SubwayVehicle] = []


func init(_city: City) -> void:
	subwayStations.clear()
	subwayVehicles.clear()


func addSubwayStation(city: City, worldPosition: Vector2) -> SubwayStation:
	var placement: SubwayStationPlacement = getSubwayStationPlacement(city, worldPosition)
	if not placement.isValid:
		return null
	var station := SubwayStation.new()
	station.worldPosition = placement.worldPosition
	subwayStations.append(station)
	return station


func addConnectedSubwayStation(city: City, sourceStationIndex: int,
		worldPosition: Vector2) -> SubwayStation:
	if not canConnectFromStation(sourceStationIndex):
		return null
	var station: SubwayStation = addSubwayStation(city, worldPosition)
	if station == null:
		return null
	var targetStationIndex: int = subwayStations.size() - 1
	if not connectSubwayStations(sourceStationIndex, targetStationIndex):
		subwayStations.remove_at(targetStationIndex)
		return null
	return station


func canConnectStations(sourceStationIndex: int, targetStationIndex: int) -> bool:
	if sourceStationIndex == targetStationIndex:
		return false
	if not _isValidStationIndex(sourceStationIndex) or not _isValidStationIndex(targetStationIndex):
		return false
	var sourceStation: SubwayStation = subwayStations[sourceStationIndex]
	var targetStation: SubwayStation = subwayStations[targetStationIndex]
	if sourceStation.connections.has(targetStationIndex):
		return false
	if sourceStation.connections.size() >= MaxStationConnections:
		return false
	if targetStation.connections.size() >= MaxStationConnections:
		return false
	return true


func connectSubwayStations(sourceStationIndex: int, targetStationIndex: int) -> bool:
	if not canConnectStations(sourceStationIndex, targetStationIndex):
		return false
	var sourceStation: SubwayStation = subwayStations[sourceStationIndex]
	var targetStation: SubwayStation = subwayStations[targetStationIndex]
	sourceStation.connections.append(targetStationIndex)
	targetStation.connections.append(sourceStationIndex)
	return true


func addSubwayVehicle() -> SubwayVehicle:
	for stationIndex in subwayStations.size():
		var station: SubwayStation = subwayStations[stationIndex]
		if station.connections.is_empty():
			continue
		var vehicle := SubwayVehicle.new()
		vehicle.fromStationIndex = stationIndex
		vehicle.toStationIndex = station.connections[0]
		vehicle.worldPosition = station.worldPosition
		_updateSubwayVehicleForward(vehicle)
		subwayVehicles.append(vehicle)
		return vehicle
	return null


func canConnectFromStation(stationIndex: int) -> bool:
	if not _isValidStationIndex(stationIndex):
		return false
	return subwayStations[stationIndex].connections.size() < MaxStationConnections


func getSubwayStationPlacement(city: City,
		worldPosition: Vector2) -> SubwayStationPlacement:
	var placement := SubwayStationPlacement.new()
	placement.worldPosition = worldPosition
	placement.isValid = worldPosition.x >= 0.0 and worldPosition.x <= City.MapW \
			and worldPosition.y >= 0.0 and worldPosition.y <= City.MapH
	return placement


func getSubwayStationIndexAtWorldPosition(worldPosition: Vector2) -> int:
	var bestStationIndex: int = -1
	var bestDistance: float = StationHitRadius * StationHitRadius
	for stationIndex in subwayStations.size():
		var station: SubwayStation = subwayStations[stationIndex]
		var distance: float = worldPosition.distance_squared_to(station.worldPosition)
		if distance <= bestDistance:
			bestDistance = distance
			bestStationIndex = stationIndex
	return bestStationIndex


func getSuppressionForTile(city: City, tile: Vector2i) -> float:
	if subwayStations.is_empty():
		return 0.0
	var tileCenter: Vector2 = getTileCenter(city, tile)
	var strongestSuppression: float = 0.0
	for station: SubwayStation in subwayStations:
		var distance: float = tileCenter.distance_to(station.worldPosition)
		if distance > SubwayStationInfluenceRadius:
			continue
		var effect: float = SubwayStationMaxSuppression \
				* (1.0 - distance / SubwayStationInfluenceRadius)
		strongestSuppression = maxf(strongestSuppression, effect)
	return strongestSuppression


func getTileCenter(city: City, tile: Vector2i) -> Vector2:
	var rect: Rect2 = city.blockRect(tile.x, tile.y)
	return rect.position + rect.size * 0.5


func getClosestTileIntersection(city: City, tile: Vector2i) -> Vector2i:
	var center: Vector2 = getTileCenter(city, tile)
	var corners: Array[Vector2i] = [
		Vector2i(tile.x, tile.y),
		Vector2i(tile.x + 1, tile.y),
		Vector2i(tile.x, tile.y + 1),
		Vector2i(tile.x + 1, tile.y + 1),
	]
	var bestCorner: Vector2i = corners[0]
	var bestDistance: float = INF
	for corner: Vector2i in corners:
		var cornerPosition: Vector2 = getIntersectionWorldPosition(city, corner)
		var distance: float = center.distance_squared_to(cornerPosition)
		if distance < bestDistance:
			bestDistance = distance
			bestCorner = corner
	return bestCorner


func getIntersectionWorldPosition(city: City, intersection: Vector2i) -> Vector2:
	return Vector2(
			_getVertStreetCenterX(city, intersection.x),
			_getHorzStreetCenterY(city, intersection.y))


func tick(_city: City, delta: float) -> void:
	for vehicle: SubwayVehicle in subwayVehicles:
		_advanceSubwayVehicle(vehicle, delta)


func drawSubway(canvas: Node2D, _city: City) -> void:
	for stationIndex in subwayStations.size():
		var station: SubwayStation = subwayStations[stationIndex]
		for connectedStationIndex: int in station.connections:
			if connectedStationIndex < stationIndex:
				continue
			var connectedStation: SubwayStation = subwayStations[connectedStationIndex]
			canvas.draw_line(
					station.worldPosition,
					connectedStation.worldPosition,
					SubwayLineColor,
					SubwayLineWidth)
	for station: SubwayStation in subwayStations:
		_drawSubwayStation(canvas, station.worldPosition, SubwayStationColor)
	for vehicle: SubwayVehicle in subwayVehicles:
		_drawSubwayVehicle(canvas, vehicle)


func drawSubwayStationPlacementPreview(canvas: Node2D, worldPosition: Vector2,
		isValid: bool) -> void:
	var previewColor: Color = SubwayPreviewValidColor if isValid else SubwayPreviewInvalidColor
	var fillColor: Color = previewColor
	fillColor.a = 0.35
	canvas.draw_circle(worldPosition, SubwayStationPreviewRadius, fillColor)
	canvas.draw_circle(worldPosition, SubwayStationPreviewRadius, previewColor, false, 1.2)
	_drawSubwayStation(canvas, worldPosition, previewColor)


func drawSubwayConnectionPreview(canvas: Node2D, sourceStationIndex: int,
		targetWorldPosition: Vector2, isValid: bool) -> void:
	if not _isValidStationIndex(sourceStationIndex):
		return
	var previewColor: Color = SubwayPreviewValidColor if isValid else SubwayPreviewInvalidColor
	var sourcePosition: Vector2 = subwayStations[sourceStationIndex].worldPosition
	canvas.draw_line(sourcePosition, targetWorldPosition, previewColor, SubwayLineWidth)
	drawSubwayStationPlacementPreview(canvas, targetWorldPosition, isValid)


func _drawSubwayStation(canvas: Node2D, worldPosition: Vector2, stationColor: Color) -> void:
	canvas.draw_circle(worldPosition, SubwayStationRadius + 1.8, Palette.CNearBlack)
	canvas.draw_circle(worldPosition, SubwayStationRadius, stationColor)
	canvas.draw_circle(worldPosition, SubwayStationRadius, Palette.COffWhite, false, 1.1)
	canvas.draw_circle(worldPosition, SubwayStationRadius * 0.42, Palette.COffWhite)


func _advanceSubwayVehicle(vehicle: SubwayVehicle, delta: float) -> void:
	if not _isValidSubwayVehicle(vehicle):
		return
	var remainingDistance: float = SubwayVehicleSpeed * delta
	while remainingDistance > 0.0 and _isValidSubwayVehicle(vehicle):
		var fromStation: SubwayStation = subwayStations[vehicle.fromStationIndex]
		var toStation: SubwayStation = subwayStations[vehicle.toStationIndex]
		var segmentLength: float = fromStation.worldPosition.distance_to(toStation.worldPosition)
		if segmentLength < 0.5:
			_chooseNextVehicleSegment(vehicle)
			continue
		var segmentRemaining: float = (1.0 - vehicle.progress) * segmentLength
		if remainingDistance < segmentRemaining:
			vehicle.progress += remainingDistance / segmentLength
			remainingDistance = 0.0
		else:
			remainingDistance -= segmentRemaining
			_chooseNextVehicleSegment(vehicle)
	_updateSubwayVehiclePosition(vehicle)


func _chooseNextVehicleSegment(vehicle: SubwayVehicle) -> void:
	var arrivedStationIndex: int = vehicle.toStationIndex
	var previousStationIndex: int = vehicle.fromStationIndex
	if not _isValidStationIndex(arrivedStationIndex):
		return
	var arrivedStation: SubwayStation = subwayStations[arrivedStationIndex]
	var nextStationIndex: int = previousStationIndex
	for connectedStationIndex: int in arrivedStation.connections:
		if connectedStationIndex != previousStationIndex:
			nextStationIndex = connectedStationIndex
			break
	vehicle.fromStationIndex = arrivedStationIndex
	vehicle.toStationIndex = nextStationIndex
	vehicle.progress = 0.0


func _updateSubwayVehiclePosition(vehicle: SubwayVehicle) -> void:
	if not _isValidSubwayVehicle(vehicle):
		return
	var fromPosition: Vector2 = subwayStations[vehicle.fromStationIndex].worldPosition
	var toPosition: Vector2 = subwayStations[vehicle.toStationIndex].worldPosition
	vehicle.worldPosition = fromPosition.lerp(toPosition, vehicle.progress)
	_updateSubwayVehicleForward(vehicle)


func _updateSubwayVehicleForward(vehicle: SubwayVehicle) -> void:
	if not _isValidSubwayVehicle(vehicle):
		return
	var fromPosition: Vector2 = subwayStations[vehicle.fromStationIndex].worldPosition
	var toPosition: Vector2 = subwayStations[vehicle.toStationIndex].worldPosition
	var segmentVector: Vector2 = toPosition - fromPosition
	if segmentVector.length() >= 0.5:
		vehicle.forward = segmentVector.normalized()


func _drawSubwayVehicle(canvas: Node2D, vehicle: SubwayVehicle) -> void:
	if not _isValidSubwayVehicle(vehicle):
		return
	var side: Vector2 = Vector2(-vehicle.forward.y, vehicle.forward.x)
	var halfForward: Vector2 = vehicle.forward * SubwayVehicleLength * 0.5
	var halfSide: Vector2 = side * SubwayVehicleWidth * 0.5
	var points := PackedVector2Array([
		vehicle.worldPosition - halfForward - halfSide,
		vehicle.worldPosition + halfForward - halfSide,
		vehicle.worldPosition + halfForward + halfSide,
		vehicle.worldPosition - halfForward + halfSide,
	])
	canvas.draw_colored_polygon(points, SubwayVehicleColor)
	var outlinePoints := PackedVector2Array(points)
	outlinePoints.append(points[0])
	canvas.draw_polyline(outlinePoints, Palette.COffWhite, 1.0)


func _isValidSubwayVehicle(vehicle: SubwayVehicle) -> bool:
	if not _isValidStationIndex(vehicle.fromStationIndex):
		return false
	if not _isValidStationIndex(vehicle.toStationIndex):
		return false
	return subwayStations[vehicle.fromStationIndex].connections.has(vehicle.toStationIndex)


func _isValidStationIndex(stationIndex: int) -> bool:
	return stationIndex >= 0 and stationIndex < subwayStations.size()


func _getVertStreetCenterX(city: City, vertStreetIndex: int) -> float:
	if vertStreetIndex < City.Cols:
		return city._colXPositions[vertStreetIndex] - city.vertStreetWidths[vertStreetIndex] * 0.5
	return city._colXPositions[City.Cols - 1] + city._colWidths[City.Cols - 1] \
			+ city.vertStreetWidths[City.Cols] * 0.5


func _getHorzStreetCenterY(city: City, horzStreetIndex: int) -> float:
	if horzStreetIndex < City.Rows:
		return city._rowYPositions[horzStreetIndex] - city.horzStreetWidths[horzStreetIndex] * 0.5
	return city._rowYPositions[City.Rows - 1] + city._rowHeights[City.Rows - 1] \
			+ city.horzStreetWidths[City.Rows] * 0.5
