class_name TransitSystem extends RefCounted

const BusStationRadius: float = 5.5
const BusStationInfluenceRadius: float = 150.0
const BusStationMaxSuppression: float = 0.65
const BusLineWidth: float = 3.0
const BusWidth: float = 1.8
const BusLength: float = 7.0
const BusSpeed: float = 42.0

const BusLineColors: Array[Color] = [
	Palette.CSkyBlue,
	Palette.CGreenBright,
	Palette.CPink,
	Palette.CAmber,
]


class BusStation extends RefCounted:
	var tile: Vector2i = City.NoTile
	var intersection: Vector2i = Vector2i.ZERO
	var worldPosition: Vector2 = Vector2.ZERO
	var lineIndex: int = -1


class BusLine extends RefCounted:
	var stations: Array[BusStation] = []
	var color: Color = Palette.CSkyBlue


class BusVehicle extends RefCounted:
	var lineIndex: int = 0
	var routePoints: Array[Vector2] = []
	var routeIndex: int = 0
	var progress: float = 0.0
	var worldPosition: Vector2 = Vector2.ZERO
	var forward: Vector2 = Vector2.RIGHT
	var color: Color = Palette.CSkyBlue


var busStations: Array[BusStation] = []
var busLines: Array[BusLine] = []
var busVehicles: Array[BusVehicle] = []
var activeBusLineIndex: int = -1


func init(_city: City) -> void:
	busStations.clear()
	busLines.clear()
	busVehicles.clear()
	activeBusLineIndex = -1


func createBusLine() -> int:
	var line := BusLine.new()
	line.color = BusLineColors[busLines.size() % BusLineColors.size()]
	busLines.append(line)
	activeBusLineIndex = busLines.size() - 1
	return activeBusLineIndex


func addBusStation(city: City, tile: Vector2i, createNewLine: bool = false) -> BusStation:
	if tile == City.NoTile:
		return null
	if createNewLine or activeBusLineIndex < 0:
		createBusLine()
	var line: BusLine = busLines[activeBusLineIndex]
	var station := BusStation.new()
	station.tile = tile
	station.intersection = getClosestTileIntersection(city, tile)
	station.worldPosition = getIntersectionWorldPosition(city, station.intersection)
	station.lineIndex = activeBusLineIndex
	line.stations.append(station)
	busStations.append(station)
	_refreshBusRoutes(city, activeBusLineIndex)
	return station


func addBusVehicle(city: City, lineIndex: int = -1) -> BusVehicle:
	var resolvedLineIndex: int = activeBusLineIndex if lineIndex < 0 else lineIndex
	if resolvedLineIndex < 0 or resolvedLineIndex >= busLines.size():
		return null
	var routePoints: Array[Vector2] = _buildLineRoutePoints(city, busLines[resolvedLineIndex])
	if routePoints.size() < 2:
		return null
	var bus := BusVehicle.new()
	bus.lineIndex = resolvedLineIndex
	bus.routePoints = routePoints
	bus.color = busLines[resolvedLineIndex].color
	bus.worldPosition = routePoints[0]
	bus.forward = (routePoints[1] - routePoints[0]).normalized()
	busVehicles.append(bus)
	return bus


func tick(_city: City, delta: float) -> void:
	for bus: BusVehicle in busVehicles:
		_advanceBus(bus, delta)


func getSuppressionForTile(city: City, tile: Vector2i) -> float:
	if busStations.is_empty():
		return 0.0
	var tileCenter: Vector2 = getTileCenter(city, tile)
	var strongestSuppression: float = 0.0
	for station: BusStation in busStations:
		var distance: float = tileCenter.distance_to(station.worldPosition)
		if distance > BusStationInfluenceRadius:
			continue
		var effect: float = BusStationMaxSuppression \
				* (1.0 - distance / BusStationInfluenceRadius)
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


func drawTransit(canvas: Node2D, city: City) -> void:
	for lineIndex in busLines.size():
		var line: BusLine = busLines[lineIndex]
		_drawBusLine(canvas, city, line)
	for station: BusStation in busStations:
		canvas.draw_circle(
				station.worldPosition, BusStationRadius + 2.5, Color(0.0, 0.0, 0.0, 0.65))
		canvas.draw_circle(
				station.worldPosition, BusStationRadius, busLines[station.lineIndex].color)
		canvas.draw_circle(station.worldPosition, BusStationRadius, Color.WHITE, false, 1.3)
	for bus: BusVehicle in busVehicles:
		_drawBusVehicle(canvas, bus)


