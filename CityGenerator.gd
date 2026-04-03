class_name CityGenerator extends RefCounted

const MapW: int = 1280
const MapH: int = 720
const Margin: int = 20
const Cols: int = 100
const Rows: int = 60
const StreetW: int = 14

enum Zone { Empty, Park, Residential, Commercial, OfficeIndustry }

const WArterial: float = 8.0
const WCollector: float = 4.0
const WLocal: float = 1.5

const CCountryside: Color = Color("#1e3312")
const CStreet: Color = Color("#3b3b40")

const CPark: Color = Color("#548a5c")

const CRes := [
	Color("#2a4f6e"),
	Color("#3a6888"),
	Color("#4e82a4"),
	Color("#66a0c0"),
]

const CCom := [
	Color("#c09030"),
	Color("#d4a840"),
]

const CInd := [
	Color("#585860"),
	Color("#747478"),
	Color("#90909a"),
]

var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var colWidths: Array[float] = []
var rowHeights: Array[float] = []
var vertStreetWidths: Array[float] = []
var horzStreetWidths: Array[float] = []
var _colXPositions: Array[float] = []
var _rowYPositions: Array[float] = []
var _origin: Vector2 = Vector2(Margin, Margin)

var zones: Array = []
var colors: Array = []
var details: Array = []
var parcelOwner: Array = []
var parcelExtent: Array = []

var _numArms: int = 0
var _armAngles: Array[float] = []
var _secondaryCbds: Array = []


func computeLayout() -> void:
	_numArms = rng.randi_range(4, 6)
	_armAngles.clear()
	var baseAngle: float = rng.randf() * TAU
	for i in _numArms:
		_armAngles.append(baseAngle + float(i) * TAU / float(_numArms)
				+ rng.randf_range(-0.12, 0.12))

	vertStreetWidths.clear()
	for _i in Cols + 1:
		vertStreetWidths.append(WLocal)
	horzStreetWidths.clear()
	for _i in Rows + 1:
		horzStreetWidths.append(WLocal)

	var colSpacing: int = rng.randi_range(7, 11)
	var rowSpacing: int = rng.randi_range(5, 8)
	for col in Cols + 1:
		if col % colSpacing == 0:
			vertStreetWidths[col] = WCollector
	for row in Rows + 1:
		if row % rowSpacing == 0:
			horzStreetWidths[row] = WCollector

	var centerColF: float = Cols * 0.5
	var centerRowF: float = Rows * 0.5
	for armAngle: float in _armAngles:
		var colIdx: int = clamp(
				int(round(centerColF + cos(armAngle) * centerColF * 0.65)), 1, Cols - 1)
		var rowIdx: int = clamp(
				int(round(centerRowF + sin(armAngle) * centerRowF * 0.65)), 1, Rows - 1)
		vertStreetWidths[colIdx] = WArterial
		horzStreetWidths[rowIdx] = WArterial
		var innerColIdx: int = clamp(
				int(round(centerColF + cos(armAngle) * centerColF * 0.28)), 1, Cols - 1)
		var innerRowIdx: int = clamp(
				int(round(centerRowF + sin(armAngle) * centerRowF * 0.28)), 1, Rows - 1)
		if vertStreetWidths[innerColIdx] < WArterial:
			vertStreetWidths[innerColIdx] = WCollector
		if horzStreetWidths[innerRowIdx] < WArterial:
			horzStreetWidths[innerRowIdx] = WCollector

	var totalStreetWidth: float = 0.0
	for streetWidth in vertStreetWidths:
		totalStreetWidth += streetWidth
	var totalStreetHeight: float = 0.0
	for streetHeight in horzStreetWidths:
		totalStreetHeight += streetHeight

	var availWidth: float = MapW - Margin * 2 - totalStreetWidth
	var availHeight: float = MapH - Margin * 2 - totalStreetHeight

	var colWeights: Array[float] = []
	var colWeightSum: float = 0.0
	for _i in Cols:
		var weight: float = rng.randf_range(0.7, 1.4)
		colWeights.append(weight)
		colWeightSum += weight
	colWidths.clear()
	for weight in colWeights:
		colWidths.append(availWidth * weight / colWeightSum)

	var rowWeights: Array[float] = []
	var rowWeightSum: float = 0.0
	for _i in Rows:
		var weight: float = rng.randf_range(0.7, 1.4)
		rowWeights.append(weight)
		rowWeightSum += weight
	rowHeights.clear()
	for weight in rowWeights:
		rowHeights.append(availHeight * weight / rowWeightSum)

	_colXPositions.clear()
	var curX: float = _origin.x + vertStreetWidths[0]
	for col in Cols:
		_colXPositions.append(curX)
		curX += colWidths[col] + vertStreetWidths[col + 1]

	_rowYPositions.clear()
	var curY: float = _origin.y + horzStreetWidths[0]
	for row in Rows:
		_rowYPositions.append(curY)
		curY += rowHeights[row] + horzStreetWidths[row + 1]

	_generateSecondaryCbds()


