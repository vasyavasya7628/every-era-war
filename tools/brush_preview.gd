class_name BrushPreview
extends Node2D

var tile_coords: Vector2i = Vector2i.ZERO
var brush_size: int = 1
var is_valid: bool = false
var tile_size: float = 16.0

func update_preview(coords: Vector2i, size: int, valid: bool) -> void:
	tile_coords = coords
	brush_size = size
	is_valid = valid
	queue_redraw()

func _draw() -> void:
	if not is_valid:
		return
		
	var extents := brush_size - 1
	var min_cell := tile_coords - Vector2i(extents, extents)
	var diameter := brush_size * 2 - 1
	
	var rect_pos := Vector2(min_cell.x * tile_size, min_cell.y * tile_size)
	var rect_size := Vector2(diameter * tile_size, diameter * tile_size)
	
	# Semi-transparent fill
	draw_rect(Rect2(rect_pos, rect_size), Color(1, 1, 1, 0.25))
	# Highlight yellow border
	draw_rect(Rect2(rect_pos, rect_size), Color(1, 0.9, 0.2, 0.9), false, 2.0)
