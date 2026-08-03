class_name GameManager
extends Node

# ─── References ──────────────────────────────────────────────────────
var world: World = null
var factions: Array = []  # Array of Faction nodes
var player_faction: Faction = null

# ─── War Timer ───────────────────────────────────────────────────────
var war_check_timer: float = 0.0

# ─── Game State ──────────────────────────────────────────────────────
var game_started: bool = false
var game_over: bool = false

signal faction_defeated(faction: Faction)
signal game_over_signal(winner: Faction)
signal combat_occurred(attacker: Faction, defender: Faction, result: String)

func initialize(world_ref: World) -> void:
	world = world_ref
	_create_factions()
	game_started = true

# ─── Faction Creation ────────────────────────────────────────────────

func _create_factions() -> void:
	var map_w: int = World.MAP_WIDTH
	var map_h: int = World.MAP_HEIGHT

	# Player faction — center-south of the island
	var player_center := Vector2i(map_w / 2, int(map_h * 0.65))
	player_faction = Faction.create(0, "Player", Color("3b82f6"), player_center, true)
	_add_faction(player_faction)

	# AI Faction 1 — north-west
	var ai1_center := Vector2i(int(map_w * 0.3), int(map_h * 0.3))
	var ai1 := Faction.create(1, "Red Horde", Color("ef4444"), ai1_center, false)
	_add_faction(ai1)

	# AI Faction 2 — north-east
	var ai2_center := Vector2i(int(map_w * 0.7), int(map_h * 0.3))
	var ai2 := Faction.create(2, "Green Realm", Color("22c55e"), ai2_center, false)
	_add_faction(ai2)

	# Adjust faction centers to valid PLAIN tiles
	for faction in factions:
		faction.territory_center = _find_nearest_plain(faction.territory_center)

	# Spawn initial units and town centres for each faction
	for faction in factions:
		_spawn_town_centre(faction)
		_spawn_initial_units(faction)

func _add_faction(faction: Faction) -> void:
	factions.append(faction)
	world.add_child(faction)

func _find_nearest_plain(center: Vector2i) -> Vector2i:
	# Spiral search outward to find a PLAIN tile near the desired center
	if _is_plain(center):
		return center
	for radius in range(1, 30):
		for dx in range(-radius, radius + 1):
			for dy in range(-radius, radius + 1):
				if abs(dx) != radius and abs(dy) != radius:
					continue  # Only check perimeter
				var test := Vector2i(center.x + dx, center.y + dy)
				if _is_plain(test):
					return test
	return center  # Fallback

func _is_plain(tile: Vector2i) -> bool:
	if not world.is_valid_coords(tile):
		return false
	return world.grid[tile.x][tile.y] == World.TerrainType.PLAIN

func _spawn_town_centre(faction: Faction) -> void:
	var tc := Building.create(
		GameData.BuildingType.TOWN_CENTRE,
		faction,
		faction.territory_center,
		World.TILE_SIZE
	)
	# Town Centre starts fully constructed
	tc.is_constructed = true
	tc.current_hp = tc.max_hp
	world.add_child(tc)
	faction.buildings.append(tc)
	# Mark occupied tiles (so nothing else builds there)
	world.register_building_tiles(tc)

func _spawn_initial_units(faction: Faction) -> void:
	var center_world := world.tile_to_world(faction.territory_center)
	for i in range(GameData.INITIAL_UNIT_COUNT):
		# Spread units around the town centre
		var offset := Vector2(
			randf_range(-32, 32),
			randf_range(-32, 32)
		)
		var spawn_pos := center_world + Vector2(World.TILE_SIZE, World.TILE_SIZE) + offset
		var unit := Unit.create(faction, spawn_pos, world)
		world.add_child(unit)
		faction.units.append(unit)

# ─── Game Loop ───────────────────────────────────────────────────────

func _process(delta: float) -> void:
	if not game_started or game_over:
		return

	# War check timer
	war_check_timer += delta
	if war_check_timer >= GameData.AI_WAR_CHECK_INTERVAL:
		war_check_timer = 0.0
		_evaluate_wars()

	# Check for defeated factions
	_check_defeated_factions()

	# Resolve ongoing combat
	_resolve_combat()

# ─── War Evaluation ──────────────────────────────────────────────────

func _evaluate_wars() -> void:
	for faction in factions:
		if faction.is_player or faction.units.size() == 0:
			continue

		# Find weakest other faction
		var weakest: Faction = null
		var weakest_strength: float = INF

		for other in factions:
			if other == faction or other.units.size() == 0:
				continue
			var strength: float = other.get_army_strength() + other.development_level * 10.0 + other.get_territory_area() * 0.1
			if strength < weakest_strength:
				weakest_strength = strength
				weakest = other

		if weakest == null:
			continue

		# Check if strong enough to attack
		var own_strength: float = faction.get_army_strength()
		if own_strength > weakest_strength * GameData.AI_ATTACK_THRESHOLD:
			_initiate_attack(faction, weakest)

