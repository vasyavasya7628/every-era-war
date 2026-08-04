class_name UnitSpawner
extends Node

## Handles spawning units on player mouse click.

var world: World = null
var player_faction: Faction = null
var is_spawn_mode: bool = false

signal unit_spawned(unit: Unit)

func activate() -> void:
	is_spawn_mode = true

func deactivate() -> void:
	is_spawn_mode = false

func toggle() -> void:
	is_spawn_mode = not is_spawn_mode

func _unhandled_input(event: InputEvent) -> void:
	if not is_spawn_mode:
		return
	if world == null:
		return

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var mouse_world_pos: Vector2 = world.get_global_mouse_position()
		var tile_coords: Vector2i = world.world_to_tile(mouse_world_pos)

		# Validate: must be on a PLAIN tile within the map
		if not world.is_valid_coords(tile_coords):
			return
		if world.grid[tile_coords.x][tile_coords.y] != World.TerrainType.PLAIN:
			return

		# Spawn unit at the clicked position
		var unit := Unit.create(player_faction, mouse_world_pos, world)
		world.add_child(unit)
		if player_faction != null:
			player_faction.units.append(unit)

		var gm = world.get_node_or_null("GameManager")
		if gm != null and gm.has_method("register_unit"):
			gm.register_unit(unit)

		unit_spawned.emit(unit)
		get_viewport().set_input_as_handled()
