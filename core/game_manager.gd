class_name GameManager
extends Node

# ─── References ──────────────────────────────────────────────────────
var world: World = null
var factions: Array = []   # Array of Faction nodes (dynamically created)

# ─── Territory Expansion ─────────────────────────────────────────────
var territory_expand_timer: float = 0.0

# ─── Game State ──────────────────────────────────────────────────────
var game_started: bool = false

# ─── Pending Units (spawned but not yet in a faction) ────────────────
## Units that have been spawned but are waiting for a partner to form a faction.
var pending_units: Array = []

# ─── Faction-formation state machine ─────────────────────────────────
## Tracks which factions are still in the "auto-gather + build" startup phase.
## Value: "gather" | "build" | "done"
var faction_phase: Dictionary = {}   # Faction -> String

# Used to assign incrementing faction IDs
var _next_faction_id: int = 0

signal faction_formed(faction: Faction)

func initialize(world_ref: World) -> void:
	world = world_ref
	game_started = true

# ─── Unit Registration (called from UnitSpawner) ─────────────────────

## Called each time the player spawns a new human.
## Checks if the new unit is close enough to an existing pending unit to form a faction.
func register_unit(unit: Unit) -> void:
	# Clean up freed references first
	pending_units = pending_units.filter(func(u): return u != null and is_instance_valid(u))

	# Check against existing pending units for proximity pairing
	for existing in pending_units:
		if unit.global_position.distance_to(existing.global_position) <= GameData.PAIR_DISTANCE:
			# Form a faction between existing (leader) and new unit (follower)
			_form_faction(existing, unit)
			pending_units.erase(existing)
			return

	# No nearby partner — add to pending list; this unit will form a lone faction
	# Give solo humans their own solo faction immediately so they can act
	_form_solo_faction(unit)

## Creates a faction for a lone unit (no partner nearby).
func _form_solo_faction(unit: Unit) -> void:
	var col := Color.from_hsv(randf(), 0.7, 0.9)
	var center_tile := world.world_to_tile(unit.global_position)
	center_tile = _find_nearest_plain(center_tile)

	var faction := Faction.create(_next_faction_id, "Tribe %d" % _next_faction_id, col, center_tile, true)
	_next_faction_id += 1
	world.add_child(faction)
	factions.append(faction)

	# Assign unit to faction
	unit.faction = faction
	faction.units.append(unit)
	faction.leader = unit
	unit.is_leader = true

	# Begin gather phase
	faction_phase[faction] = "gather"
	faction_formed.emit(faction)

## Creates a two-member faction: leader = first_unit, follower = second_unit.
func _form_faction(leader_unit: Unit, follower_unit: Unit) -> void:
	var col := Color.from_hsv(randf(), 0.7, 0.9)

	# Territory center = midpoint between the two units
	var mid := (leader_unit.global_position + follower_unit.global_position) / 2.0
	var center_tile := world.world_to_tile(mid)
	center_tile = _find_nearest_plain(center_tile)

	var faction := Faction.create(_next_faction_id, "Tribe %d" % _next_faction_id, col, center_tile, true)
	_next_faction_id += 1
	world.add_child(faction)
	factions.append(faction)

	# Assign units — first spawned is leader
	faction.leader = leader_unit
	leader_unit.is_leader = true
	follower_unit.is_leader = false

	for u in [leader_unit, follower_unit]:
		u.faction = faction
		faction.units.append(u)
		u.queue_redraw()

	# Both units: set the follower's leader reference
	follower_unit.leader_ref = leader_unit

	# Begin gather phase for this faction
	faction_phase[faction] = "gather"
	faction_formed.emit(faction)

# ─── Game Loop ───────────────────────────────────────────────────────

func _process(delta: float) -> void:
	if not game_started:
		return

	# Territory auto-expansion tick
	territory_expand_timer += delta
	if territory_expand_timer >= GameData.TERRITORY_EXPAND_INTERVAL:
		territory_expand_timer = 0.0
		for faction in factions:
			if faction.units.size() > 0 or faction.buildings.size() > 0:
				faction.expand_territory()

	# Process each faction's startup phase
	for faction in factions:
		_process_faction_phase(faction)

	# Clean up dead units/buildings
	_cleanup_factions()

func _process_faction_phase(faction: Faction) -> void:
	if not faction_phase.has(faction):
		return
	var phase: String = faction_phase[faction]

	match phase:
		"gather":
			_process_gather_phase(faction)
		"build":
			_process_build_phase(faction)
		# "done" means normal AI takes over — no special processing needed

