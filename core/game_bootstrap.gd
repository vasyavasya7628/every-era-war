class_name GameBootstrap
extends Node

## Bootstrap script that initializes all RTS game systems at runtime.
## Attached to the Main node — sets up factions, AI, HUD, spawners, etc.
## This avoids complex .tscn modifications and keeps wiring in code.

var game_manager: GameManager = null
var game_hud: GameHUD = null
var unit_spawner: UnitSpawner = null
var building_placer: BuildingPlacer = null
var ai_controllers: Array = []

func initialize(world: World) -> void:
	# ── Game Manager ──
	game_manager = GameManager.new()
	game_manager.name = "GameManager"
	world.add_child(game_manager)
	game_manager.initialize(world)

	# ── Unit Spawner (for player) ──
	unit_spawner = UnitSpawner.new()
	unit_spawner.name = "UnitSpawner"
	unit_spawner.world = world
	unit_spawner.player_faction = game_manager.player_faction
	world.add_child(unit_spawner)

	# ── Building Placer (for player) ──
	building_placer = BuildingPlacer.new()
	building_placer.name = "BuildingPlacer"
	building_placer.world = world
	building_placer.player_faction = game_manager.player_faction
	world.add_child(building_placer)

	# ── Territory Overlay ──
	var overlay := TerritoryOverlay.new()
	overlay.name = "TerritoryOverlay"
	overlay.factions = game_manager.factions
	overlay.tile_size = World.TILE_SIZE
	world.add_child(overlay)

	# ── Game HUD ──
	game_hud = GameHUD.new()
	game_hud.name = "GameHUD"
	world.add_child(game_hud)
	game_hud.initialize(
		game_manager.player_faction,
		unit_spawner,
		building_placer,
		game_manager
	)

	# ── Listen for dynamic faction creation ──
	game_manager.faction_formed.connect(func(f: Faction):
		if unit_spawner.player_faction == null:
			unit_spawner.player_faction = f
		if building_placer.player_faction == null:
			building_placer.player_faction = f
	)

	print("[GameBootstrap] RTS systems initialized dynamically")
