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
