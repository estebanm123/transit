class_name Traffic extends RefCounted

const CarCount: int = 1600
const CarSpeedMin: float = 4.25
const CarSpeedMax: float = 9.35
const CarLength: float = 2.8
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
const PhaseArterialDuration: float = 25.0
const PhaseNonArterialDuration: float = 8.0
const PhaseNS: int = 0
const PhaseEW: int = 1
const StopOffset: float = CarLength * 2.0
const BrakingDistance: float = 18.0
const IntersectionBoxDepth: float = StopOffset

const ArterialSpeedMultiplier: float = 4.0

const ZoneWeights: Dictionary = {
    Zone.Park: 2,
    Zone.Residential: 1,
    Zone.HighDensityResidential: 12,
    Zone.Commercial: 30,
    Zone.OfficeIndustry: 6,
}
const GoalHopsMax: int = 150

const HISTORY_SIZE: int = 8
const HISTORY_HALF: int = 4


class Car extends RefCounted:
    var fromVertStreet: int = 0
    var fromHorzStreet: int = 0
    var toVertStreet: int = 0
    var toHorzStreet: int = 0
    var progress: float = 0.0
    var baseSpeed: float = 0.0
    var desiredSpeed: float = 0.0
    var currentSpeed: float = 0.0
    var segLength: float = 0.0
    var forward: Vector2 = Vector2.ZERO
    var laneOffset: Vector2 = Vector2.ZERO
    var color: Color
    var colorIndex: int = 0
    var leader = null
    var follower = null
    var goalTile: Vector2i = Vector2i.ZERO
    var goalIntersection: Vector2i = Vector2i.ZERO
    var goalHops: int = 0
    var historyBuf: Array = [
        Vector4i(), Vector4i(), Vector4i(), Vector4i(),
        Vector4i(), Vector4i(), Vector4i(), Vector4i(),
    ]
    var historyHead: int = 0
    var historyCount: int = 0


var _cars: Array[Car] = []
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _trafficLights: Dictionary = {}
var _segmentMap: Dictionary = {}
var _segmentFront: Dictionary = {}
var _tilesByZone: Dictionary = {}
var _time: float = 0.0

var _vertStreetX: PackedFloat32Array
var _horzStreetY: PackedFloat32Array
var _horzUsable: PackedByteArray
var _vertUsable: PackedByteArray
var _goalTotalWeight: float = 0.0
var _goalCumWeights: Array[float] = []
var _goalZones: Array[int] = []


func init(city: City) -> void:
    _rng.seed = 99991
    _time = 0.0
    _trafficLights.clear()
    for v in range(City.Cols + 1):
        for h in range(City.Rows + 1):
            if city.vertStreetWidths[v] >= City.WCollector \
                    and city.horzStreetWidths[h] >= City.WCollector:
                var isVertArterial: bool = city.vertStreetWidths[v] >= City.WArterial
                var isHorzArterial: bool = city.horzStreetWidths[h] >= City.WArterial
                var arterialPhase: int = -1
                if isVertArterial and not isHorzArterial:
                    arterialPhase = PhaseNS
                elif isHorzArterial and not isVertArterial:
                    arterialPhase = PhaseEW
                _trafficLights[Vector2i(v, h)] = {
                    "phase": _rng.randi() % 2,
                    "lastChanged": -_rng.randf_range(0.0, PhaseDuration),
                    "arterialPhase": arterialPhase,
                }
    _cars.clear()
    _segmentMap.clear()
    _buildTilesByZone(city)
    _buildPositionCache(city)
    _buildUsabilityCache(city)
    var attempts: int = 0
    while _cars.size() < CarCount and attempts < CarCount * 30:
        attempts += 1
        var car: Car = _spawnCar(city)
        if car != null:
            _assignGoal(city, car)
            _cars.append(car)
    _cars.sort_custom(func(a: Car, b: Car) -> bool: return a.colorIndex < b.colorIndex)
    _buildSegmentMap()


func tick(city: City, delta: float) -> void:
    _time += delta
    for car in _cars:
        _advanceCar(city, car, delta)