func _initiate_attack(attacker: Faction, defender: Faction) -> void:
	# Convert idle units to warriors and send toward enemy
	var target_pos := world.tile_to_world(defender.territory_center)
	for unit in attacker.units:
		if unit == null or not is_instance_valid(unit):
			continue
		if unit.role == GameData.UnitRole.IDLE or unit.role == GameData.UnitRole.SCOUT:
			unit.role = GameData.UnitRole.WARRIOR
			unit.target_position = target_pos + Vector2(randf_range(-24, 24), randf_range(-24, 24))
			unit.is_working = false
			unit.queue_redraw()

# ─── Combat Resolution ───────────────────────────────────────────────

func _resolve_combat() -> void:
	# Check for warrior units from different factions near each other
	var combat_range: float = GameData.COMBAT_RANGE_TILES * World.TILE_SIZE

	# Group warriors by faction
	var warriors_by_faction: Dictionary = {}
	for faction in factions:
		var faction_warriors: Array = []
		for unit in faction.units:
			if unit == null or not is_instance_valid(unit):
				continue
			if unit.role == GameData.UnitRole.WARRIOR:
				faction_warriors.append(unit)
		if faction_warriors.size() > 0:
			warriors_by_faction[faction] = faction_warriors

	# Check each pair of factions for proximity combat
	var faction_list: Array = warriors_by_faction.keys()
	for i in range(faction_list.size()):
		for j in range(i + 1, faction_list.size()):
			var f1: Faction = faction_list[i]
			var f2: Faction = faction_list[j]
			var w1: Array = warriors_by_faction[f1]
			var w2: Array = warriors_by_faction[f2]

			# Check if any warriors are in range
			var in_combat: bool = false
			for u1 in w1:
				for u2 in w2:
					if u1.global_position.distance_to(u2.global_position) < combat_range:
						in_combat = true
						break
				if in_combat:
					break

			if in_combat:
				_resolve_battle(f1, w1, f2, w2)

func _resolve_battle(f1: Faction, w1: Array, f2: Faction, w2: Array) -> void:
	var strength1: float = _calculate_group_strength(w1)
	var strength2: float = _calculate_group_strength(w2)

	var winner: Faction
	var loser: Faction
	var winner_warriors: Array
	var loser_warriors: Array

	if strength1 >= strength2:
		winner = f1
		loser = f2
		winner_warriors = w1
		loser_warriors = w2
	else:
		winner = f2
		loser = f1
		winner_warriors = w2
		loser_warriors = w1

	# Loser loses units proportional to strength ratio
	var strength_ratio: float = min(_calculate_group_strength(winner_warriors) / max(_calculate_group_strength(loser_warriors), 0.1), 5.0)
	var loser_casualties: int = ceili(loser_warriors.size() * min(strength_ratio * 0.3, 1.0))
	var winner_casualties: int = ceili(winner_warriors.size() * randf_range(GameData.COMBAT_ATTRITION_MIN, GameData.COMBAT_ATTRITION_MAX))

	# Kill loser units
	loser_casualties = mini(loser_casualties, loser_warriors.size())
	for k in range(loser_casualties):
		var unit: Unit = loser_warriors[k]
		_kill_unit(loser, unit)

	# Kill winner attrition
	winner_casualties = mini(winner_casualties, winner_warriors.size())
	for k in range(winner_casualties):
		var unit: Unit = winner_warriors[k]
		_kill_unit(winner, unit)

	# After battle, surviving winner warriors return to idle
	for unit in winner_warriors:
		if is_instance_valid(unit):
			unit.role = GameData.UnitRole.IDLE
			unit.queue_redraw()

	var result_text: String = "%s defeated %s! (%d vs %d casualties)" % [winner.faction_name, loser.faction_name, winner_casualties, loser_casualties]
	combat_occurred.emit(winner, loser, result_text)

func _calculate_group_strength(warriors: Array) -> float:
	var strength: float = 0.0
	for unit in warriors:
		if unit == null or not is_instance_valid(unit):
			continue
		var base: float = 1.0
		if unit.has_weapon:
			base *= GameData.WEAPON_BONUS
		strength += base
	return strength

func _kill_unit(faction: Faction, unit: Unit) -> void:
	if unit == null or not is_instance_valid(unit):
		return
	faction.remove_unit(unit)
	unit.queue_free()

# ─── Defeated Factions ───────────────────────────────────────────────

func _check_defeated_factions() -> void:
	for faction in factions:
		# Clean up freed unit references
		faction.units = faction.units.filter(func(u): return u != null and is_instance_valid(u))
		faction.buildings = faction.buildings.filter(func(b): return b != null and is_instance_valid(b))

		if faction.units.size() == 0 and faction.buildings.size() == 0:
			faction_defeated.emit(faction)

	# Check win condition
	var alive_factions: Array = factions.filter(func(f): return f.units.size() > 0 or f.buildings.size() > 0)
	if alive_factions.size() <= 1 and alive_factions.size() > 0:
		game_over = true
		game_over_signal.emit(alive_factions[0])