func _process_gather_phase(faction: Faction) -> void:
	# Check if enough wood has been gathered
	if faction.get_resource(GameData.ResourceType.WOOD) >= GameData.INITIAL_WOOD_GATHER:
		faction_phase[faction] = "build"
		# Switch all units to idle so the build phase can assign them
		for unit in faction.units:
			if unit != null and is_instance_valid(unit):
				unit.target_resource = null
				unit.is_working = false
				unit._set_role(GameData.UnitRole.IDLE)
		return

	# Make sure all units are gathering wood
	for unit in faction.units:
		if unit == null or not is_instance_valid(unit):
			continue
		if unit.role != GameData.UnitRole.GATHERER:
			unit._set_role(GameData.UnitRole.GATHERER)

func _process_build_phase(faction: Faction) -> void:
	# Check if town centre already placed
	if faction.has_construction_sites() or faction.get_completed_buildings_of_type(GameData.BuildingType.TOWN_CENTRE).size() > 0:
		# Either still building or already built
		if faction.get_completed_buildings_of_type(GameData.BuildingType.TOWN_CENTRE).size() > 0:
			# Done! Seed territory and hand off to normal AI
			if faction.territory_tiles.size() <= 1:
				_seed_initial_territory(faction)
			faction_phase[faction] = "done"
		return

	# Place town centre at territory center
	var tc_tile := faction.territory_center
	# Find a valid 2x2 spot near the territory center
	var build_tile := _find_tc_spot(tc_tile)
	if build_tile == Vector2i(-1, -1):
		return  # No valid spot yet — wait

	var tc := Building.create(
		GameData.BuildingType.TOWN_CENTRE,
		faction,
		build_tile,
		World.TILE_SIZE
	)
	world.add_child(tc)
	faction.buildings.append(tc)
	world.register_building_tiles(tc)

	# Assign builder units
	for unit in faction.units:
		if unit != null and is_instance_valid(unit):
			unit.target_building = tc
			unit._set_role(GameData.UnitRole.BUILDER)

func _find_tc_spot(center: Vector2i) -> Vector2i:
	# Spiral search for a 2x2 buildable area
	for radius in range(0, 15):
		for dx in range(-radius, radius + 1):
			for dy in range(-radius, radius + 1):
				if abs(dx) != radius and abs(dy) != radius:
					continue
				var tile := Vector2i(center.x + dx, center.y + dy)
				if _is_valid_tc_spot(tile):
					return tile
	return Vector2i(-1, -1)

func _is_valid_tc_spot(tile: Vector2i) -> bool:
	for dx in range(2):
		for dy in range(2):
			var check := Vector2i(tile.x + dx, tile.y + dy)
			if not world.is_valid_coords(check):
				return false
			if world.grid[check.x][check.y] != World.TerrainType.PLAIN:
				return false
			if world.is_tile_occupied(check):
				return false
	return true

# ─── Territory Seeding ───────────────────────────────────────────────

func _seed_initial_territory(faction: Faction) -> void:
	var radius: int = GameData.INITIAL_TERRITORY_RADIUS
	var queue: Array = [faction.territory_center]
	var visited: Dictionary = {}
	visited[faction.territory_center] = true
	faction.territory_tiles[faction.territory_center] = true
	var dirs := [Vector2i(1,0), Vector2i(-1,0), Vector2i(0,1), Vector2i(0,-1)]
	while queue.size() > 0:
		var current: Vector2i = queue.pop_front()
		for d in dirs:
			var neighbor: Vector2i = current + d
			if visited.has(neighbor):
				continue
			visited[neighbor] = true
			if not world.is_valid_coords(neighbor):
				continue
			if not world.is_land_tile(neighbor):
				continue
			if neighbor.distance_to(faction.territory_center) > radius:
				continue
			faction.territory_tiles[neighbor] = true
			queue.append(neighbor)

# ─── Cleanup ─────────────────────────────────────────────────────────

func _cleanup_factions() -> void:
	for faction in factions:
		faction.units = faction.units.filter(func(u): return u != null and is_instance_valid(u))
		faction.buildings = faction.buildings.filter(func(b): return b != null and is_instance_valid(b))

# ─── Helpers ─────────────────────────────────────────────────────────

func _find_nearest_plain(center: Vector2i) -> Vector2i:
	if _is_plain(center):
		return center
	for radius in range(1, 30):
		for dx in range(-radius, radius + 1):
			for dy in range(-radius, radius + 1):
				if abs(dx) != radius and abs(dy) != radius:
					continue
				var test := Vector2i(center.x + dx, center.y + dy)
				if _is_plain(test):
					return test
	return center

func _is_plain(tile: Vector2i) -> bool:
	if not world.is_valid_coords(tile):
		return false
	return world.grid[tile.x][tile.y] == World.TerrainType.PLAIN

## Kill a unit and remove it from its faction.
func kill_unit(faction: Faction, unit: Unit) -> void:
	if unit == null or not is_instance_valid(unit):
		return
	if faction != null:
		faction.remove_unit(unit)
	unit.queue_free()
