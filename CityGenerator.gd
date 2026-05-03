class_name CityGenerator extends RefCounted

const MediumDensityRandomChance: float = 0.018
const HighRiseRandomChance: float = 0.003
const MediumDensityCoreDistance: float = 5.0
const HighRiseCoreDistance: float = 2.0
const WalkBaseShareMax: float = 0.05
const WalkParkBonusMax: float = 0.10
const BikeBaseShareMax: float = 0.05
const BikeCityBonusMax: float = 0.10
const ParkFullBonusRatio: float = 0.15
const HighDensityFullBonusRatio: float = 0.35
const ActiveTransportShareMax: float = 0.30

var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _numArms: int = 0
var _armAngles: Array[float] = []
var _secondaryCbds: Array = []


func generate() -> City:
	var city := City.new()
	_computeLayout(city)
	_buildMap(city)
	return city


func _computeLayout(city: City) -> void:
	_numArms = rng.randi_range(2, 3)
	_armAngles.clear()
	var baseAngle: float = rng.randf() * TAU
	for i in _numArms:
		_armAngles.append(baseAngle + float(i) * TAU / float(_numArms)
				+ rng.randf_range(-0.12, 0.12))

	city.vertStreetWidths.clear()
	for _i in City.Cols + 1:
		city.vertStreetWidths.append(City.WLocal)
	city.horzStreetWidths.clear()
	for _i in City.Rows + 1:
		city.horzStreetWidths.append(City.WLocal)

	var colSpacing: int = rng.randi_range(7, 11)
	var rowSpacing: int = rng.randi_range(5, 8)
	for col in City.Cols + 1:
		if col % colSpacing == 0:
			city.vertStreetWidths[col] = City.WCollector
	for row in City.Rows + 1:
		if row % rowSpacing == 0:
			city.horzStreetWidths[row] = City.WCollector

	var centerColF: float = City.Cols * 0.5
	var centerRowF: float = City.Rows * 0.5
	for armAngle: float in _armAngles:
		var colIdx: int = clamp(
				int(round(centerColF + cos(armAngle) * centerColF * 0.65)), 1, City.Cols - 1)
		var rowIdx: int = clamp(
				int(round(centerRowF + sin(armAngle) * centerRowF * 0.65)), 1, City.Rows - 1)
		city.vertStreetWidths[colIdx] = City.WArterial
		city.horzStreetWidths[rowIdx] = City.WArterial
		var innerColIdx: int = clamp(
				int(round(centerColF + cos(armAngle) * centerColF * 0.28)), 1, City.Cols - 1)
		var innerRowIdx: int = clamp(
				int(round(centerRowF + sin(armAngle) * centerRowF * 0.28)), 1, City.Rows - 1)
		if city.vertStreetWidths[innerColIdx] < City.WArterial:
			city.vertStreetWidths[innerColIdx] = City.WCollector
		if city.horzStreetWidths[innerRowIdx] < City.WArterial:
			city.horzStreetWidths[innerRowIdx] = City.WCollector

	var totalStreetWidth: float = 0.0
	for streetWidth in city.vertStreetWidths:
		totalStreetWidth += streetWidth
	var totalStreetHeight: float = 0.0
	for streetHeight in city.horzStreetWidths:
		totalStreetHeight += streetHeight

	var availWidth: float = City.MapW - City.Margin * 2 - totalStreetWidth
	var availHeight: float = City.MapH - City.Margin * 2 - totalStreetHeight

	var colWeights: Array[float] = []
	var colWeightSum: float = 0.0
	for _i in City.Cols:
		var weight: float = rng.randf_range(0.7, 1.4)
		colWeights.append(weight)
		colWeightSum += weight
	city._colWidths.clear()
	for weight in colWeights:
		city._colWidths.append(availWidth * weight / colWeightSum)

	var rowWeights: Array[float] = []
	var rowWeightSum: float = 0.0
	for _i in City.Rows:
		var weight: float = rng.randf_range(0.7, 1.4)
		rowWeights.append(weight)
		rowWeightSum += weight
	city._rowHeights.clear()
	for weight in rowWeights:
		city._rowHeights.append(availHeight * weight / rowWeightSum)

	city._colXPositions.clear()
	var curX: float = City.Margin + city.vertStreetWidths[0]
	for col in City.Cols:
		city._colXPositions.append(curX)
		curX += city._colWidths[col] + city.vertStreetWidths[col + 1]

	city._rowYPositions.clear()
	var curY: float = City.Margin + city.horzStreetWidths[0]
	for row in City.Rows:
		city._rowYPositions.append(curY)
		curY += city._rowHeights[row] + city.horzStreetWidths[row + 1]

	_generateSecondaryCbds(city)


