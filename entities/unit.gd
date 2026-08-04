class_name Unit
extends Node2D

## Autonomous unit with state-machine AI.
## Roles: IDLE → finds work, GATHERER → collects resources,
## BUILDER → constructs buildings, SCOUT → explores, WARRIOR → fights.

var faction: Faction = null
var role: GameData.UnitRole = GameData.UnitRole.IDLE
var has_weapon: bool = false
var move_speed: float = GameData.UNIT_MOVE_SPEED

# Movement
var target_position: Vector2 = Vector2.ZERO
var is_moving: bool = false

# Work state
var task_timer: float = 0.0
var is_working: bool = false
var target_resource: ResourceNode = null
var target_building = null   # Building reference
var world_ref: World = null

# Leader & follower state
var is_leader: bool = false
var leader_ref: Unit = null

# Scout wander
var wander_timer: float = 0.0

# Role-switch delay (prevents instant flickering)
var role_switch_cooldown: float = 0.0

# Visual blink for working state
var _work_blink: float = 0.0

func _ready() -> void:
	z_index = 10
	add_to_group("units")
	# Small initial randomisation so units don't all think simultaneously
	role_switch_cooldown = randf_range(0.3, 1.5)

func _process(delta: float) -> void:
	# Water death check — dies if standing on WATER tile
	if world_ref != null:
		var current_tile := world_ref.world_to_tile(global_position)
		if world_ref.is_valid_coords(current_tile) and world_ref.grid[current_tile.x][current_tile.y] == World.TerrainType.WATER:
			_die()
			return

	if faction == null:
		return

	_work_blink += delta

	# Cooldown before role switch
	if role_switch_cooldown > 0.0:
		role_switch_cooldown -= delta
		return

	match role:
		GameData.UnitRole.IDLE:
			_process_idle(delta)
		GameData.UnitRole.GATHERER:
			_process_gatherer(delta)
		GameData.UnitRole.BUILDER:
			_process_builder(delta)
		GameData.UnitRole.SCOUT:
			_process_scout(delta)
		GameData.UnitRole.WARRIOR:
			_process_warrior(delta)

func _die() -> void:
	if faction != null:
		faction.remove_unit(self)
	queue_free()

# ─── IDLE ────────────────────────────────────────────────────────────

func _process_idle(_delta: float) -> void:
	# Priority 1: construction sites
	if faction.has_construction_sites():
		var site = _find_nearest_construction_site()
		if site != null:
			target_building = site
			_set_role(GameData.UnitRole.BUILDER)
			return

	# Priority 2: gather resources
	var res := _find_nearest_resource()
	if res != null:
		target_resource = res
		_set_role(GameData.UnitRole.GATHERER)
		return

	# Priority 3: scout
	_set_role(GameData.UnitRole.SCOUT)

# ─── GATHERER ────────────────────────────────────────────────────────

func _process_gatherer(delta: float) -> void:
	# Validate target
	if target_resource == null or not is_instance_valid(target_resource) or not target_resource.can_gather():
		is_working = false
		target_resource = _find_nearest_resource()
		if target_resource == null:
			_set_role(GameData.UnitRole.IDLE)
			return

	var target_world_pos := target_resource.position + Vector2(World.TILE_SIZE / 2.0, World.TILE_SIZE / 2.0)
	var dist := global_position.distance_to(target_world_pos)

	if dist > World.TILE_SIZE * 1.2:
		# Walk toward resource
		is_working = false
		_move_toward(target_world_pos, delta)
	else:
		# At resource — gather
		if not is_working:
			target_resource.start_gather()
			is_working = true
			task_timer = GameData.GATHER_TIME
			queue_redraw()

		task_timer -= delta
		if task_timer <= 0.0:
			target_resource.finish_gather()
			faction.add_resource(target_resource.resource_type, GameData.GATHER_AMOUNT)
			is_working = false
			target_resource = null
			queue_redraw()

# ─── BUILDER ─────────────────────────────────────────────────────────

