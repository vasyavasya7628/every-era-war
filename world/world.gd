class_name World
extends Node2D

enum TerrainType {
	WATER,
	PLAIN,
	MOUNTAIN
}

const MAP_WIDTH: int = 128
const MAP_HEIGHT: int = 128
const TILE_SIZE: int = 16

# ─── Resource & Building tracking ────────────────────────────────────
var resource_nodes: Array = []       # All ResourceNode instances on the map
var occupied_tiles: Dictionary = {}  # Vector2i -> true for tiles with buildings

# Tile atlas coordinates (Source ID: 0)
const ATLAS_WATER: Vector2i = Vector2i(0, 0)
const ATLAS_SHALLOW_WATER: Vector2i = Vector2i(1, 0)
const ATLAS_SHORE: Vector2i = Vector2i(2, 0)
const ATLAS_PLAIN: Vector2i = Vector2i(3, 0)
const ATLAS_MOUNTAIN: Vector2i = Vector2i(0, 1)
const ATLAS_MOUNTAIN_PEAK: Vector2i = Vector2i(1, 1)
const ATLAS_ROCKY_SHORE: Vector2i = Vector2i(2, 1)

@onready var tile_map_layer: TileMapLayer = $TileMapLayer

# 2D Grid storing base TerrainType for each cell: grid[x][y]
var grid: Array = []

func _ready() -> void:
	_setup_tileset()
	_init_grid()
	_generate_initial_world()
	_spawn_resources()
	# Initialize RTS game systems after world is ready
	call_deferred("_init_game_systems")

func _init_game_systems() -> void:
	var bootstrap := GameBootstrap.new()
	bootstrap.name = "GameBootstrap"
	bootstrap.initialize(self)

func _setup_tileset() -> void:
	if tile_map_layer == null:
		return
		
	tile_map_layer.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	
	# Create procedural tile texture image
	var img := _create_tileset_image()
	# Save image to res:// for texture editor inspection
	img.save_png("res://world/tileset.png")
	
	var tex := ImageTexture.create_from_image(img)
	
	var tileset := TileSet.new()
	tileset.tile_size = Vector2i(TILE_SIZE, TILE_SIZE)
	
	var source := TileSetAtlasSource.new()
	source.texture = tex
	source.texture_region_size = Vector2i(TILE_SIZE, TILE_SIZE)
	
	var tiles_to_create := [
		Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(3, 0),
		Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1), Vector2i(3, 1)
	]
	for coords in tiles_to_create:
		source.create_tile(coords)
		
	tileset.add_source(source, 0)
	tile_map_layer.tile_set = tileset

func _create_tileset_image() -> Image:
	var atlas_w := 4 * TILE_SIZE # 64 px
	var atlas_h := 2 * TILE_SIZE # 32 px
	var img := Image.create(atlas_w, atlas_h, false, Image.FORMAT_RGBA8)
	
	# Helper to fill a tile box without any cell perimeter borders for seamless rendering
	var fill_tile = func(tx: int, ty: int, base_col: Color, detail_col: Color):
		var start_x := tx * TILE_SIZE
		var start_y := ty * TILE_SIZE
		for y in range(TILE_SIZE):
			for x in range(TILE_SIZE):
				var px := start_x + x
				var py := start_y + y
				# Use pseudo-random noise pattern to make texture organic and seamless
				var noise_val := (x * 7 + y * 13 + tx * 17 + ty * 31) % 11
				if noise_val == 0:
					img.set_pixel(px, py, detail_col)
				else:
					img.set_pixel(px, py, base_col)

	# 0,0: WATER (Deep Ocean Blue)
	fill_tile.call(0, 0, Color("1e4d8c"), Color("2b6cb0"))
	# 1,0: SHALLOW WATER (Turquoise)
	fill_tile.call(1, 0, Color("319795"), Color("4fd1c5"))
	# 2,0: SHORE (Beach Sand)
	fill_tile.call(2, 0, Color("d69e2e"), Color("ecc94b"))
	# 3,0: PLAIN (Meadow Grass)
	fill_tile.call(3, 0, Color("38a169"), Color("48bb78"))
	
	# 0,1: MOUNTAIN (Rock Grey)
	fill_tile.call(0, 1, Color("4a5568"), Color("718096"))
	# 1,1: MOUNTAIN PEAK (Snow White/Grey)
	fill_tile.call(1, 1, Color("cbd5e0"), Color("ffffff"))
	# 2,1: ROCKY SHORE (Pebble Coast)
	fill_tile.call(2, 1, Color("744210"), Color("9b2c2c"))

	return img