func _buildMap(city: City) -> void:
	var centerCol: float = (City.Cols - 1) / 2.0
	var centerRow: float = (City.Rows - 1) / 2.0
	city.zones = []
	city.colors = []
	city.parcelOwner = []
	city.parcelExtent = []
	city.commuteProfiles = []
	city.totalPopulation = 0

	var cityParkRatio: float = rng.randf_range(0.0, 0.043)
	var cityIndRatio: float = rng.randf_range(0.0, 0.04)
	var comCore: float = rng.randf_range(1.0, 5.0)
	var comFringe: float = comCore + rng.randf_range(0.6, 3.0)
	var cbdOfficeRatio: float = rng.randf_range(0.015, 0.15)
	var cbdResRatio: float = rng.randf_range(0.0, 0.80)

	for row in City.Rows:
		var zoneRow: Array = []
		var colorRow: Array = []
		var ownerRow: Array = []
		var extentRow: Array = []
		for col in City.Cols:
			zoneRow.append(null)
			colorRow.append(Color.WHITE)
			ownerRow.append(Vector2i(col, row))
			extentRow.append(Vector2i(col, row))
		city.zones.append(zoneRow)
		city.colors.append(colorRow)
		city.parcelOwner.append(ownerRow)
		city.parcelExtent.append(extentRow)

	for row in City.Rows:
		for col in City.Cols:
			if city.zones[row][col] != null:
				continue

			var dx: float = col - centerCol
			var dy: float = row - centerRow
			var dist: float = sqrt(dx * dx + dy * dy)
			var corner: bool = (col == 0 or col == City.Cols - 1) \
					and (row == 0 or row == City.Rows - 1)

			var zone: int
			if not _isInsideCity(col, row):
				zone = Zone.Empty
			elif dist < comCore:
				if rng.randf() < cbdResRatio:
					zone = Zone.Residential
				elif rng.randf() < cbdOfficeRatio:
					zone = Zone.OfficeIndustry
				else:
					zone = Zone.Commercial
			elif dist < comFringe:
				if rng.randf() < 0.07:
					zone = Zone.Commercial
				elif rng.randf() < cityParkRatio * 0.5:
					zone = Zone.Park
				else:
					zone = Zone.Residential
			else:
				var parkChance: float = min(0.95, cityParkRatio * (3.0 if corner else 1.0))
				if rng.randf() < parkChance:
					zone = Zone.Park
				elif rng.randf() < 0.06:
					zone = Zone.Commercial
				else:
					var indChance: float = cityIndRatio
					for neighbor: Vector2i in [Vector2i(col - 1, row), Vector2i(col, row - 1)]:
						if neighbor.x >= 0 and neighbor.y >= 0 \
								and city.zones[neighbor.y][neighbor.x] == Zone.OfficeIndustry:
							indChance = min(0.9, indChance * 5.0)
							break
					if rng.randf() < indChance:
						zone = Zone.OfficeIndustry
					else:
						zone = Zone.Residential

			if zone != Zone.Empty:
				for cbd: Dictionary in _secondaryCbds:
					var secDist: float = _secondaryCbdDist(col, row, cbd)
					if secDist < cbd.coreR:
						if rng.randf() < cbd.resRatio:
							zone = Zone.Residential
						elif rng.randf() < cbd.officeRatio:
							zone = Zone.OfficeIndustry
						else:
							zone = Zone.Commercial
						break
					elif secDist < cbd.fringeR:
						zone = Zone.Commercial if rng.randf() < 0.22 else Zone.Residential
						break

			var effectiveDistColor: float = dist
			for cbd: Dictionary in _secondaryCbds:
				var secDist: float = _secondaryCbdDist(col, row, cbd)
				if secDist < cbd.fringeR:
					effectiveDistColor = min(effectiveDistColor,
							secDist * 5.5 / max(0.01, cbd.fringeR))
					break

			if zone == Zone.Residential:
				zone = _pickResidentialDensity(effectiveDistColor)
			var baseColor: Color
			match zone:
				Zone.Park:
					baseColor = City.CPark
				Zone.Residential, Zone.MediumDensityResidential, Zone.HighDensityResidential:
					baseColor = _residentialColor(zone, effectiveDistColor)
				Zone.Commercial:
					baseColor = City.CCom[rng.randi() % City.CCom.size()]
				Zone.OfficeIndustry:
					baseColor = City.CInd[rng.randi() % City.CInd.size()]
				_:
					baseColor = Color.WHITE

			city.zones[row][col] = zone
			city.colors[row][col] = baseColor

			if (zone == Zone.Park or zone == Zone.OfficeIndustry) \
					and rng.randf() <= (0.95 if zone == Zone.Park else 0.80):
				var mergeLimit: int = 7 if zone == Zone.Park else 1
				var maxCol: int = col
				while maxCol + 1 < City.Cols and maxCol - col < mergeLimit:
					var nextCol: int = maxCol + 1
					if city.zones[row][nextCol] != null:
						break
					var ndx: float = nextCol - centerCol
					var ndy: float = row - centerRow
					var dist2: float = sqrt(ndx * ndx + ndy * ndy)
					if not _isInsideCity(nextCol, row) \
							or (zone == Zone.Park and dist2 < comCore):
						break
					if zone == Zone.Park and rng.randf() < (maxCol - col + 1) * 0.15:
						break
					maxCol += 1
				var maxRow: int = row
				while maxRow + 1 < City.Rows and maxRow - row < mergeLimit:
					var ok: bool = true
					for c2 in range(col, maxCol + 1):
						if city.zones[maxRow + 1][c2] != null:
							ok = false
							break
						var ndx: float = c2 - centerCol
						var ndy: float = (maxRow + 1) - centerRow
						var dist2: float = sqrt(ndx * ndx + ndy * ndy)
						if not _isInsideCity(c2, maxRow + 1) \
								or (zone == Zone.Park and dist2 < comCore):
							ok = false
							break
					if not ok:
						break
					if zone == Zone.Park and rng.randf() < (maxRow - row + 1) * 0.15:
						break
					maxRow += 1
				if maxCol > col or maxRow > row:
					for r in range(row, maxRow + 1):
						for c2 in range(col, maxCol + 1):
							city.zones[r][c2] = zone
							city.colors[r][c2] = baseColor
							city.parcelOwner[r][c2] = Vector2i(col, row)
					city.parcelExtent[row][col] = Vector2i(maxCol, maxRow)

	_assignResidentialCommuteProfiles(city)