func _process_builder(delta: float) -> void:
	# Validate target
	if target_building == null or not is_instance_valid(target_building) or target_building.is_constructed:
		is_working = false
		target_building = _find_nearest_construction_site()
		if target_building == null:
			_set_role(GameData.UnitRole.IDLE)
			return

	var bld_center: Vector2 = target_building.position + Vector2(
		target_building.bld_size.x * World.TILE_SIZE / 2.0,
		target_building.bld_size.y * World.TILE_SIZE / 2.0
	)
	var dist := global_position.distance_to(bld_center)

	if dist > World.TILE_SIZE * 1.8:
		is_working = false
		_move_toward(bld_center, delta)
	else:
		is_working = true
		var build_rate: float = GameData.BUILDING_DEFS[target_building.building_type]["build_rate"]
		target_building.add_construction(build_rate * delta)
		if target_building.is_constructed:
			is_working = false
			target_building = null
			_set_role(GameData.UnitRole.IDLE)
		queue_redraw()

# ─── SCOUT ───────────────────────────────────────────────────────────

func _process_scout(delta: float) -> void:
	# Check if there's now real work to do
	if faction.has_construction_sites():
		_set_role(GameData.UnitRole.IDLE)
		return
	var res := _find_nearest_resource()
	if res != null:
		target_resource = res
		_set_role(GameData.UnitRole.GATHERER)
		return

	wander_timer -= delta
	if wander_timer <= 0.0:
		# Pick random wander target within territory (range ≈ sqrt of tile count + buffer)
		var center := world_ref.tile_to_world(faction.territory_center)
		var range_px: float = (sqrt(float(faction.territory_tiles.size())) + 10.0) * World.TILE_SIZE
		target_position = center + Vector2(
			randf_range(-range_px, range_px),
			randf_range(-range_px, range_px)
		)
		# Clamp to map bounds
		target_position.x = clampf(target_position.x, 0, (World.MAP_WIDTH - 1) * World.TILE_SIZE)
		target_position.y = clampf(target_position.y, 0, (World.MAP_HEIGHT - 1) * World.TILE_SIZE)
		wander_timer = randf_range(2.0, 4.0)

	if global_position.distance_to(target_position) > 4.0:
		_move_toward(target_position, delta)

# ─── WARRIOR ─────────────────────────────────────────────────────────

func _process_warrior(delta: float) -> void:
	if target_position == Vector2.ZERO:
		return
	if global_position.distance_to(target_position) > GameData.COMBAT_RANGE_TILES * World.TILE_SIZE:
		_move_toward(target_position, delta)

func _is_within_leash_range(tile: Vector2i) -> bool:
	if faction == null:
		return true
	return faction.get_min_tile_distance(tile) <= 15.0

func _is_resource_valid_for_faction(res_node: ResourceNode) -> bool:
	if res_node == null or not res_node.can_gather():
		return false
	if world_ref == null:
		return true
	var res_tile := world_ref.world_to_tile(res_node.global_position)
	var gm = world_ref.get_node_or_null("GameManager")
	if gm != null and gm.has_method("is_tile_claimed"):
		if gm.is_tile_claimed(res_tile, faction):
			return false  # On another faction's territory — cannot harvest
	if faction != null and not _is_within_leash_range(res_tile):
		return false  # Too far from own territory (> 15 tiles)
	return true

# ─── Movement ────────────────────────────────────────────────────────

func _move_toward(target: Vector2, delta: float) -> bool:
	var direction := (target - global_position).normalized()
	var step := direction * move_speed * delta

	# Check if next tile is walkable and within 15-tile territory leash
	var next_pos := global_position + step
	var next_tile := world_ref.world_to_tile(next_pos)

	if faction != null and not _is_within_leash_range(next_tile):
		# Cannot move > 15 tiles away from own territory
		var center_pos := world_ref.tile_to_world(faction.territory_center)
		var back_dir := (center_pos - global_position).normalized()
		var back_step := back_dir * move_speed * delta
		var back_pos := global_position + back_step
		var back_tile := world_ref.world_to_tile(back_pos)
		if world_ref.is_valid_coords(back_tile) and world_ref.grid[back_tile.x][back_tile.y] == World.TerrainType.PLAIN:
			global_position = back_pos
		queue_redraw()
		return false

	if world_ref.is_valid_coords(next_tile):
		if world_ref.grid[next_tile.x][next_tile.y] != World.TerrainType.PLAIN:
			# Try perpendicular directions
			var perp1 := Vector2(-direction.y, direction.x) * move_speed * delta
			var alt1 := global_position + perp1
			var alt1_tile := world_ref.world_to_tile(alt1)
			if world_ref.is_valid_coords(alt1_tile) and world_ref.grid[alt1_tile.x][alt1_tile.y] == World.TerrainType.PLAIN:
				global_position = alt1
			else:
				var perp2 := Vector2(direction.y, -direction.x) * move_speed * delta
				var alt2 := global_position + perp2
				var alt2_tile := world_ref.world_to_tile(alt2)
				if world_ref.is_valid_coords(alt2_tile) and world_ref.grid[alt2_tile.x][alt2_tile.y] == World.TerrainType.PLAIN:
					global_position = alt2
			queue_redraw()
			return false
		else:
			global_position = next_pos
	else:
		# Out of bounds — don't move
		return false

	# Check if reached
	var reached := global_position.distance_to(target) < 3.0
	# Redraw periodically (when tile changes)
	if Engine.get_process_frames() % 10 == 0:
		queue_redraw()
	return reached