func _buildPositionCache(city: City) -> void:
    _vertStreetX.resize(City.Cols + 1)
    for v in range(City.Cols + 1):
        _vertStreetX[v] = _vertStreetCenterX(city, v)
    _horzStreetY.resize(City.Rows + 1)
    for h in range(City.Rows + 1):
        _horzStreetY[h] = _horzStreetCenterY(city, h)


func _buildUsabilityCache(city: City) -> void:
    _horzUsable.resize((City.Rows + 1) * City.Cols)
    for h in range(City.Rows + 1):
        for v in range(City.Cols):
            _horzUsable[h * City.Cols + v] = 1 if _horzSegmentUsable(city, v, h) else 0
    _vertUsable.resize((City.Cols + 1) * City.Rows)
    for v in range(City.Cols + 1):
        for h in range(City.Rows):
            _vertUsable[v * City.Rows + h] = 1 if _vertSegmentUsable(city, v, h) else 0


func _horzUsableAt(v: int, h: int) -> bool:
    if v < 0 or v >= City.Cols or h < 0 or h > City.Rows:
        return false
    return _horzUsable[h * City.Cols + v] != 0


func _vertUsableAt(v: int, h: int) -> bool:
    if v < 0 or v > City.Cols or h < 0 or h >= City.Rows:
        return false
    return _vertUsable[v * City.Rows + h] != 0


func _buildSegmentMap() -> void:
    _segmentMap.clear()
    _segmentFront.clear()
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
        group.sort_custom(func(a: Car, b: Car) -> bool: return a.progress < b.progress)
        _segmentMap[key] = group[0]
        _segmentFront[key] = group[group.size() - 1]
        for i in range(group.size() - 1):
            group[i].leader = group[i + 1]
            group[i + 1].follower = group[i]


func _insertIntoSegment(car: Car) -> void:
    var key := Vector4i(car.fromVertStreet, car.fromHorzStreet,
            car.toVertStreet, car.toHorzStreet)
    var head: Car = _segmentMap.get(key, null)
    if head == null or car.progress <= head.progress:
        car.leader = head
        car.follower = null
        if head != null:
            head.follower = car
        _segmentMap[key] = car
        if car.leader == null:
            _segmentFront[key] = car
        return
    var prev: Car = head
    while prev.leader != null and prev.leader.progress <= car.progress:
        prev = prev.leader
    car.follower = prev
    car.leader = prev.leader
    if prev.leader != null:
        prev.leader.follower = car
    prev.leader = car
    if car.leader == null:
        _segmentFront[key] = car


func _removeFromSegment(car: Car) -> void:
    var key := Vector4i(car.fromVertStreet, car.fromHorzStreet,
            car.toVertStreet, car.toHorzStreet)
    if car.follower != null:
        car.follower.leader = car.leader
    else:
        if car.leader != null:
            _segmentMap[key] = car.leader
        else:
            _segmentMap.erase(key)
    if car.leader != null:
        car.leader.follower = car.follower
    else:
        if car.follower != null:
            _segmentFront[key] = car.follower
        else:
            _segmentFront.erase(key)
    car.leader = null
    car.follower = null


func drawCars(canvas: Node2D) -> void:
    const HALF_LEN: float = CarLength * 0.5
    const HALF_WID: float = CarWidth * 0.5
    for car in _cars:
        var cx: float = lerpf(_vertStreetX[car.fromVertStreet], _vertStreetX[car.toVertStreet],
                car.progress) + car.laneOffset.x
        var cy: float = lerpf(_horzStreetY[car.fromHorzStreet], _horzStreetY[car.toHorzStreet],
                car.progress) + car.laneOffset.y
        var rect: Rect2
        if car.forward.x != 0.0:
            rect = Rect2(cx - HALF_LEN, cy - HALF_WID, CarLength, CarWidth)
        else:
            rect = Rect2(cx - HALF_WID, cy - HALF_LEN, CarWidth, CarLength)
        canvas.draw_rect(rect, car.color)


func _vertStreetCenterX(city: City, vertStreetIdx: int) -> float:
    if vertStreetIdx < City.Cols:
        return city._colXPositions[vertStreetIdx] - city.vertStreetWidths[vertStreetIdx] * 0.5
    return city._colXPositions[City.Cols - 1] + city._colWidths[City.Cols - 1] \
            + city.vertStreetWidths[City.Cols] * 0.5


