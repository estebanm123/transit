class_name CityLayer extends Node2D

const ViewModeLandUse: int = 0
const ViewModeCommuteHeatmap: int = 1
const HeatmapLowColor: Color = Palette.CRed
const HeatmapMidColor: Color = Palette.CAmber
const HeatmapHighColor: Color = Palette.CGreenBright
const HeatmapLandUseMix: float = 0.45

var _city: City
var _viewMode: int = ViewModeLandUse


func setup(city: City) -> void:
	_city = city
	queue_redraw()


func setViewMode(viewMode: int) -> void:
	if _viewMode == viewMode:
		return
	_viewMode = viewMode
	queue_redraw()


func _draw() -> void:
	if _city == null:
		return
	draw_rect(Rect2(0, 0, City.MapW, City.MapH), City.CCountryside)
	_drawParcels()


func _drawParcels() -> void:
	for row in City.Rows:
		for col in City.Cols:
			var zone: int = _city.zones[row][col]
			if zone == Zone.Empty:
				continue
			if _city.parcelOwner[row][col] != Vector2i(col, row):
				continue
			var extent: Vector2i = _city.parcelExtent[row][col]
			var rect: Rect2 = _city.mergedBlockRect(col, row)
			var streetLeft: float = _city.vertStreetWidths[col]
			var streetRight: float = _city.vertStreetWidths[extent.x + 1]
			var streetTop: float = _city.horzStreetWidths[row]
			var streetBottom: float = _city.horzStreetWidths[extent.y + 1]
			draw_rect(Rect2(rect.position.x - streetLeft, rect.position.y - streetTop,
					rect.size.x + streetLeft + streetRight,
					rect.size.y + streetTop + streetBottom), City.CStreet)
			var color: Color = _getParcelColor(col, row)
			draw_rect(rect, color)


func _getParcelColor(col: int, row: int) -> Color:
	if _viewMode == ViewModeLandUse:
		return _city.colors[row][col]
	var profile: City.TileCommuteProfile = _city.getCommuteProfile(col, row)
	if profile == null:
		return _city.colors[row][col].lerp(City.CStreet, HeatmapLandUseMix)
	return _getHeatmapColor(City.getTileCommuteHappiness(profile) / 10.0)


func _getHeatmapColor(normalizedHappiness: float) -> Color:
	var clampedHappiness: float = clampf(normalizedHappiness, 0.0, 1.0)
	if clampedHappiness <= 0.5:
		return HeatmapLowColor.lerp(HeatmapMidColor, clampedHappiness * 2.0)
	return HeatmapMidColor.lerp(
			HeatmapHighColor, (clampedHappiness - 0.5) * 2.0)
