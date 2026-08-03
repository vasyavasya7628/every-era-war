class_name BuildingPlacer
extends Node2D

## Allows the player to place building blueprints on the grid.
## Shows a ghost preview that follows the mouse, validates placement,
## and creates the building on click.

var world: World = null
var player_faction: Faction = null
var is_placing: bool = false
var selected_type: GameData.BuildingType = GameData.BuildingType.HOUSE
var ghost_position: Vector2i = Vector2i.ZERO
var is_valid_placement: bool = false

signal building_placed(building: Building)

func _ready() -> void:
	z_index = 20  # Ghost renders above everything

func start_placement(type: GameData.BuildingType) -> void:
	selected_type = type
	is_placing = true

func cancel_placement() -> void:
	is_placing = false
	queue_redraw()

func _process(_delta: float) -> void:
	if not is_placing or world == null:
		return
	var mouse_world_pos: Vector2 = world.get_global_mouse_position()
	ghost_position = world.world_to_tile(mouse_world_pos)
	is_valid_placement = _check_placement(ghost_position)
	queue_redraw()

func _unhandled_input(event: InputEvent) -> void:
	if not is_placing:
		return

	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if is_valid_placement and player_faction != null:
				var def: Dictionary = GameData.BUILDING_DEFS[selected_type]
				var cost: Dictionary = def["cost"]
				if player_faction.spend_resources(cost):
					var bld := Building.create(selected_type, player_faction, ghost_position, World.TILE_SIZE)
					world.add_child(bld)
					player_faction.buildings.append(bld)
					world.register_building_tiles(bld)
					building_placed.emit(bld)
					is_placing = false
					queue_redraw()
			get_viewport().set_input_as_handled()

		elif event.button_index == MOUSE_BUTTON_RIGHT:
			cancel_placement()
			get_viewport().set_input_as_handled()

func _check_placement(tile: Vector2i) -> bool:
	if world == null or player_faction == null:
		return false

	var def: Dictionary = GameData.BUILDING_DEFS[selected_type]
	var bsize: Vector2i = def["size"]

	# Check cost affordability
	if not player_faction.can_afford(def["cost"]):
		return false

	# Check every tile the building would occupy
	for dx in range(bsize.x):
		for dy in range(bsize.y):
			var check_tile := Vector2i(tile.x + dx, tile.y + dy)

			# Must be within map bounds
			if not world.is_valid_coords(check_tile):
				return false

			# Must be PLAIN terrain
			if world.grid[check_tile.x][check_tile.y] != World.TerrainType.PLAIN:
				return false

			# Must be within faction territory
			if not player_faction.is_in_territory(check_tile):
				return false

			# Must not overlap existing buildings
			if world.is_tile_occupied(check_tile):
				return false

	return true

func _draw() -> void:
	if not is_placing:
		return

	var def: Dictionary = GameData.BUILDING_DEFS[selected_type]
	var bsize: Vector2i = def["size"]
	var ts: float = World.TILE_SIZE

	var rect_pos := Vector2(ghost_position.x * ts, ghost_position.y * ts)
	var rect_size := Vector2(bsize.x * ts, bsize.y * ts)

	if is_valid_placement:
		# Green ghost
		draw_rect(Rect2(rect_pos, rect_size), Color(0, 1, 0, 0.25))
		draw_rect(Rect2(rect_pos, rect_size), Color(0, 1, 0, 0.7), false, 1.5)
	else:
		# Red ghost
		draw_rect(Rect2(rect_pos, rect_size), Color(1, 0, 0, 0.25))
		draw_rect(Rect2(rect_pos, rect_size), Color(1, 0, 0, 0.7), false, 1.5)
