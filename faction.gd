class_name Faction
extends Node2D

## Manages all per-faction state: population, resources, buildings, territory.

var faction_id: int = 0
var faction_name: String = "Unnamed"
var faction_color: Color = Color.WHITE
var is_player: bool = false

# Economy
var resources: Dictionary = {}

# Population & structures
var units: Array = []       # Unit node references
var buildings: Array = []   # Building node references

# Territory
var territory_center: Vector2i = Vector2i.ZERO
var territory_radius: int = GameData.INITIAL_TERRITORY_RADIUS

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
	resources = {
		GameData.ResourceType.WOOD: 50,
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
	return int(PI * territory_radius * territory_radius)

func expand_territory() -> void:
	territory_radius += GameData.TERRITORY_EXPAND_PER_BUILDING

func is_in_territory(tile: Vector2i) -> bool:
	var diff := Vector2(tile.x - territory_center.x, tile.y - territory_center.y)
	return diff.length() <= territory_radius

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

static func create(id: int, fname: String, color: Color, center: Vector2i, player: bool = false) -> Faction:
	var faction := Faction.new()
	faction.faction_id = id
	faction.faction_name = fname
	faction.faction_color = color
	faction.territory_center = center
	faction.is_player = player
	faction.name = "Faction_" + fname
	return faction
