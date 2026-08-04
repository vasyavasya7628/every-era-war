class_name Building
extends Node2D

## A constructable building on the grid.
## Buildings start as construction sites (current_hp=0) and are built by workers.

var building_type: GameData.BuildingType = GameData.BuildingType.HOUSE
var faction: Faction = null
var tile_position: Vector2i = Vector2i.ZERO
var bld_size: Vector2i = Vector2i(1, 1)
var max_hp: int = 100
var current_hp: float = 0.0
var is_constructed: bool = false
var weapon_timer: float = 0.0

func _ready() -> void:
	z_index = 5
	add_to_group("buildings")

func _process(delta: float) -> void:
	if not is_constructed:
		return

	if building_type == GameData.BuildingType.TOWN_CENTRE and Engine.get_process_frames() % 15 == 0:
		queue_redraw()

	# Forge produces weapons over time
	if building_type == GameData.BuildingType.FORGE and faction != null:
		weapon_timer += delta
		if weapon_timer >= GameData.FORGE_WEAPON_INTERVAL:
			weapon_timer = 0.0
			_produce_weapon()

func _produce_weapon() -> void:
	# Find an unarmed unit in the faction and arm them
	for unit in faction.units:
		if unit != null and is_instance_valid(unit) and not unit.has_weapon:
			unit.has_weapon = true
			unit.queue_redraw()
			return  # One weapon per cycle

# ─── Construction ────────────────────────────────────────────────────

func add_construction(amount: float) -> void:
	if is_constructed:
		return
	current_hp = min(current_hp + amount, max_hp)
	if current_hp >= max_hp:
		is_constructed = true
		if faction != null:
			faction.expand_territory()
	queue_redraw()

# ─── Tile Queries ────────────────────────────────────────────────────

func get_occupied_tiles() -> Array:
	var tiles: Array = []
	for dx in range(bld_size.x):
		for dy in range(bld_size.y):
			tiles.append(Vector2i(tile_position.x + dx, tile_position.y + dy))
	return tiles

# ─── Visual ──────────────────────────────────────────────────────────

func _draw() -> void:
	if faction == null:
		return

	var ts: float = World.TILE_SIZE
	var w: float = bld_size.x * ts
	var h: float = bld_size.y * ts
	var col: Color = faction.faction_color

	# Simple Drop Shadow
	draw_rect(Rect2(3, 3, w, h), Color(0, 0, 0, 0.35))

	if not is_constructed:
		# ── Under Construction ──
		# Semi-transparent fill
		draw_rect(Rect2(0, 0, w, h), Color(col.r, col.g, col.b, 0.35))

		# Scaffold hatching pattern
		var line_col := Color(col.r, col.g, col.b, 0.5)
		for i in range(0, int(w + h), 6):
			var x1 := clampf(float(i), 0, w)
			var y1 := clampf(float(i) - w, 0, h)
			var x2 := clampf(float(i) - h, 0, w)
			var y2 := clampf(float(i), 0, h)
			draw_line(Vector2(x1, y1), Vector2(x2, y2), line_col, 1.0)

		# Progress bar
		var bar_w: float = w - 2
		var progress: float = current_hp / max_hp
		var bar_y: float = h + 2
		draw_rect(Rect2(1, bar_y, bar_w, 3), Color(0.2, 0.2, 0.2, 0.8))
		draw_rect(Rect2(1, bar_y, bar_w * progress, 3), Color(0.2, 0.9, 0.2, 0.9))

		# Border
		draw_rect(Rect2(0, 0, w, h), Color(col.r, col.g, col.b, 0.6), false, 1.0)
	else:
		# ── Completed Building ──
		draw_rect(Rect2(0, 0, w, h), col)
		draw_rect(Rect2(0, 0, w, h), col.darkened(0.25), false, 1.0)

		# Type-specific icon
		match building_type:
			GameData.BuildingType.TOWN_CENTRE:
				# Flag/banner: pole + colored top
				var cx: float = w / 2.0
				draw_line(Vector2(cx, 2), Vector2(cx, h - 2), Color.WHITE, 1.0)
				draw_rect(Rect2(cx + 1, 2, 5, 4), Color.YELLOW)
				# Corner markers
				draw_rect(Rect2(1, 1, 3, 3), col.lightened(0.4))
				draw_rect(Rect2(w - 4, 1, 3, 3), col.lightened(0.4))
				draw_rect(Rect2(1, h - 4, 3, 3), col.lightened(0.4))
				draw_rect(Rect2(w - 4, h - 4, 3, 3), col.lightened(0.4))

				# Display stored resource counts above Town Centre
				if faction != null and is_constructed:
					var text := "W:%d G:%d O:%d S:%d" % [
						faction.get_resource(GameData.ResourceType.WOOD),
						faction.get_resource(GameData.ResourceType.GOLD),
						faction.get_resource(GameData.ResourceType.ORE),
						faction.get_resource(GameData.ResourceType.STONE)
					]
					var font := ThemeDB.fallback_font
					draw_string(font, Vector2(-8, -4), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color.YELLOW)

			GameData.BuildingType.HOUSE:
				# Roof triangle on top
				draw_colored_polygon(
					PackedVector2Array([
						Vector2(w / 2.0, 0),
						Vector2(-1, ts * 0.5),
						Vector2(w + 1, ts * 0.5),
					]),
					col.darkened(0.15)
				)
				# Door
				draw_rect(Rect2(w / 2.0 - 2, h - 5, 4, 5), col.darkened(0.4))

			GameData.BuildingType.FORGE:
				# Anvil shape — orange/red accent
				var accent := Color("e05530")
				draw_rect(Rect2(4, h / 2.0 - 2, w - 8, 4), accent)
				draw_rect(Rect2(w / 2.0 - 1, h / 2.0 - 5, 2, 3), Color.DIM_GRAY)
				# Fire glow
				draw_circle(Vector2(w / 2.0, h / 2.0), 3, Color(1, 0.5, 0, 0.4))

			GameData.BuildingType.MINE:
				# Pickaxe shape
				draw_line(Vector2(3, 3), Vector2(ts - 3, ts - 3), Color.DIM_GRAY, 2.0)
				draw_rect(Rect2(2, 2, 4, 3), Color.GRAY)

# ─── Factory ─────────────────────────────────────────────────────────

static func create(type: GameData.BuildingType, f: Faction, tile_pos: Vector2i, tile_size: int) -> Building:
	var bld := Building.new()
	bld.building_type = type
	bld.faction = f
	bld.tile_position = tile_pos

	var def: Dictionary = GameData.BUILDING_DEFS[type]
	bld.bld_size = def["size"]
	bld.max_hp = def["max_hp"]

	bld.position = Vector2(tile_pos.x * tile_size, tile_pos.y * tile_size)
	bld.name = "Building_%s_%d_%d" % [def["name"].replace(" ", ""), tile_pos.x, tile_pos.y]

	# Town Centre starts fully built
	if type == GameData.BuildingType.TOWN_CENTRE:
		bld.is_constructed = true
		bld.current_hp = bld.max_hp

	return bld
