class_name TerritoryOverlay
extends Node2D

## Draws territory borders for all factions as colored circles.

var factions: Array = []
var tile_size: int = 16

func _ready() -> void:
	z_index = 2  # Above terrain, below resources and buildings

func _process(_delta: float) -> void:
	# Redraw territory borders every 30 frames to avoid excessive draw calls
	if Engine.get_process_frames() % 30 == 0:
		queue_redraw()

func _draw() -> void:
	for faction in factions:
		if faction == null or not is_instance_valid(faction):
			continue
		if faction.units.size() == 0 and faction.buildings.size() == 0:
			continue

		var center := Vector2(
			faction.territory_center.x * tile_size + tile_size / 2.0,
			faction.territory_center.y * tile_size + tile_size / 2.0
		)
		var radius: float = faction.territory_radius * tile_size

		# Draw filled territory circle (very transparent)
		var fill_col := Color(faction.faction_color.r, faction.faction_color.g, faction.faction_color.b, 0.06)
		draw_circle(center, radius, fill_col)

		# Draw territory border ring
		var border_col := Color(faction.faction_color.r, faction.faction_color.g, faction.faction_color.b, 0.35)
		_draw_circle_outline(center, radius, border_col, 1.5)

func _draw_circle_outline(center: Vector2, radius: float, color: Color, width: float) -> void:
	var points: int = 48
	var prev := center + Vector2(radius, 0)
	for i in range(1, points + 1):
		var angle: float = TAU * i / points
		var next := center + Vector2(cos(angle) * radius, sin(angle) * radius)
		draw_line(prev, next, color, width)
		prev = next