func _init_grid() -> void:
	grid.clear()
	for x in range(MAP_WIDTH):
		var column: Array = []
		for y in range(MAP_HEIGHT):
			column.append(TerrainType.WATER)
		grid.append(column)

func _generate_initial_world() -> void:
	# Create a central island surrounded by ocean
	var center_x := MAP_WIDTH / 2
	var center_y := MAP_HEIGHT / 2
	var island_radius := 35
	
	for x in range(MAP_WIDTH):
		for y in range(MAP_HEIGHT):
			var dist := Vector2(x - center_x, y - center_y).length()
			if dist < island_radius - 10:
				# Inner island core: Plain & Mountains
				if dist < island_radius - 22:
					grid[x][y] = TerrainType.MOUNTAIN
				else:
					grid[x][y] = TerrainType.PLAIN
			elif dist < island_radius:
				# Island outer ring: Plain
				grid[x][y] = TerrainType.PLAIN
			else:
				grid[x][y] = TerrainType.WATER
				
	# Refresh all cells visually
	for x in range(MAP_WIDTH):
		for y in range(MAP_HEIGHT):
			_update_cell_visual(x, y)

func paint_cells(center_coords: Vector2i, brush_radius: int, tool_type: TerrainType) -> void:
	var extents := brush_radius - 1
	var min_x := clampi(center_coords.x - extents, 0, MAP_WIDTH - 1)
	var max_x := clampi(center_coords.x + extents, 0, MAP_WIDTH - 1)
	var min_y := clampi(center_coords.y - extents, 0, MAP_HEIGHT - 1)
	var max_y := clampi(center_coords.y + extents, 0, MAP_HEIGHT - 1)
	
	var changed_cells: Array[Vector2i] = []
	
	for x in range(min_x, max_x + 1):
		for y in range(min_y, max_y + 1):
			if grid[x][y] != tool_type:
				grid[x][y] = tool_type
				changed_cells.append(Vector2i(x, y))
				
	# Update changed cells and their 8-way neighbors for shore transitions
	var to_update: Dictionary = {}
	for cell in changed_cells:
		for dx in range(-1, 2):
			for dy in range(-1, 2):
				var nx: int = cell.x + dx
				var ny: int = cell.y + dy
				if is_valid_coords(Vector2i(nx, ny)):
					to_update[Vector2i(nx, ny)] = true
					
	for cell in to_update.keys():
		_update_cell_visual(cell.x, cell.y)

func _update_cell_visual(x: int, y: int) -> void:
	var base_type: TerrainType = grid[x][y]
	var atlas_pos: Vector2i = ATLAS_WATER
	
	var has_water_neighbor := _has_neighbor_of_type(x, y, TerrainType.WATER)
	
	match base_type:
		TerrainType.WATER:
			if _has_neighbor_of_type(x, y, TerrainType.PLAIN) or _has_neighbor_of_type(x, y, TerrainType.MOUNTAIN):
				atlas_pos = ATLAS_SHALLOW_WATER
			else:
				atlas_pos = ATLAS_WATER
		TerrainType.PLAIN:
			if has_water_neighbor:
				atlas_pos = ATLAS_SHORE
			else:
				atlas_pos = ATLAS_PLAIN
		TerrainType.MOUNTAIN:
			if has_water_neighbor:
				atlas_pos = ATLAS_MOUNTAIN
			else:
				atlas_pos = ATLAS_MOUNTAIN
				
	tile_map_layer.set_cell(Vector2i(x, y), 0, atlas_pos)

func _has_neighbor_of_type(x: int, y: int, target_type: TerrainType) -> bool:
	for dx in range(-1, 2):
		for dy in range(-1, 2):
			if dx == 0 and dy == 0:
				continue
			var nx := x + dx
			var ny := y + dy
			if is_valid_coords(Vector2i(nx, ny)):
				if grid[nx][ny] == target_type:
					return true
	return false

