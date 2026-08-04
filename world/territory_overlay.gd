class_name TerritoryOverlay
extends Node2D

## Draws territory as individual colored tiles for each faction.

var factions: Array = []
var tile_size: int = 16

func _ready() -> void:
	z_index = 2  # Above terrain, below resources and buildings

func _process(_delta: float) -> void:
	# Redraw territory tiles every 30 frames to avoid excessive draw calls
	if Engine.get_process_frames() % 30 == 0:
		queue_redraw()

func _draw() -> void:
	for faction in factions:
		if faction == null or not is_instance_valid(faction):
			continue
		if faction.territory_tiles.is_empty():
			continue

		var col: Color = faction.faction_color
		var fill_col := Color(col.r, col.g, col.b, 0.12)
		var border_col := Color(col.r, col.g, col.b, 0.45)
		var ts := float(tile_size)

		for tile in faction.territory_tiles:
			var tile_v := tile as Vector2i
			var rect := Rect2(tile_v.x * ts, tile_v.y * ts, ts, ts)

			# Filled tile background
			draw_rect(rect, fill_col)

			# Only draw border edges where this faction doesn't own the neighbour
			# (creates clean inner-boundary lines rather than grid lines everywhere)
			var top    := Vector2i(tile_v.x,     tile_v.y - 1)
			var bottom := Vector2i(tile_v.x,     tile_v.y + 1)
			var left   := Vector2i(tile_v.x - 1, tile_v.y)
			var right  := Vector2i(tile_v.x + 1, tile_v.y)

			var x0 := tile_v.x * ts
			var y0 := tile_v.y * ts
			var x1 := x0 + ts
			var y1 := y0 + ts

			if not faction.territory_tiles.has(top):
				draw_line(Vector2(x0, y0), Vector2(x1, y0), border_col, 1.0)
			if not faction.territory_tiles.has(bottom):
				draw_line(Vector2(x0, y1), Vector2(x1, y1), border_col, 1.0)
			if not faction.territory_tiles.has(left):
				draw_line(Vector2(x0, y0), Vector2(x0, y1), border_col, 1.0)
			if not faction.territory_tiles.has(right):
				draw_line(Vector2(x1, y0), Vector2(x1, y1), border_col, 1.0)