func _advanceBus(bus: BusVehicle, delta: float) -> void:
	if bus.routePoints.size() < 2:
		return
	var remainingDistance: float = BusSpeed * delta
	while remainingDistance > 0.0:
		var fromPoint: Vector2 = bus.routePoints[bus.routeIndex]
		var toPoint: Vector2 = bus.routePoints[(bus.routeIndex + 1) % bus.routePoints.size()]
		var segmentLength: float = fromPoint.distance_to(toPoint)
		if segmentLength < 0.5:
			bus.routeIndex = (bus.routeIndex + 1) % bus.routePoints.size()
			bus.progress = 0.0
			continue
		var segmentRemaining: float = (1.0 - bus.progress) * segmentLength
		if remainingDistance < segmentRemaining:
			bus.progress += remainingDistance / segmentLength
			remainingDistance = 0.0
		else:
			remainingDistance -= segmentRemaining
			bus.routeIndex = (bus.routeIndex + 1) % bus.routePoints.size()
			bus.progress = 0.0
	var startPoint: Vector2 = bus.routePoints[bus.routeIndex]
	var endPoint: Vector2 = bus.routePoints[(bus.routeIndex + 1) % bus.routePoints.size()]
	var segmentVector: Vector2 = endPoint - startPoint
	if segmentVector.length() >= 0.5:
		bus.forward = segmentVector.normalized()
	bus.worldPosition = startPoint.lerp(endPoint, bus.progress)


func _refreshBusRoutes(city: City, lineIndex: int) -> void:
	if lineIndex < 0 or lineIndex >= busLines.size():
		return
	var routePoints: Array[Vector2] = _buildLineRoutePoints(city, busLines[lineIndex])
	for bus: BusVehicle in busVehicles:
		if bus.lineIndex != lineIndex:
			continue
		if routePoints.size() < 2:
			continue
		bus.routePoints = routePoints
		bus.routeIndex = mini(bus.routeIndex, routePoints.size() - 1)
		bus.progress = clampf(bus.progress, 0.0, 1.0)


func _buildLineRoutePoints(city: City, line: BusLine) -> Array[Vector2]:
	var routePoints: Array[Vector2] = []
	if line.stations.size() < 2:
		return routePoints
	for stationIndex in line.stations.size():
		var fromStation: BusStation = line.stations[stationIndex]
		var toStation: BusStation = line.stations[(stationIndex + 1) % line.stations.size()]
		var legPoints: Array[Vector2] = _buildIntersectionLeg(
				city, fromStation.intersection, toStation.intersection)
		for pointIndex in legPoints.size():
			if not routePoints.is_empty() and pointIndex == 0:
				continue
			routePoints.append(legPoints[pointIndex])
	return routePoints


func _buildIntersectionLeg(city: City, fromIntersection: Vector2i,
		toIntersection: Vector2i) -> Array[Vector2]:
	var midIntersection := Vector2i(toIntersection.x, fromIntersection.y)
	return [
		getIntersectionWorldPosition(city, fromIntersection),
		getIntersectionWorldPosition(city, midIntersection),
		getIntersectionWorldPosition(city, toIntersection),
	]


func _drawBusLine(canvas: Node2D, city: City, line: BusLine) -> void:
	var routePoints: Array[Vector2] = _buildLineRoutePoints(city, line)
	if routePoints.size() < 2:
		return
	var lineColor: Color = line.color
	lineColor.a = 0.62
	for pointIndex in routePoints.size():
		var fromPoint: Vector2 = routePoints[pointIndex]
		var toPoint: Vector2 = routePoints[(pointIndex + 1) % routePoints.size()]
		canvas.draw_line(fromPoint, toPoint, lineColor, BusLineWidth)


func _drawBusVehicle(canvas: Node2D, bus: BusVehicle) -> void:
	var side: Vector2 = Vector2(-bus.forward.y, bus.forward.x)
	var halfForward: Vector2 = bus.forward * BusLength * 0.5
	var halfSide: Vector2 = side * BusWidth * 0.5
	var points := PackedVector2Array([
		bus.worldPosition - halfForward - halfSide,
		bus.worldPosition + halfForward - halfSide,
		bus.worldPosition + halfForward + halfSide,
		bus.worldPosition - halfForward + halfSide,
	])
	canvas.draw_colored_polygon(points, bus.color)
	var outlinePoints := PackedVector2Array(points)
	outlinePoints.append(points[0])
	canvas.draw_polyline(outlinePoints, Color.WHITE, 1.0)


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