func _is_surrounded_by_type(x: int, y: int, target_type: TerrainType) -> bool:
	for dx in range(-1, 2):
		for dy in range(-1, 2):
			if dx == 0 and dy == 0:
				continue
			var nx := x + dx
			var ny := y + dy
			if is_valid_coords(Vector2i(nx, ny)):
				if grid[nx][ny] != target_type:
					return false
	return true

func is_valid_coords(coords: Vector2i) -> bool:
	return coords.x >= 0 and coords.x < MAP_WIDTH and coords.y >= 0 and coords.y < MAP_HEIGHT

func world_to_tile(world_pos: Vector2) -> Vector2i:
	return Vector2i(floor(world_pos.x / TILE_SIZE), floor(world_pos.y / TILE_SIZE))

func tile_to_world(tile_coords: Vector2i) -> Vector2:
	return Vector2(tile_coords.x * TILE_SIZE, tile_coords.y * TILE_SIZE)

# ─── Resource Spawning ───────────────────────────────────────────────

func _spawn_resources() -> void:
	# Spawn resource nodes on PLAIN tiles
	var rng := RandomNumberGenerator.new()
	rng.seed = 42  # Deterministic for reproducibility
	
	# Cluster definitions: [type, cluster_count, nodes_per_cluster]
	var clusters: Array = [
		[GameData.ResourceType.WOOD,  40, 3],
		[GameData.ResourceType.ORE,   15, 2],
		[GameData.ResourceType.GOLD,  10, 1],
		[GameData.ResourceType.STONE, 15, 2],
	]
	
	for cluster_def in clusters:
		var res_type: GameData.ResourceType = cluster_def[0]
		var cluster_count: int = cluster_def[1]
		var per_cluster: int = cluster_def[2]
		
		for _c in range(cluster_count):
			# Pick random center on PLAIN terrain
			var center := _find_random_plain_tile(rng)
			if center == Vector2i(-1, -1):
				continue
			
			for _n in range(per_cluster):
				var offset := Vector2i(rng.randi_range(-2, 2), rng.randi_range(-2, 2))
				var tile := center + offset
				if not is_valid_coords(tile):
					continue
				if grid[tile.x][tile.y] != TerrainType.PLAIN:
					continue
				if _has_resource_at(tile):
					continue
				
				var node := ResourceNode.create(res_type, tile, TILE_SIZE)
				add_child(node)
				resource_nodes.append(node)

func _find_random_plain_tile(rng: RandomNumberGenerator) -> Vector2i:
	for _attempt in range(50):
		var x := rng.randi_range(0, MAP_WIDTH - 1)
		var y := rng.randi_range(0, MAP_HEIGHT - 1)
		if grid[x][y] == TerrainType.PLAIN:
			return Vector2i(x, y)
	return Vector2i(-1, -1)

func _has_resource_at(tile: Vector2i) -> bool:
	for node in resource_nodes:
		if node.tile_position == tile:
			return true
	return false

# ─── Building Tile Tracking ──────────────────────────────────────────

func register_building_tiles(building: Building) -> void:
	for tile in building.get_occupied_tiles():
		occupied_tiles[tile] = true

func unregister_building_tiles(building: Building) -> void:
	for tile in building.get_occupied_tiles():
		occupied_tiles.erase(tile)

func is_tile_occupied(tile: Vector2i) -> bool:
	return occupied_tiles.has(tile)

# ─── Resource Queries ────────────────────────────────────────────────

func get_nearest_resource(pos: Vector2, type: GameData.ResourceType = -1) -> ResourceNode:
	var best: ResourceNode = null
	var best_dist: float = INF
	for node in resource_nodes:
		if type >= 0 and node.resource_type != type:
			continue
		if not node.can_gather():
			continue
		var dist := pos.distance_to(node.global_position)
		if dist < best_dist:
			best_dist = dist
			best = node
	return best

func is_buildable(tile: Vector2i) -> bool:
	if not is_valid_coords(tile):
		return false
	if grid[tile.x][tile.y] != TerrainType.PLAIN:
		return false
	if is_tile_occupied(tile):
		return false
	if _has_resource_at(tile):
		return false
	return true
