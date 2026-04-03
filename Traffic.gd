class_name Traffic extends RefCounted

const CarCount: int = 200
const CarSpeedMin: float = 12.5
const CarSpeedMax: float = 27.5
const CarLength: float = 3.5
const CarWidth: float = 1.8

const CarColors: Array[Color] = [
    Palette.CGrayLight,
    Palette.CAmber,
    Palette.CSienna,
    Palette.CSkyBlue,
    Palette.CGreenBright,
    Palette.CPink,
]

const PhaseDuration: float = 15.0
const PhaseNS: int = 0
const PhaseEW: int = 1
const StopOffset: float = CarLength * 2.0
const BrakingDistance: float = 18.0

const ZoneWeights: Dictionary = {
    Zone.Park: 2,
    Zone.Residential: 1,
    Zone.HighDensityResidential: 10,
    Zone.Commercial: 15,
    Zone.OfficeIndustry: 6,
}
const GoalHopsMax: int = 150

var _cars: Array = []
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _trafficLights: Dictionary = {}
var _segmentMap: Dictionary = {}
var _tilesByZone: Dictionary = {}
var _time: float = 0.0


func init(city: City) -> void:
    _rng.seed = 99991
    _time = 0.0
    _trafficLights.clear()
    for v in range(City.Cols + 1):
        for h in range(City.Rows + 1):
            if city.vertStreetWidths[v] >= City.WCollector \
                    and city.horzStreetWidths[h] >= City.WCollector:
                _trafficLights[Vector2i(v, h)] = {
                    "phase": _rng.randi() % 2,
                    "lastChanged": -_rng.randf_range(0.0, PhaseDuration),
                }
    _cars.clear()
    _segmentMap.clear()
    _buildTilesByZone(city)
    var attempts: int = 0
    while _cars.size() < CarCount and attempts < CarCount * 30:
        attempts += 1
        var car: Dictionary = _spawnCar(city)
        if not car.is_empty():
            _assignGoal(city, car)
            _cars.append(car)
    _buildSegmentMap()


func tick(city: City, delta: float) -> void:
    _time += delta
    for car in _cars:
        _advanceCar(city, car, delta)


func _buildSegmentMap() -> void:
    _segmentMap.clear()
    for car in _cars:
        car.leader = null
        car.follower = null
    var groups: Dictionary = {}
    for car in _cars:
        var key := Vector4i(car.fromVertStreet, car.fromHorzStreet,
                car.toVertStreet, car.toHorzStreet)
        if not groups.has(key):
            groups[key] = []
        groups[key].append(car)
    for key in groups:
        var group: Array = groups[key]
        group.sort_custom(func(a, b): return a.progress < b.progress)
        _segmentMap[key] = group[0]
        for i in range(group.size() - 1):
            group[i].leader = group[i + 1]
            group[i + 1].follower = group[i]


func _insertIntoSegment(car: Dictionary) -> void:
    var key := Vector4i(car.fromVertStreet, car.fromHorzStreet,
            car.toVertStreet, car.toHorzStreet)
    var head = _segmentMap.get(key, null)
    if head == null or car.progress <= head.progress:
        car.leader = head
        car.follower = null
        if head != null:
            head.follower = car
        _segmentMap[key] = car
        return
    var prev = head
    while prev.leader != null and prev.leader.progress <= car.progress:
        prev = prev.leader
    car.follower = prev
    car.leader = prev.leader
    if prev.leader != null:
        prev.leader.follower = car
    prev.leader = car


func _removeFromSegment(car: Dictionary) -> void:
    if car.follower != null:
        car.follower.leader = car.leader
    else:
        var key := Vector4i(car.fromVertStreet, car.fromHorzStreet,
                car.toVertStreet, car.toHorzStreet)
        if car.leader != null:
            _segmentMap[key] = car.leader
        else:
            _segmentMap.erase(key)
    if car.leader != null:
        car.leader.follower = car.follower
    car.leader = null
    car.follower = null


func drawCars(canvas: Node2D, city: City) -> void:
    for car in _cars:
        var segStart := Vector2(
                _vertStreetCenterX(city, car.fromVertStreet),
                _horzStreetCenterY(city, car.fromHorzStreet))
        var segEnd := Vector2(
                _vertStreetCenterX(city, car.toVertStreet),
                _horzStreetCenterY(city, car.toHorzStreet))
        var center: Vector2 = segStart.lerp(segEnd, car.progress) + car.laneOffset
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
    var desiredSpeed: float = _rng.randf_range(CarSpeedMin, CarSpeedMax)

    return {
        "fromVertStreet": fromVertStreet,
        "fromHorzStreet": fromHorzStreet,
        "toVertStreet": toVertStreet,
        "toHorzStreet": toHorzStreet,
        "progress": _rng.randf(),
        "desiredSpeed": desiredSpeed,
        "currentSpeed": desiredSpeed,
        "segLength": segLength,
        "forward": forward,
        "laneOffset": _calcLaneOffset(forward, streetWidth),
        "color": CarColors[_rng.randi() % CarColors.size()],
        "leader": null,
        "follower": null,
        "goalTile": Vector2i(0, 0),
        "goalIntersection": Vector2i(0, 0),
        "goalHops": 0,
    }


func _isRedForCar(car: Dictionary, key: Vector2i) -> bool:
    var light: Dictionary = _trafficLights[key]
    var elapsed: float = _time - light.lastChanged
    if elapsed >= PhaseDuration:
        light.phase = 1 - light.phase
        light.lastChanged = _time - fmod(elapsed, PhaseDuration)
    var isEW: bool = (car.toHorzStreet == car.fromHorzStreet)
    return (isEW and light.phase == PhaseNS) or (not isEW and light.phase == PhaseEW)