func _horzStreetCenterY(city: City, horzStreetIdx: int) -> float:
    if horzStreetIdx < City.Rows:
        return city._rowYPositions[horzStreetIdx] - city.horzStreetWidths[horzStreetIdx] * 0.5
    return city._rowYPositions[City.Rows - 1] + city._rowHeights[City.Rows - 1] \
            + city.horzStreetWidths[City.Rows] * 0.5


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


func _spawnCar(city: City) -> Car:
    var isHorizontalSegment: bool = _rng.randf() < 0.5
    var fromVertStreet: int
    var fromHorzStreet: int
    var toVertStreet: int
    var toHorzStreet: int

    if isHorizontalSegment:
        fromVertStreet = _rng.randi_range(0, City.Cols - 1)
        fromHorzStreet = _rng.randi_range(0, City.Rows)
        if not _horzUsableAt(fromVertStreet, fromHorzStreet):
            return null
        toVertStreet = fromVertStreet + 1
        toHorzStreet = fromHorzStreet
    else:
        fromVertStreet = _rng.randi_range(0, City.Cols)
        fromHorzStreet = _rng.randi_range(0, City.Rows - 1)
        if not _vertUsableAt(fromVertStreet, fromHorzStreet):
            return null
        toVertStreet = fromVertStreet
        toHorzStreet = fromHorzStreet + 1

    var segStart := Vector2(_vertStreetX[fromVertStreet], _horzStreetY[fromHorzStreet])
    var segEnd := Vector2(_vertStreetX[toVertStreet], _horzStreetY[toHorzStreet])
    var segLength: float = segStart.distance_to(segEnd)
    if segLength < 0.5:
        return null

    var forward: Vector2 = (segEnd - segStart) / segLength
    var streetWidth: float = city.horzStreetWidths[fromHorzStreet] \
            if isHorizontalSegment else city.vertStreetWidths[fromVertStreet]
    var baseSpeed: float = _rng.randf_range(CarSpeedMin, CarSpeedMax)
    var speedMult: float = ArterialSpeedMultiplier if streetWidth >= City.WArterial else 1.0
    var colorIdx: int = _rng.randi() % CarColors.size()

    var car := Car.new()
    car.fromVertStreet = fromVertStreet
    car.fromHorzStreet = fromHorzStreet
    car.toVertStreet = toVertStreet
    car.toHorzStreet = toHorzStreet
    car.progress = _rng.randf()
    car.baseSpeed = baseSpeed
    car.desiredSpeed = baseSpeed * speedMult
    car.currentSpeed = car.desiredSpeed
    car.segLength = segLength
    car.forward = forward
    car.laneOffset = _calcLaneOffset(forward, streetWidth)
    car.color = CarColors[colorIdx]
    car.colorIndex = colorIdx
    return car


func _isRedForCar(car: Car, key: Vector2i) -> bool:
    var light: Dictionary = _trafficLights[key]
    var elapsed: float = _time - light.lastChanged
    var phaseDuration: float
    if light.arterialPhase < 0:
        phaseDuration = PhaseDuration
    elif light.phase == light.arterialPhase:
        phaseDuration = PhaseArterialDuration
    else:
        phaseDuration = PhaseNonArterialDuration
    if elapsed >= phaseDuration:
        light.phase = 1 - light.phase
        light.lastChanged = _time - fmod(elapsed, phaseDuration)
    var isEW: bool = (car.toHorzStreet == car.fromHorzStreet)
    return (isEW and light.phase == PhaseNS) or (not isEW and light.phase == PhaseEW)


func _isIntersectionClear(v: int, h: int, isHorizontal: bool) -> bool:
    var departing: Array[Vector4i]
    var arriving: Array[Vector4i]
    if isHorizontal:
        departing = [Vector4i(v, h, v, h + 1), Vector4i(v, h, v, h - 1)]
        arriving = [Vector4i(v, h - 1, v, h), Vector4i(v, h + 1, v, h)]
    else:
        departing = [Vector4i(v, h, v + 1, h), Vector4i(v, h, v - 1, h)]
        arriving = [Vector4i(v - 1, h, v, h), Vector4i(v + 1, h, v, h)]
    for key: Vector4i in departing:
        var tail: Car = _segmentMap.get(key, null)
        if tail != null and tail.currentSpeed > 0.0 \
                and tail.progress < IntersectionBoxDepth / tail.segLength:
            return false
    for key: Vector4i in arriving:
        var front: Car = _segmentFront.get(key, null)
        if front == null:
            continue
        var stopLineT: float = 1.0 - StopOffset / front.segLength
        if front.progress >= stopLineT and front.currentSpeed > 0.0:
            return false
    return true


