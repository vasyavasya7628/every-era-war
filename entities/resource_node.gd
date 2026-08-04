class_name ResourceNode
extends Node2D

## A gatherable resource object placed on the map.
## Resources are infinite — they never deplete, but limit concurrent gatherers.

var resource_type: GameData.ResourceType = GameData.ResourceType.WOOD
var tile_position: Vector2i = Vector2i.ZERO
var current_gatherers: int = 0
var max_gatherers: int = 3

func _ready() -> void:
	z_index = 3
	add_to_group("resources")

func can_gather() -> bool:
	return current_gatherers < max_gatherers

func start_gather() -> void:
	current_gatherers += 1

func finish_gather() -> void:
	current_gatherers = max(current_gatherers - 1, 0)

func _draw() -> void:
	var half := World.TILE_SIZE / 2.0
	var col: Color = GameData.RESOURCE_COLORS.get(resource_type, Color.WHITE)

	# Simple Drop Shadow
	draw_ellipse(Vector2(half + 1, half + 3), 4.5, 2.0, Color(0, 0, 0, 0.35))

	match resource_type:
		GameData.ResourceType.WOOD:
			# Tiny tree: brown trunk + green triangle canopy
			draw_rect(Rect2(half - 1, half + 1, 2, 4), Color("5c3a1e"))        # trunk
			draw_colored_polygon(                                                # canopy
				PackedVector2Array([
					Vector2(half, half - 4),
					Vector2(half - 4, half + 1),
					Vector2(half + 4, half + 1),
				]),
				col
			)
		GameData.ResourceType.GOLD:
			# Yellow diamond shape
			draw_colored_polygon(
				PackedVector2Array([
					Vector2(half, half - 3),
					Vector2(half + 3, half),
					Vector2(half, half + 3),
					Vector2(half - 3, half),
				]),
				col
			)
		GameData.ResourceType.ORE:
			# Grey irregular rectangle with notch
			draw_rect(Rect2(half - 3, half - 1, 6, 3), col)
			draw_rect(Rect2(half + 1, half - 2, 2, 1), col.lightened(0.3))
		GameData.ResourceType.STONE:
			# Brown square with lighter accent
			draw_rect(Rect2(half - 2, half - 2, 5, 5), col)
			draw_rect(Rect2(half, half - 1, 2, 2), col.lightened(0.25))

static func create(type: GameData.ResourceType, tile_pos: Vector2i, tile_size: int) -> ResourceNode:
	var node := ResourceNode.new()
	node.resource_type = type
	node.tile_position = tile_pos
	node.position = Vector2(tile_pos.x * tile_size, tile_pos.y * tile_size)
	return node
