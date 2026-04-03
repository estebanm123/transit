class_name CityLayer extends Node2D

var _city: City


func setup(city: City) -> void:
	_city = city
	queue_redraw()


func _draw() -> void:
	if _city == null:
		return
	draw_rect(Rect2(0, 0, City.MapW, City.MapH), City.CCountryside)

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
			var color: Color = _city.colors[row][col]
			draw_rect(rect, color)
			_drawZoneDetail(zone, color, _city.details[row][col])


func _drawZoneDetail(zone: int, color: Color, det: Dictionary) -> void:
	match zone:
		Zone.Park:
			for p: Rect2 in det.get("paths", []):
				draw_rect(p, color.darkened(0.20))
			for t2 in det.get("trees", []):
				draw_circle(t2["p"], t2["r"], color.darkened(0.30))
				draw_circle(t2["p"], t2["r"] * 0.55, color.lightened(0.10))

		Zone.Residential:
			var density: int = det.get("density", 3)
			for bld: Rect2 in det.get("blds", []):
				if density == 1:
					var roofBaseY: float = bld.position.y + bld.size.y * 0.42
					var bodyHeight: float = bld.size.y * 0.58
					draw_colored_polygon(PackedVector2Array([
						Vector2(bld.position.x - 1.0, roofBaseY),
						Vector2(bld.end.x + 1.0, roofBaseY),
						Vector2(bld.position.x + bld.size.x * 0.5, bld.position.y),
					]), color.darkened(0.22))
					draw_rect(Rect2(bld.position.x, roofBaseY, bld.size.x, bodyHeight),
							color.darkened(0.38))
					var doorWidth: float = bld.size.x * 0.28
					draw_rect(Rect2(bld.position.x + (bld.size.x - doorWidth) * 0.5,
							bld.end.y - bodyHeight * 0.45, doorWidth, bodyHeight * 0.45),
							color.darkened(0.60))
				else:
					draw_rect(bld, color.darkened(0.38))
					var floors: int = density
					var floorHeight: float = bld.size.y / floors
					var windowColor: Color = color.lightened(0.32)
					for f in floors:
						var floorY: float = bld.position.y + f * floorHeight + 1.5
						var windowHeight: float = max(2.0, floorHeight - 3.5)
						var winX: float = bld.position.x + 2.0
						while winX + 3.5 < bld.end.x - 1.5:
							draw_rect(Rect2(winX, floorY, 3.5, windowHeight), windowColor)
							winX += 6.0

		Zone.Commercial:
			for bld: Rect2 in det.get("blds", []):
				draw_rect(bld, color.darkened(0.44))

		Zone.OfficeIndustry:
			for bld: Rect2 in det.get("blds", []):
				draw_rect(bld, color.darkened(0.30))