func _pickResidentialDensity(effectiveDistColor: float) -> int:
	var roll: float = rng.randf()
	if effectiveDistColor < HighRiseCoreDistance or roll < HighRiseRandomChance:
		return Zone.HighDensityResidential
	if effectiveDistColor < MediumDensityCoreDistance or roll < MediumDensityRandomChance:
		return Zone.MediumDensityResidential
	return Zone.Residential


func _residentialColor(zone: int, effectiveDistColor: float) -> Color:
	match zone:
		Zone.HighDensityResidential:
			return City.CRes[3]
		Zone.MediumDensityResidential:
			return City.CRes[2]
		_:
			var idx: int = clamp(int(effectiveDistColor), 0, City.CRes.size() - 1)
			return City.CRes[City.CRes.size() - 1 - idx]


func _assignResidentialCommuteProfiles(city: City) -> void:
	var parkTileCount: int = 0
	var developedTileCount: int = 0
	var residentialTileCount: int = 0
	var highDensityTileCount: int = 0

	city.commuteProfiles.clear()
	for row in City.Rows:
		var commuteRow: Array = []
		for col in City.Cols:
			commuteRow.append(null)
			var zone: int = city.zones[row][col]
			if zone == Zone.Empty:
				continue
			developedTileCount += 1
			if zone == Zone.Park:
				parkTileCount += 1
			if _isResidentialZone(zone):
				residentialTileCount += 1
				if zone == Zone.HighDensityResidential:
					highDensityTileCount += 1
		city.commuteProfiles.append(commuteRow)

	var parkRatio: float = float(parkTileCount) / maxf(1.0, float(developedTileCount))
	var highDensityRatio: float = float(highDensityTileCount) \
			/ maxf(1.0, float(residentialTileCount))
	var parkInfluence: float = clampf(parkRatio / ParkFullBonusRatio, 0.0, 1.0)
	var highDensityInfluence: float = clampf(
			highDensityRatio / HighDensityFullBonusRatio, 0.0, 1.0)
	var cityWalkShare: float = rng.randf_range(0.0, WalkBaseShareMax) \
			+ parkInfluence * WalkParkBonusMax
	var cityBikeShare: float = rng.randf_range(0.0, BikeBaseShareMax) \
			+ (parkInfluence + highDensityInfluence) * 0.5 * BikeCityBonusMax
	var cityCenter: Vector2 = Vector2((City.Cols - 1) * 0.5, (City.Rows - 1) * 0.5)

	for row in City.Rows:
		for col in City.Cols:
			if city.parcelOwner[row][col] != Vector2i(col, row):
				continue
			var zone: int = city.zones[row][col]
			if not _isResidentialZone(zone):
				continue
			var profile: City.TileCommuteProfile = City.TileCommuteProfile.new()
			profile.population = _residentialPopulation(zone)
			profile.commuteCostByMode = _commuteCostsForTile(col, row, zone, cityCenter)
			profile.transportDistribution = _initialTransportDistribution(
					zone, cityWalkShare, cityBikeShare)
			profile.baseTransportDistribution = profile.transportDistribution.duplicate()
			profile.currentCarCommuteMinutes = profile.commuteCostByMode.get(
					City.TransportCar, 0.0)
			city.commuteProfiles[row][col] = profile
			city.totalPopulation += profile.population