# ─── Helpers ─────────────────────────────────────────────────────────

func _find_nearest_resource() -> ResourceNode:
	var preferred_type: GameData.ResourceType = GameData.ResourceType.WOOD

	if faction != null:
		var wood_count := faction.get_resource(GameData.ResourceType.WOOD)
		if wood_count < GameData.INITIAL_WOOD_GATHER:
			preferred_type = GameData.ResourceType.WOOD
		else:
			# Find resource type with lowest amount in storage
			var min_amt := INF
			var types := [GameData.ResourceType.WOOD, GameData.ResourceType.GOLD, GameData.ResourceType.ORE, GameData.ResourceType.STONE]
			for t in types:
				var amt := faction.get_resource(t)
				if amt < min_amt:
					min_amt = amt
					preferred_type = t

	# Search for nearest valid node of preferred_type first
	var best: ResourceNode = null
	var best_dist: float = INF
	for node in get_tree().get_nodes_in_group("resources"):
		var res_node := node as ResourceNode
		if not _is_resource_valid_for_faction(res_node):
			continue
		if res_node.resource_type != preferred_type:
			continue
		var dist := global_position.distance_to(res_node.global_position)
		if dist < best_dist:
			best_dist = dist
			best = res_node

	if best != null:
		return best

	# Fallback to any valid node
	for node in get_tree().get_nodes_in_group("resources"):
		var res_node := node as ResourceNode
		if not _is_resource_valid_for_faction(res_node):
			continue
		var dist := global_position.distance_to(res_node.global_position)
		if dist < best_dist:
			best_dist = dist
			best = res_node
	return best

func _find_nearest_construction_site():
	if faction == null:
		return null
	var sites := faction.get_construction_sites()
	var best = null
	var best_dist: float = INF
	for site in sites:
		if site == null or not is_instance_valid(site):
			continue
		var dist := global_position.distance_to(site.global_position)
		if dist < best_dist:
			best_dist = dist
			best = site
	return best

func _set_role(new_role: GameData.UnitRole) -> void:
	role = new_role
	is_working = false
	role_switch_cooldown = randf_range(0.3, 0.8)
	queue_redraw()

# ─── Visual ──────────────────────────────────────────────────────────

func _draw() -> void:
	if faction == null:
		return

	var col: Color = faction.faction_color

	# 1. Simple Drop Shadow under unit
	draw_ellipse(Vector2(0, 4), 3.5, 1.8, Color(0, 0, 0, 0.45))

	# 2. Beautiful Minimalist Unit Sprite (Stylized Humanoid Figure)
	# Head
	draw_circle(Vector2(0, -3), 2.2, col.lightened(0.25))
	draw_arc(Vector2(0, -3), 2.2, 0, TAU, 16, col.darkened(0.4), 1.0)

	# Body / Tunic
	var body_points := PackedVector2Array([
		Vector2(-2.5, -1),
		Vector2(2.5, -1),
		Vector2(2.0, 3.5),
		Vector2(-2.0, 3.5)
	])
	draw_colored_polygon(body_points, col)
	var body_outline := PackedVector2Array([
		Vector2(-2.5, -1),
		Vector2(2.5, -1),
		Vector2(2.0, 3.5),
		Vector2(-2.0, 3.5),
		Vector2(-2.5, -1)
	])
	draw_polyline(body_outline, col.darkened(0.4), 1.0)

	# Weapon indicator (sword on right)
	if has_weapon:
		draw_line(Vector2(3, -2), Vector2(3, 4), Color.WHITE, 1.2)
		draw_line(Vector2(1.5, 1), Vector2(4.5, 1), Color.WHITE, 1.0)

	# 3. State Icon above unit
	_draw_state_icon()