func buildMap() -> void:
	var centerCol: float = (Cols - 1) / 2.0
	var centerRow: float = (Rows - 1) / 2.0
	zones = []
	colors = []
	details = []
	parcelOwner = []
	parcelExtent = []

	var cityParkRatio: float = rng.randf_range(0.0, 0.043)
	var cityIndRatio: float = rng.randf_range(0.0, 0.04)
	var comCore: float = rng.randf_range(1.0, 5.0)
	var comFringe: float = comCore + rng.randf_range(0.6, 3.0)
	var cbdOfficeRatio: float = rng.randf_range(0.015, 0.15)
	var cbdResRatio: float = rng.randf_range(0.0, 0.80)

	for row in Rows:
		var zoneRow: Array = []
		var colorRow: Array = []
		var ownerRow: Array = []
		var extentRow: Array = []
		for col in Cols:
			zoneRow.append(null)
			colorRow.append(Color.WHITE)
			ownerRow.append(Vector2i(col, row))
			extentRow.append(Vector2i(col, row))
		zones.append(zoneRow)
		colors.append(colorRow)
		parcelOwner.append(ownerRow)
		parcelExtent.append(extentRow)

	for row in Rows:
		for col in Cols:
			if zones[row][col] != null:
				continue

			var dx: float = col - centerCol
			var dy: float = row - centerRow
			var dist: float = sqrt(dx * dx + dy * dy)
			var corner: bool = (col == 0 or col == Cols - 1) and (row == 0 or row == Rows - 1)

			var zone: Zone
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
								and zones[neighbor.y][neighbor.x] == Zone.OfficeIndustry:
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

			var baseColor: Color
			match zone:
				Zone.Park:
					baseColor = CPark
				Zone.Residential:
					var idx: int = clamp(int(effectiveDistColor), 0, CRes.size() - 1)
					baseColor = CRes[CRes.size() - 1 - idx]
				Zone.Commercial:
					baseColor = CCom[rng.randi() % CCom.size()]
				Zone.OfficeIndustry:
					baseColor = CInd[rng.randi() % CInd.size()]
				_:
					baseColor = Color.WHITE

			zones[row][col] = zone
			colors[row][col] = baseColor

			if (zone == Zone.Park or zone == Zone.OfficeIndustry) \
					and rng.randf() <= (0.95 if zone == Zone.Park else 0.80):
				var mergeLimit: int = 7 if zone == Zone.Park else 1
				var maxCol: int = col
				while maxCol + 1 < Cols and maxCol - col < mergeLimit:
					var nextCol: int = maxCol + 1
					if zones[row][nextCol] != null:
						break
					var ndx: float = nextCol - centerCol
					var ndy: float = row - centerRow
					var dist2: float = sqrt(ndx * ndx + ndy * ndy)
					if not _isInsideCity(nextCol, row) or (zone == Zone.Park and dist2 < comCore):
						break
					if zone == Zone.Park and rng.randf() < (maxCol - col + 1) * 0.15:
						break
					maxCol += 1
				var maxRow: int = row
				while maxRow + 1 < Rows and maxRow - row < mergeLimit:
					var ok: bool = true
					for c2 in range(col, maxCol + 1):
						if zones[maxRow + 1][c2] != null:
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
							zones[r][c2] = zone
							colors[r][c2] = baseColor
							parcelOwner[r][c2] = Vector2i(col, row)
					parcelExtent[row][col] = Vector2i(maxCol, maxRow)

	for row in Rows:
		var detailRow: Array = []
		for col in Cols:
			if parcelOwner[row][col] != Vector2i(col, row):
				detailRow.append({})
				continue
			var dx: float = col - centerCol
			var dy: float = row - centerRow
			var dist: float = sqrt(dx * dx + dy * dy)
			var zone: Zone = zones[row][col]
			var isOffice: bool = (zone == Zone.OfficeIndustry and dist < comCore)
			var nearCommercial: bool = false
			if zone == Zone.Residential:
				var neighbors: Array[Vector2i] = [
					Vector2i(col - 1, row), Vector2i(col + 1, row),
					Vector2i(col, row - 1), Vector2i(col, row + 1),
				]
				for neighbor: Vector2i in neighbors:
					if neighbor.x >= 0 and neighbor.x < Cols \
							and neighbor.y >= 0 and neighbor.y < Rows \
							and zones[neighbor.y][neighbor.x] == Zone.Commercial:
						nearCommercial = true
						break
			var effectiveDist: float = dist
			for cbd: Dictionary in _secondaryCbds:
				var secDist: float = _secondaryCbdDist(col, row, cbd)
				if secDist < cbd.fringeR:
					effectiveDist = min(effectiveDist,
							secDist * 5.5 / max(0.01, cbd.fringeR))
					if zone == Zone.OfficeIndustry and secDist < cbd.coreR:
						isOffice = true
					break
			detailRow.append(_genDetails(
					zone, colors[row][col], mergedBlockRect(col, row),
					effectiveDist, isOffice, nearCommercial))
		details.append(detailRow)