func _isResidentialZone(zone: int) -> bool:
	return zone == Zone.Residential \
			or zone == Zone.MediumDensityResidential \
			or zone == Zone.HighDensityResidential


func _residentialPopulation(zone: int) -> int:
	match zone:
		Zone.MediumDensityResidential:
			return rng.randi_range(100, 400)
		Zone.HighDensityResidential:
			return rng.randi_range(400, 800)
		_:
			return rng.randi_range(10, 100)


func _commuteCostsForTile(col: int, row: int, zone: int, cityCenter: Vector2) -> Dictionary:
	var distanceFromCenter: float = Vector2(col, row).distance_to(cityCenter)
	var densityMultiplier: float = 1.0
	match zone:
		Zone.MediumDensityResidential:
			densityMultiplier = 0.9
		Zone.HighDensityResidential:
			densityMultiplier = 0.8
	return {
		City.TransportCar: 8.0 + distanceFromCenter * 0.75 * densityMultiplier,
		City.TransportSubway: 10.0 + distanceFromCenter * 0.95 * densityMultiplier,
		City.TransportBike: 5.0 + distanceFromCenter * 1.25 * densityMultiplier,
		City.TransportWalk: 4.0 + distanceFromCenter * 3.0 * densityMultiplier,
	}


func _initialTransportDistribution(zone: int, cityWalkShare: float,
		cityBikeShare: float) -> Dictionary:
	var walkMultiplier: float = 0.85
	var bikeMultiplier: float = 0.9
	match zone:
		Zone.MediumDensityResidential:
			walkMultiplier = 1.0
			bikeMultiplier = 1.0
		Zone.HighDensityResidential:
			walkMultiplier = 1.15
			bikeMultiplier = 1.1
	var walkShare: float = clampf(
			cityWalkShare * walkMultiplier + rng.randf_range(-0.01, 0.01),
			0.0, WalkBaseShareMax + WalkParkBonusMax)
	var bikeShare: float = clampf(
			cityBikeShare * bikeMultiplier + rng.randf_range(-0.01, 0.01),
			0.0, BikeBaseShareMax + BikeCityBonusMax)
	var activeShare: float = walkShare + bikeShare
	if activeShare > ActiveTransportShareMax:
		var scale: float = ActiveTransportShareMax / activeShare
		walkShare *= scale
		bikeShare *= scale
	return {
		City.TransportCar: 1.0 - walkShare - bikeShare,
		City.TransportSubway: 0.0,
		City.TransportBike: bikeShare,
		City.TransportWalk: walkShare,
	}


func _secondaryCbdDist(col: int, row: int, cbd: Dictionary) -> float:
	var dx: float = float(col) - cbd.center.x
	var dy: float = float(row) - cbd.center.y
	if cbd.type == "circular":
		return sqrt(dx * dx + dy * dy)
	var angle: float = cbd.angle
	var along: float = dx * cos(angle) + dy * sin(angle)
	var perp: float = -dx * sin(angle) + dy * cos(angle)
	var dAlong: float = max(0.0, abs(along) - cbd.halfLen)
	return sqrt(dAlong * dAlong + perp * perp)