func _draw_state_icon() -> void:
	var y_offset: float = -9.0

	# State 1: Thinking (cooldown or idle)
	if role_switch_cooldown > 0.0 or role == GameData.UnitRole.IDLE:
		# Lightbulb icon 💡
		draw_circle(Vector2(0, y_offset - 3), 2.2, Color.YELLOW)
		draw_rect(Rect2(-1, y_offset - 1, 2, 1.5), Color.DARK_GRAY)
		# Glow rays
		draw_line(Vector2(-3, y_offset - 3), Vector2(-4, y_offset - 3), Color(1, 1, 0.6), 1.0)
		draw_line(Vector2(3, y_offset - 3), Vector2(4, y_offset - 3), Color(1, 1, 0.6), 1.0)
		draw_line(Vector2(0, y_offset - 6), Vector2(0, y_offset - 7), Color(1, 1, 0.6), 1.0)
		return

	# State 2: Gathering
	if role == GameData.UnitRole.GATHERER:
		var is_wood := true
		if target_resource != null and target_resource.resource_type != GameData.ResourceType.WOOD:
			is_wood = false

		if is_wood:
			# Log icon 🪵
			draw_rect(Rect2(-3, y_offset - 2, 6, 2.5), Color("7c4a1e"))
			draw_rect(Rect2(-3, y_offset - 2, 1, 2.5), Color("c2935c"))
			draw_line(Vector2(-2, y_offset - 1), Vector2(2, y_offset - 1), Color("4a2b0f"), 1.0)
		else:
			# Pickaxe icon ⛏️
			draw_line(Vector2(-2, y_offset + 1), Vector2(2, y_offset - 3), Color("6e4726"), 1.2)
			draw_line(Vector2(-1, y_offset - 4), Vector2(3, y_offset - 1), Color.LIGHT_GRAY, 1.5)
			var tip_col := Color.GOLD if (target_resource and target_resource.resource_type == GameData.ResourceType.GOLD) else Color.WHITE
			draw_line(Vector2(0, y_offset - 5), Vector2(2, y_offset - 3), tip_col, 1.0)
		return

	# State 3: Scouting
	if role == GameData.UnitRole.SCOUT:
		# Running figure symbol 🏃
		draw_circle(Vector2(0, y_offset - 4), 1.2, Color.CYAN)
		draw_line(Vector2(0, y_offset - 3), Vector2(-1, y_offset), Color.CYAN, 1.2)
		draw_line(Vector2(-1, y_offset), Vector2(2, y_offset + 2), Color.CYAN, 1.0)
		draw_line(Vector2(0, y_offset - 2), Vector2(2, y_offset - 1), Color.CYAN, 1.0)
		return

	# State 4: Builder
	if role == GameData.UnitRole.BUILDER:
		# Hammer icon 🔨
		draw_line(Vector2(-1, y_offset + 1), Vector2(1, y_offset - 3), Color("6e4726"), 1.2)
		draw_rect(Rect2(-1, y_offset - 4, 4, 2), Color.SILVER)
		return

	# State 5: Warrior
	if role == GameData.UnitRole.WARRIOR:
		# Sword icon ⚔️
		draw_line(Vector2(0, y_offset + 1), Vector2(0, y_offset - 5), Color.SILVER, 1.5)
		draw_line(Vector2(-2, y_offset - 1), Vector2(2, y_offset - 1), Color.GOLD, 1.0)
		return

# ─── Factory ─────────────────────────────────────────────────────────

static func create(f: Faction, pos: Vector2, world: World) -> Unit:
	var unit := Unit.new()
	unit.faction = f
	unit.global_position = pos
	unit.world_ref = world
	if f != null:
		unit.name = "Unit_%s_%d" % [f.faction_name, f.units.size()]
	else:
		unit.name = "Unit_Pending"
	return unit