func _advanceCar(city: City, car: Dictionary, delta: float) -> void:
    var lightKey := Vector2i(car.toVertStreet, car.toHorzStreet)
    var redLight: bool = _trafficLights.has(lightKey) and _isRedForCar(car, lightKey)
    var stopT: float = maxf(0.0, 1.0 - StopOffset / car.segLength)

    if redLight and car.progress >= stopT:
        car.currentSpeed = 0.0
        return

    var effectiveSpeed: float = car.desiredSpeed
    if redLight:
        var brakeStartT: float = stopT - BrakingDistance / car.segLength
        if car.progress > brakeStartT and stopT > brakeStartT:
            effectiveSpeed = car.desiredSpeed \
                    * (stopT - car.progress) / (stopT - brakeStartT)

    if car.leader != null and car.leader.progress > car.progress:
        var gap: float = (car.leader.progress - car.progress) * car.segLength - CarLength
        if gap < BrakingDistance:
            effectiveSpeed = minf(effectiveSpeed, car.leader.currentSpeed)

    car.currentSpeed = effectiveSpeed
    car.progress += effectiveSpeed * delta / car.segLength

    if redLight:
        car.progress = minf(car.progress, stopT)
        return

    if car.progress < 1.0:
        return

    var overflow: float = car.progress - 1.0
    var arrivedVertStreet: int = car.toVertStreet
    var arrivedHorzStreet: int = car.toHorzStreet

    var neighbors: Array = _getExitSegments(
            city, arrivedVertStreet, arrivedHorzStreet,
            car.fromVertStreet, car.fromHorzStreet)
    car.goalHops += 1
    if (arrivedVertStreet == car.goalIntersection.x \
            and arrivedHorzStreet == car.goalIntersection.y) \
            or car.goalHops > GoalHopsMax:
        _assignGoal(city, car)
    var nextToVertStreet: int
    var nextToHorzStreet: int
    if neighbors.is_empty():
        nextToVertStreet = car.fromVertStreet
        nextToHorzStreet = car.fromHorzStreet
    else:
        var chosen: Array = _greedyExit(city, neighbors, car.goalIntersection)
        nextToVertStreet = chosen[0]
        nextToHorzStreet = chosen[1]

    _removeFromSegment(car)

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

    car.progress = overflow / car.segLength

    _insertIntoSegment(car)


func _buildTilesByZone(city: City) -> void:
    _tilesByZone.clear()
    for row in City.Rows:
        for col in City.Cols:
            if city.parcelOwner[row][col] != Vector2i(col, row):
                continue
            var zone: int = city.zones[row][col]
            if not ZoneWeights.has(zone):
                continue
            if not _tilesByZone.has(zone):
                _tilesByZone[zone] = []
            _tilesByZone[zone].append(Vector2i(col, row))


func _pickGoalTile() -> Vector2i:
    var totalWeight: float = 0.0
    for zone: int in ZoneWeights:
        if _tilesByZone.has(zone):
            totalWeight += ZoneWeights[zone]
    if totalWeight == 0.0:
        return Vector2i(0, 0)
    var roll: float = _rng.randf() * totalWeight
    var cumulative: float = 0.0
    var pickedZone: int = ZoneWeights.keys()[0]
    for zone: int in ZoneWeights:
        if _tilesByZone.has(zone):
            cumulative += ZoneWeights[zone]
            if roll <= cumulative:
                pickedZone = zone
                break
    var tiles: Array = _tilesByZone[pickedZone]
    return tiles[_rng.randi() % tiles.size()]


func _assignGoal(city: City, car: Dictionary) -> void:
    var tile: Vector2i = _pickGoalTile()
    car.goalTile = tile
    var corners: Array[Vector2i] = [
        Vector2i(tile.x, tile.y),
        Vector2i(tile.x + 1, tile.y),
        Vector2i(tile.x, tile.y + 1),
        Vector2i(tile.x + 1, tile.y + 1),
    ]
    var curX: float = _vertStreetCenterX(city, car.toVertStreet)
    var curY: float = _horzStreetCenterY(city, car.toHorzStreet)
    var bestDist: float = INF
    var bestCorner := Vector2i(tile.x, tile.y)
    for corner: Vector2i in corners:
        var cx: float = _vertStreetCenterX(city, corner.x)
        var cy: float = _horzStreetCenterY(city, corner.y)
        var d: float = (curX - cx) * (curX - cx) + (curY - cy) * (curY - cy)
        if d < bestDist:
            bestDist = d
            bestCorner = corner
    car.goalIntersection = bestCorner
    car.goalHops = 0


func _greedyExit(city: City, candidates: Array, goalIntersection: Vector2i) -> Array:
    var goalX: float = _vertStreetCenterX(city, goalIntersection.x)
    var goalY: float = _horzStreetCenterY(city, goalIntersection.y)
    var bestDist: float = INF
    var best: Array = candidates[0]
    for cand: Array in candidates:
        var cx: float = _vertStreetCenterX(city, cand[0])
        var cy: float = _horzStreetCenterY(city, cand[1])
        var d: float = (cx - goalX) * (cx - goalX) + (cy - goalY) * (cy - goalY)
        if d < bestDist:
            bestDist = d
            best = cand
    return best


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
