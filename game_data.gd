class_name GameData
extends Node

# ─── Resource Types ──────────────────────────────────────────────────
enum ResourceType {
	WOOD,
	GOLD,
	ORE,
	STONE
}

# ─── Unit Roles ──────────────────────────────────────────────────────
enum UnitRole {
	IDLE,
	BUILDER,
	GATHERER,
	SCOUT,
	WARRIOR
}

# ─── Building Types ─────────────────────────────────────────────────
enum BuildingType {
	TOWN_CENTRE,
	HOUSE,
	FORGE,
	MINE
}

# ─── Building Definitions ───────────────────────────────────────────
# Each entry: { size: Vector2i, max_hp: int, cost: Dictionary, build_rate: float }
# build_rate = HP added per second per worker
# Using static var because Godot 4.x can't resolve enum keys in const dicts
static var BUILDING_DEFS: Dictionary = {
	BuildingType.TOWN_CENTRE: {
		"name": "Town Centre",
		"size": Vector2i(2, 2),
		"max_hp": 200,
		"cost": {},  # Free – auto-placed at faction start
		"build_rate": 10.0,
	},
	BuildingType.HOUSE: {
		"name": "House",
		"size": Vector2i(1, 1),
		"max_hp": 100,
		"cost": { ResourceType.WOOD: 20 },
		"build_rate": 10.0,
	},
	BuildingType.FORGE: {
		"name": "Forge",
		"size": Vector2i(2, 1),
		"max_hp": 150,
		"cost": { ResourceType.WOOD: 30, ResourceType.ORE: 20, ResourceType.STONE: 10 },
		"build_rate": 10.0,
	},
	BuildingType.MINE: {
		"name": "Mine",
		"size": Vector2i(1, 1),
		"max_hp": 80,
		"cost": { ResourceType.WOOD: 15, ResourceType.STONE: 10 },
		"build_rate": 10.0,
	},
}

# ─── Resource Gathering ─────────────────────────────────────────────
const GATHER_TIME: float = 3.0          # Seconds to gather one resource unit
const GATHER_AMOUNT: int = 5            # Amount gained per gather action

# ─── Unit Constants ─────────────────────────────────────────────────
const UNIT_MOVE_SPEED: float = 30.0     # Pixels per second
const UNIT_SIZE: int = 4                # Pixel size of a unit sprite (4×4)

# ─── Faction Constants ──────────────────────────────────────────────
const INITIAL_TERRITORY_RADIUS: int = 5 # Tiles from centre
const TERRITORY_EXPAND_PER_BUILDING: int = 2
const INITIAL_UNIT_COUNT: int = 5

# ─── AI Constants ────────────────────────────────────────────────────
const AI_SPAWN_INTERVAL: float = 10.0   # Seconds between AI auto-spawns
const AI_WAR_CHECK_INTERVAL: float = 60.0  # Seconds between war evaluations
const AI_ATTACK_THRESHOLD: float = 1.5  # Must be N× stronger to attack
const AI_WARRIOR_RATIO: float = 0.3     # 30% of units kept as warriors

# ─── Combat Constants ───────────────────────────────────────────────
const COMBAT_RANGE_TILES: int = 2       # Tile distance to trigger combat
const COMBAT_ATTRITION_MIN: float = 0.1 # Winner loses 10-30% of warriors
const COMBAT_ATTRITION_MAX: float = 0.3
const WEAPON_BONUS: float = 1.5         # Multiplier for armed units

# ─── Forge Production ───────────────────────────────────────────────
const FORGE_WEAPON_INTERVAL: float = 15.0  # Seconds per weapon crafted

# ─── Resource Node Visual Colors ─────────────────────────────────────
static var RESOURCE_COLORS: Dictionary = {
	ResourceType.WOOD:  Color("2d6a1e"),  # Dark green (trees)
	ResourceType.GOLD:  Color("d4a017"),  # Gold yellow
	ResourceType.ORE:   Color("6b6b6b"),  # Grey
	ResourceType.STONE: Color("8b7355"),  # Brown
}

static var RESOURCE_NAMES: Dictionary = {
	ResourceType.WOOD:  "Wood",
	ResourceType.GOLD:  "Gold",
	ResourceType.ORE:   "Ore",
	ResourceType.STONE: "Stone",
}
