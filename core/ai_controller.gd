class_name AIController
extends Node

## Controls an AI faction's economy, building, and military decisions.
## Attached to each non-player faction.

var faction: Faction = null
var world: World = null

# Timers
var spawn_timer: float = 0.0
var build_timer: float = 0.0
var think_timer: float = 0.0

# Build priorities: House → Mine → Forge
const BUILD_PRIORITY: Array = [
	GameData.BuildingType.HOUSE,
	GameData.BuildingType.MINE,
	GameData.BuildingType.FORGE,
]

func _ready() -> void:
	# Stagger AI thinking to avoid all factions thinking on the same frame
	think_timer = randf_range(0.0, 5.0)
	build_timer = randf_range(3.0, 10.0)

func initialize(f: Faction, w: World) -> void:
	faction = f
	world = w

func _process(delta: float) -> void:
	if faction == null or world == null:
		return
	if faction.units.size() == 0 and faction.buildings.size() == 0:
		return  # Faction is defeated

	# ── Spawn units periodically ──
	spawn_timer += delta
	if spawn_timer >= GameData.AI_SPAWN_INTERVAL:
		spawn_timer = 0.0
		_spawn_unit()

	# ── Building decisions ──
	build_timer += delta
	if build_timer >= 8.0:  # Check every 8 seconds
		build_timer = 0.0
		_try_build()

	# ── Maintain warrior ratio ──
	think_timer += delta
	if think_timer >= 5.0:
		think_timer = 0.0
		_manage_warriors()

# ─── Unit Spawning ───────────────────────────────────────────────────

func _spawn_unit() -> void:
	# Spawn a unit near the faction's town centre
	var center_world := world.tile_to_world(faction.territory_center)
	var offset := Vector2(randf_range(-24, 24), randf_range(-24, 24))
	var spawn_pos := center_world + Vector2(World.TILE_SIZE, World.TILE_SIZE) + offset

	# Verify spawn position is on PLAIN terrain
	var spawn_tile := world.world_to_tile(spawn_pos)
	if not world.is_valid_coords(spawn_tile):
		return
	if world.grid[spawn_tile.x][spawn_tile.y] != World.TerrainType.PLAIN:
		return

	var unit := Unit.create(faction, spawn_pos, world)
	world.add_child(unit)
	faction.units.append(unit)

# ─── Building Decisions ──────────────────────────────────────────────

func _try_build() -> void:
	# Don't build if there are already construction sites (let workers finish first)
	if faction.has_construction_sites():
		return

	# Try each building type in priority order
	for btype in BUILD_PRIORITY:
		var def: Dictionary = GameData.BUILDING_DEFS[btype]
		var cost: Dictionary = def["cost"]

		if not faction.can_afford(cost):
			continue

		# Find a valid tile within territory
		var tile := _find_build_spot(def["size"])
		if tile == Vector2i(-1, -1):
			continue

		# Spend resources and place building
		if faction.spend_resources(cost):
			var bld := Building.create(btype, faction, tile, World.TILE_SIZE)
			world.add_child(bld)
			faction.buildings.append(bld)
			world.register_building_tiles(bld)
			return  # Only build one at a time

func _find_build_spot(bsize: Vector2i) -> Vector2i:
	# Pick random tiles from territory_tiles dict and test each for validity
	var tiles: Array = faction.territory_tiles.keys()
	if tiles.is_empty():
		return Vector2i(-1, -1)
	for _attempt in range(30):
		var tile: Vector2i = tiles[randi() % tiles.size()]
		if _is_valid_build_spot(tile, bsize):
			return tile
	return Vector2i(-1, -1)  # No valid spot found

func _is_valid_build_spot(tile: Vector2i, bsize: Vector2i) -> bool:
	for dx in range(bsize.x):
		for dy in range(bsize.y):
			var check := Vector2i(tile.x + dx, tile.y + dy)
			if not world.is_valid_coords(check):
				return false
			if world.grid[check.x][check.y] != World.TerrainType.PLAIN:
				return false
			if not faction.is_in_territory(check):
				return false
			if world.is_tile_occupied(check):
				return false
	return true

# ─── Warrior Management ─────────────────────────────────────────────

func _manage_warriors() -> void:
	# Clean up invalid unit references
	faction.units = faction.units.filter(func(u): return u != null and is_instance_valid(u))

	var total_units := faction.units.size()
	if total_units == 0:
		return

	var desired_warriors := int(ceil(total_units * GameData.AI_WARRIOR_RATIO))
	var current_warriors := faction.get_unit_count_by_role(GameData.UnitRole.WARRIOR)

	if current_warriors < desired_warriors:
		# Convert some idle/scouts to warriors
		var to_convert := desired_warriors - current_warriors
		for unit in faction.units:
			if to_convert <= 0:
				break
			if unit.role == GameData.UnitRole.IDLE or unit.role == GameData.UnitRole.SCOUT:
				unit.role = GameData.UnitRole.WARRIOR
				# Set patrol position at a random territory tile
				var tiles: Array = faction.territory_tiles.keys()
				if tiles.size() > 0:
					var patrol_tile: Vector2i = tiles[randi() % tiles.size()]
					unit.target_position = world.tile_to_world(patrol_tile)
				else:
					unit.target_position = world.tile_to_world(faction.territory_center)
				unit.queue_redraw()
				to_convert -= 1
	elif current_warriors > desired_warriors + 2:
		# Convert excess warriors back to idle
		var to_convert := current_warriors - desired_warriors
		for unit in faction.units:
			if to_convert <= 0:
				break
			if unit.role == GameData.UnitRole.WARRIOR:
				unit.role = GameData.UnitRole.IDLE
				unit.queue_redraw()
				to_convert -= 1