func _generateSecondaryCbds(city: City) -> void:
	_secondaryCbds.clear()
	var count: int = rng.randi_range(0, 1)
	if count == 0:
		return
	var arterialCols: Array[int] = []
	var arterialRows: Array[int] = []
	for c in range(1, City.Cols):
		if city.vertStreetWidths[c] >= City.WArterial:
			arterialCols.append(c)
	for r in range(1, City.Rows):
		if city.horzStreetWidths[r] >= City.WArterial:
			arterialRows.append(r)
	if arterialCols.is_empty() and arterialRows.is_empty():
		return
	var centerCol: float = (City.Cols - 1) / 2.0
	var centerRow: float = (City.Rows - 1) / 2.0
	var placed: Array = []
	var attempts: int = 0
	while placed.size() < count and attempts < 60:
		attempts += 1
		var cbdType: String = "circular" if rng.randf() < 0.5 else "linear"
		var center: Vector2
		var angle: float = 0.0
		var halfLen: float = 0.0
		if cbdType == "linear":
			var useRow: bool = not arterialRows.is_empty() and \
					(arterialCols.is_empty() or rng.randf() < 0.5)
			if useRow:
				var rowIdx: int = arterialRows[rng.randi() % arterialRows.size()]
				center = Vector2(rng.randf_range(8.0, City.Cols - 9.0), rowIdx - 0.5)
				angle = 0.0
			else:
				var colIdx: int = arterialCols[rng.randi() % arterialCols.size()]
				center = Vector2(colIdx - 0.5, rng.randf_range(6.0, City.Rows - 7.0))
				angle = PI * 0.5
			halfLen = rng.randf_range(3.0, 9.0)
		else:
			if not arterialCols.is_empty() and not arterialRows.is_empty() \
					and rng.randf() < 0.55:
				var colIdx: int = arterialCols[rng.randi() % arterialCols.size()]
				var rowIdx: int = arterialRows[rng.randi() % arterialRows.size()]
				center = Vector2(colIdx - 0.5 + rng.randf_range(-1.5, 1.5),
						rowIdx - 0.5 + rng.randf_range(-1.5, 1.5))
			elif not arterialCols.is_empty():
				var colIdx: int = arterialCols[rng.randi() % arterialCols.size()]
				center = Vector2(colIdx - 0.5 + rng.randf_range(-1.5, 1.5),
						rng.randf_range(5.0, City.Rows - 6.0))
			else:
				var rowIdx: int = arterialRows[rng.randi() % arterialRows.size()]
				center = Vector2(rng.randf_range(5.0, City.Cols - 6.0),
						rowIdx - 0.5 + rng.randf_range(-1.5, 1.5))
		if center.distance_to(Vector2(centerCol, centerRow)) < 10.0:
			continue
		var tooClose: bool = false
		for existing: Dictionary in placed:
			if center.distance_to(existing.center) < 8.0:
				tooClose = true
				break
		if tooClose:
			continue
		var cbdCol: int = clamp(int(round(center.x)), 0, City.Cols - 1)
		var cbdRow: int = clamp(int(round(center.y)), 0, City.Rows - 1)
		if not _isInsideCity(cbdCol, cbdRow):
			continue
		var coreRadius: float = rng.randf_range(1.5, 3.5)
		var fringeRadius: float = coreRadius + rng.randf_range(1.5, 3.5)
		placed.append({
			"center": center,
			"type": cbdType,
			"coreR": coreRadius,
			"fringeR": fringeRadius,
			"officeRatio": rng.randf_range(0.02, 0.12),
			"resRatio": rng.randf_range(0.0, 0.80),
			"angle": angle,
			"halfLen": halfLen,
		})
	_secondaryCbds = placed


func _isInsideCity(col: int, row: int) -> bool:
	var centerCol: float = (City.Cols - 1) / 2.0
	var centerRow: float = (City.Rows - 1) / 2.0
	var dx: float = (col - centerCol) / (City.Cols / 2.0)
	var dy: float = (row - centerRow) / (City.Rows / 2.0)
	var normalizedDist: float = sqrt(dx * dx + dy * dy)
	if normalizedDist < 0.55:
		return true
	var angle: float = atan2(dy, dx)
	for armAngle: float in _armAngles:
		var diff: float = angle - armAngle
		diff -= TAU * round(diff / TAU)
		var influence: float = max(0.0, 1.0 - abs(diff) / 0.65)
		if normalizedDist < 0.55 + 0.18 * influence:
			return true
	return false
