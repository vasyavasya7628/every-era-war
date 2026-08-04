class_name Faction
extends Node2D

## Manages all per-faction state: population, resources, buildings, territory.
## A faction is formed dynamically when the player spawns humans close together.

var faction_id: int = 0
var faction_name: String = "Unnamed"
var faction_color: Color = Color.WHITE
var is_player: bool = true

## The leader unit — the first human that was spawned for this faction.
var leader: Unit = null

# Economy
var resources: Dictionary = {}

# Population & structures
var units: Array = []       # Unit node references
var buildings: Array = []   # Building node references

# Territory — keys are Vector2i tile coords, values are true
var territory_tiles: Dictionary = {}
var territory_center: Vector2i = Vector2i.ZERO

# Development = number of completed buildings
var development_level: int:
	get:
		var count: int = 0
		for b in buildings:
			if b != null and is_instance_valid(b) and b.is_constructed:
				count += 1
		return count

func _init() -> void:
	_reset_resources()

func _reset_resources() -> void:
	# Start with no resources — units must gather them
	resources = {
		GameData.ResourceType.WOOD: 0,
		GameData.ResourceType.GOLD: 0,
		GameData.ResourceType.ORE: 0,
		GameData.ResourceType.STONE: 0,
	}

# ─── Resource Management ────────────────────────────────────────────

func add_resource(type: GameData.ResourceType, amount: int) -> void:
	if resources.has(type):
		resources[type] += amount
	else:
		resources[type] = amount

func get_resource(type: GameData.ResourceType) -> int:
	return resources.get(type, 0)

func can_afford(cost: Dictionary) -> bool:
	for type in cost:
		if get_resource(type) < cost[type]:
			return false
	return true

func spend_resources(cost: Dictionary) -> bool:
	if not can_afford(cost):
		return false
	for type in cost:
		resources[type] -= cost[type]
	return true

# ─── Army & Combat ──────────────────────────────────────────────────

func get_army_strength() -> float:
	var strength: float = 0.0
	for unit in units:
		if unit == null or not is_instance_valid(unit):
			continue
		var base: float = 1.0 + 0.1 * development_level
		if unit.has_weapon:
			base *= GameData.WEAPON_BONUS
		strength += base
	return strength

# ─── Territory ──────────────────────────────────────────────────────

func get_territory_area() -> int:
	return territory_tiles.size()

func is_in_territory(tile: Vector2i) -> bool:
	return territory_tiles.has(tile)

## BFS frontier expansion — organic tile-by-tile spread over land.
func expand_territory() -> void:
	var world_node := get_parent() as World
	if world_node == null:
		return

	# How many tiles to claim this tick
	var tiles_to_add: int = GameData.TERRITORY_BASE_EXPANSION + development_level * GameData.TERRITORY_EXPAND_PER_BUILDING

	# Build frontier: unclaimed land tiles adjacent to our territory
	var frontier: Array = []
	var seen: Dictionary = {}
	for tile in territory_tiles:
		var tile_v := tile as Vector2i
		var neighbors := [
			Vector2i(tile_v.x + 1, tile_v.y),
			Vector2i(tile_v.x - 1, tile_v.y),
			Vector2i(tile_v.x, tile_v.y + 1),
			Vector2i(tile_v.x, tile_v.y - 1),
		]
		for n in neighbors:
			if seen.has(n):
				continue
			seen[n] = true
			if territory_tiles.has(n):
				continue
			if not world_node.is_land_tile(n):
				continue
			frontier.append(n)

	# Shuffle for organic spread
	frontier.shuffle()

	var added := 0
	for t in frontier:
		if added >= tiles_to_add:
			break
		territory_tiles[t] = true
		added += 1

# ─── Unit Queries ───────────────────────────────────────────────────

func get_unit_count_by_role(role: GameData.UnitRole) -> int:
	var count: int = 0
	for unit in units:
		if unit != null and is_instance_valid(unit) and unit.role == role:
			count += 1
	return count

func get_idle_units() -> Array:
	var result: Array = []
	for unit in units:
		if unit != null and is_instance_valid(unit) and unit.role == GameData.UnitRole.IDLE:
			result.append(unit)
	return result

# ─── Building Queries ───────────────────────────────────────────────

func get_completed_buildings_of_type(type: GameData.BuildingType) -> Array:
	var result: Array = []
	for b in buildings:
		if b != null and is_instance_valid(b) and b.building_type == type and b.is_constructed:
			result.append(b)
	return result

func has_construction_sites() -> bool:
	for b in buildings:
		if b != null and is_instance_valid(b) and not b.is_constructed:
			return true
	return false

func get_construction_sites() -> Array:
	var result: Array = []
	for b in buildings:
		if b != null and is_instance_valid(b) and not b.is_constructed:
			result.append(b)
	return result

# ─── Removal ────────────────────────────────────────────────────────

func remove_unit(unit) -> void:
	units.erase(unit)

func remove_building(building) -> void:
	buildings.erase(building)

# ─── Factory ────────────────────────────────────────────────────────

static func create(id: int, fname: String, color: Color, center: Vector2i, player: bool = true) -> Faction:
	var faction := Faction.new()
	faction.faction_id = id
	faction.faction_name = fname
	faction.faction_color = color
	faction.territory_center = center
	if not faction.territory_tiles.has(center):
		faction.territory_tiles[center] = true
	faction.is_player = player
	faction.name = "Faction_" + fname
	return faction