func blockRect(col: int, row: int) -> Rect2:
	return Rect2(_colXPositions[col], _rowYPositions[row], colWidths[col], rowHeights[row])


func mergedBlockRect(col: int, row: int) -> Rect2:
	var extent: Vector2i = parcelExtent[row][col]
	var x: float = _colXPositions[col]
	var y: float = _rowYPositions[row]
	var w: float = _colXPositions[extent.x] + colWidths[extent.x] - x
	var h: float = _rowYPositions[extent.y] + rowHeights[extent.y] - y
	return Rect2(x, y, w, h)


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


func _generateSecondaryCbds() -> void:
	_secondaryCbds.clear()
	var count: int = rng.randi_range(0, 5)
	if count == 0:
		return
	var arterialCols: Array[int] = []
	var arterialRows: Array[int] = []
	for c in range(1, Cols):
		if vertStreetWidths[c] >= WArterial:
			arterialCols.append(c)
	for r in range(1, Rows):
		if horzStreetWidths[r] >= WArterial:
			arterialRows.append(r)
	if arterialCols.is_empty() and arterialRows.is_empty():
		return
	var centerCol: float = (Cols - 1) / 2.0
	var centerRow: float = (Rows - 1) / 2.0
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
				center = Vector2(rng.randf_range(8.0, Cols - 9.0), rowIdx - 0.5)
				angle = 0.0
			else:
				var colIdx: int = arterialCols[rng.randi() % arterialCols.size()]
				center = Vector2(colIdx - 0.5, rng.randf_range(6.0, Rows - 7.0))
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
						rng.randf_range(5.0, Rows - 6.0))
			else:
				var rowIdx: int = arterialRows[rng.randi() % arterialRows.size()]
				center = Vector2(rng.randf_range(5.0, Cols - 6.0),
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
		var cbdCol: int = clamp(int(round(center.x)), 0, Cols - 1)
		var cbdRow: int = clamp(int(round(center.y)), 0, Rows - 1)
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
	var centerCol: float = (Cols - 1) / 2.0
	var centerRow: float = (Rows - 1) / 2.0
	var dx: float = (col - centerCol) / (Cols / 2.0)
	var dy: float = (row - centerRow) / (Rows / 2.0)
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


func _genDetails(zone: Zone, _color: Color, rect: Rect2, dist: float = 0.0,
		isOffice: bool = false, nearCommercial: bool = false) -> Dictionary:
	var tileScale: float = sqrt(rect.get_area()) / 7.5
	var result: Dictionary = {}

	match zone:
		Zone.Park:
			var trees: Array = []
			for _i in rng.randi_range(
					max(1, int(2.0 * tileScale)), max(1, int(6.0 * tileScale))):
				trees.append({
					"p": Vector2(
						rect.position.x + rng.randf_range(3.0, max(3.0, rect.size.x - 3.0)),
						rect.position.y + rng.randf_range(3.0, max(3.0, rect.size.y - 3.0))),
					"r": rng.randf_range(1.5, 4.0),
				})
			result["trees"] = trees

		Zone.Residential:
			var floors: int
			if dist < 3.0:
				floors = rng.randi_range(6, 10)
			elif dist < 6.0:
				if nearCommercial and rng.randf() < 0.50:
					floors = rng.randi_range(6, 10)
				elif rng.randf() < 0.08:
					floors = rng.randi_range(6, 10)
				else:
					floors = rng.randi_range(3, 5)
			else:
				if nearCommercial and rng.randf() < 0.50:
					floors = rng.randi_range(6, 10)
				elif rng.randf() < 0.05:
					floors = rng.randi_range(6, 10)
				else:
					floors = 1
			result["density"] = floors
			var buildings: Array = []
			if floors == 1:
				for _i in rng.randi_range(
						max(1, int(1.0 * tileScale)), max(1, int(3.0 * tileScale))):
					var bldWidth: float = rng.randf_range(
							5.0, max(5.0, min(9.0, rect.size.x * 0.28)))
					var bldHeight: float = rng.randf_range(
							6.0, max(6.0, min(10.0, rect.size.y * 0.28)))
					buildings.append(Rect2(
						rect.position.x + rng.randf_range(
								0.5, max(0.5, rect.size.x - bldWidth - 0.5)),
						rect.position.y + rng.randf_range(
								0.5, max(0.5, rect.size.y - bldHeight - 0.5)),
						bldWidth, bldHeight))
			else:
				var towerHeight: float = min(float(floors) * 2.7 + 1.5, rect.size.y - 4.0)
				for _i in rng.randi_range(
						max(1, int(1.0 * tileScale)), max(1, int(3.0 * tileScale))):
					var bldWidth: float = rng.randf_range(3.5, min(8.0, rect.size.x * 0.28))
					buildings.append(Rect2(
						rect.position.x + rng.randf_range(
								2.0, max(2.0, rect.size.x - bldWidth - 2.0)),
						rect.position.y + rng.randf_range(
								2.0, max(2.0, rect.size.y - towerHeight - 2.0)),
						bldWidth, towerHeight))
			result["blds"] = buildings

		Zone.Commercial:
			var buildings: Array = []
			for _i in rng.randi_range(
					max(1, int(1.0 * tileScale)), max(1, int(2.0 * tileScale))):
				var bldWidth: float = rng.randf_range(6.0, min(18.0, rect.size.x * 0.55))
				var bldHeight: float = rng.randf_range(
						4.0, min(rect.size.y * 0.80, rect.size.y - 3.0))
				buildings.append(Rect2(
					rect.position.x + rng.randf_range(
							1.5, max(1.5, rect.size.x - bldWidth - 1.5)),
					rect.position.y + rng.randf_range(
							1.5, max(1.5, rect.size.y - bldHeight - 1.5)),
					bldWidth, bldHeight))
			result["blds"] = buildings

		Zone.OfficeIndustry:
			var buildings: Array = []
			for _i in rng.randi_range(
					max(1, int(1.0 * tileScale)), max(1, int(2.0 * tileScale))):
				var bldWidth: float = rng.randf_range(9.0, min(27.0, rect.size.x * 0.70))
				var bldHeight: float = rng.randf_range(5.5, min(20.0, rect.size.y * 0.60))
				buildings.append(Rect2(
					rect.position.x + rng.randf_range(
							1.5, max(1.5, rect.size.x - bldWidth - 1.5)),
					rect.position.y + rng.randf_range(
							1.5, max(1.5, rect.size.y - bldHeight - 1.5)),
					bldWidth, bldHeight))
			result["blds"] = buildings

	return result