func _advanceCar(city: City, car: Car, delta: float) -> void:
    var lightKey := Vector2i(car.toVertStreet, car.toHorzStreet)
    var redLight: bool = _trafficLights.has(lightKey) and _isRedForCar(car, lightKey)
    var stopT: float = maxf(0.0, 1.0 - StopOffset / car.segLength)
    var brakeStartT: float = stopT - BrakingDistance / car.segLength

    var isHorizontal: bool = (car.toHorzStreet == car.fromHorzStreet)
    var intersectionBlocked: bool = false
    if not redLight and car.progress > brakeStartT:
        intersectionBlocked = not _isIntersectionClear(
                car.toVertStreet, car.toHorzStreet, isHorizontal)

    var shouldStop: bool = redLight or intersectionBlocked
    if shouldStop and car.progress >= stopT:
        car.currentSpeed = 0.0
        return

    var effectiveSpeed: float = car.desiredSpeed
    if shouldStop:
        if car.progress > brakeStartT and stopT > brakeStartT:
            effectiveSpeed = car.desiredSpeed \
                    * (stopT - car.progress) / (stopT - brakeStartT)

    if car.leader != null and car.leader.progress > car.progress:
        var gap: float = (car.leader.progress - car.progress) * car.segLength - CarLength
        if gap < BrakingDistance:
            effectiveSpeed = minf(effectiveSpeed, car.leader.currentSpeed)

    car.currentSpeed = effectiveSpeed
    car.progress += effectiveSpeed * delta / car.segLength

    if shouldStop:
        car.progress = minf(car.progress, stopT)
        return

    if car.progress < 1.0:
        return

    var overflow: float = car.progress - 1.0
    var arrivedVertStreet: int = car.toVertStreet
    var arrivedHorzStreet: int = car.toHorzStreet

    var neighbors: Array = _getExitSegments(
            arrivedVertStreet, arrivedHorzStreet,
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
        var chosen: Array = _greedyExit(neighbors, car.goalIntersection)
        nextToVertStreet = chosen[0]
        nextToHorzStreet = chosen[1]

    _removeFromSegment(car)

    car.fromVertStreet = arrivedVertStreet
    car.fromHorzStreet = arrivedHorzStreet
    car.toVertStreet = nextToVertStreet
    car.toHorzStreet = nextToHorzStreet

    var dx: float = _vertStreetX[nextToVertStreet] - _vertStreetX[arrivedVertStreet]
    var dy: float = _horzStreetY[nextToHorzStreet] - _horzStreetY[arrivedHorzStreet]
    car.segLength = sqrt(dx * dx + dy * dy)
    if car.segLength < 0.5:
        car.segLength = 0.5

    car.forward = Vector2(dx, dy) / car.segLength

    var isHorizontalSegment: bool = (nextToHorzStreet == arrivedHorzStreet)
    var streetWidth: float = city.horzStreetWidths[arrivedHorzStreet] \
            if isHorizontalSegment else city.vertStreetWidths[arrivedVertStreet]
    car.laneOffset = _calcLaneOffset(car.forward, streetWidth)
    car.desiredSpeed = car.baseSpeed \
            * (ArterialSpeedMultiplier if streetWidth >= City.WArterial else 1.0)

    car.progress = overflow / car.segLength

    _insertIntoSegment(car)

    var seg := Vector4i(car.fromVertStreet, car.fromHorzStreet,
            car.toVertStreet, car.toHorzStreet)
    car.historyBuf[car.historyHead] = seg
    car.historyHead = (car.historyHead + 1) % HISTORY_SIZE
    if car.historyCount < HISTORY_SIZE:
        car.historyCount += 1
    if car.historyCount == HISTORY_SIZE:
        var looping: bool = true
        for i in range(HISTORY_HALF):
            if car.historyBuf[(car.historyHead + i) % HISTORY_SIZE] \
                    != car.historyBuf[(car.historyHead + i + HISTORY_HALF) % HISTORY_SIZE]:
                looping = false
                break
        if looping:
            _assignGoal(city, car)


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
    _goalTotalWeight = 0.0
    _goalCumWeights.clear()
    _goalZones.clear()
    var cumulative: float = 0.0
    for zone: int in ZoneWeights:
        if _tilesByZone.has(zone):
            _goalTotalWeight += ZoneWeights[zone]
            cumulative += ZoneWeights[zone]
            _goalCumWeights.append(cumulative)
            _goalZones.append(zone)


func _pickGoalTile() -> Vector2i:
    if _goalTotalWeight == 0.0:
        return Vector2i(0, 0)
    var roll: float = _rng.randf() * _goalTotalWeight
    var pickedZone: int = _goalZones[_goalZones.size() - 1]
    for i in range(_goalCumWeights.size()):
        if roll <= _goalCumWeights[i]:
            pickedZone = _goalZones[i]
            break
    var tiles: Array = _tilesByZone[pickedZone]
    return tiles[_rng.randi() % tiles.size()]


func _assignGoal(city: City, car: Car) -> void:
    car.historyHead = 0
    car.historyCount = 0
    var tile: Vector2i = _pickGoalTile()
    car.goalTile = tile
    var corners: Array[Vector2i] = [
        Vector2i(tile.x, tile.y),
        Vector2i(tile.x + 1, tile.y),
        Vector2i(tile.x, tile.y + 1),
        Vector2i(tile.x + 1, tile.y + 1),
    ]
    var curX: float = _vertStreetX[car.toVertStreet]
    var curY: float = _horzStreetY[car.toHorzStreet]
    var bestDist: float = INF
    var bestCorner := Vector2i(tile.x, tile.y)
    for corner: Vector2i in corners:
        var cx: float = _vertStreetX[corner.x]
        var cy: float = _horzStreetY[corner.y]
        var d: float = (curX - cx) * (curX - cx) + (curY - cy) * (curY - cy)
        if d < bestDist:
            bestDist = d
            bestCorner = corner
    car.goalIntersection = bestCorner
    car.goalHops = 0


func _greedyExit(candidates: Array, goalIntersection: Vector2i) -> Array:
    var goalX: float = _vertStreetX[goalIntersection.x]
    var goalY: float = _horzStreetY[goalIntersection.y]
    var bestDist: float = INF
    var best: Array = candidates[0]
    for cand: Array in candidates:
        var cx: float = _vertStreetX[cand[0]]
        var cy: float = _horzStreetY[cand[1]]
        var d: float = (cx - goalX) * (cx - goalX) + (cy - goalY) * (cy - goalY)
        if d < bestDist:
            bestDist = d
            best = cand
    return best


func _getExitSegments(vertStreetIdx: int, horzStreetIdx: int,
        cameFromVertStreet: int, cameFromHorzStreet: int) -> Array:
    var exits: Array = []
    # East
    if not (cameFromVertStreet == vertStreetIdx + 1 and cameFromHorzStreet == horzStreetIdx) \
            and _horzUsableAt(vertStreetIdx, horzStreetIdx):
        exits.append([vertStreetIdx + 1, horzStreetIdx])
    # West
    if not (cameFromVertStreet == vertStreetIdx - 1 and cameFromHorzStreet == horzStreetIdx) \
            and _horzUsableAt(vertStreetIdx - 1, horzStreetIdx):
        exits.append([vertStreetIdx - 1, horzStreetIdx])
    # South
    if not (cameFromVertStreet == vertStreetIdx and cameFromHorzStreet == horzStreetIdx + 1) \
            and _vertUsableAt(vertStreetIdx, horzStreetIdx):
        exits.append([vertStreetIdx, horzStreetIdx + 1])
    # North
    if not (cameFromVertStreet == vertStreetIdx and cameFromHorzStreet == horzStreetIdx - 1) \
            and _vertUsableAt(vertStreetIdx, horzStreetIdx - 1):
        exits.append([vertStreetIdx, horzStreetIdx - 1])
    return exits
