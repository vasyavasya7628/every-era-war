class_name GameHUD
extends CanvasLayer

## In-game HUD showing resources, spawn controls, build menu, and faction info.

var player_faction: Faction = null
var unit_spawner: UnitSpawner = null
var building_placer: BuildingPlacer = null
var game_manager: GameManager = null

# UI References (created in _ready)
var resource_panel: PanelContainer
var lbl_wood: Label
var lbl_gold: Label
var lbl_ore: Label
var lbl_stone: Label

var faction_panel: PanelContainer
var lbl_population: Label
var lbl_development: Label
var lbl_territory: Label

var action_panel: PanelContainer
var btn_spawn: Button
var btn_house: Button
var btn_forge: Button
var btn_mine: Button

var info_label: Label
var combat_log_label: Label
var combat_log_timer: float = 0.0

func _ready() -> void:
	layer = 1
	_build_ui()

func initialize(faction: Faction, spawner: UnitSpawner, placer: BuildingPlacer, gm: GameManager) -> void:
	player_faction = faction
	unit_spawner = spawner
	building_placer = placer
	game_manager = gm

	# Connect signals
	if game_manager:
		game_manager.combat_occurred.connect(_on_combat)
		game_manager.game_over_signal.connect(_on_game_over)

func _process(delta: float) -> void:
	if player_faction == null:
		return
	_update_resources()
	_update_faction_info()
	_update_action_buttons()

	# Fade combat log
	if combat_log_timer > 0:
		combat_log_timer -= delta
		if combat_log_timer <= 0 and combat_log_label:
			combat_log_label.text = ""

# ─── UI Construction ─────────────────────────────────────────────────

func _build_ui() -> void:
	# ── Resource Bar (top-right) ──
	var res_margin := MarginContainer.new()
	res_margin.anchors_preset = Control.PRESET_TOP_RIGHT
	res_margin.anchor_left = 1.0
	res_margin.anchor_right = 1.0
	res_margin.offset_left = -320
	res_margin.offset_bottom = 60
	res_margin.add_theme_constant_override("margin_left", 8)
	res_margin.add_theme_constant_override("margin_top", 8)
	res_margin.add_theme_constant_override("margin_right", 8)
	res_margin.add_theme_constant_override("margin_bottom", 8)
	add_child(res_margin)

	resource_panel = PanelContainer.new()
	res_margin.add_child(resource_panel)

	var res_inner_margin := MarginContainer.new()
	res_inner_margin.add_theme_constant_override("margin_left", 8)
	res_inner_margin.add_theme_constant_override("margin_top", 4)
	res_inner_margin.add_theme_constant_override("margin_right", 8)
	res_inner_margin.add_theme_constant_override("margin_bottom", 4)
	resource_panel.add_child(res_inner_margin)

	var res_inner_hbox := HBoxContainer.new()
	res_inner_hbox.add_theme_constant_override("separation", 14)
	res_inner_margin.add_child(res_inner_hbox)

	lbl_wood = _make_resource_label("Wood: 0", res_inner_hbox)
	lbl_gold = _make_resource_label("Gold: 0", res_inner_hbox)
	lbl_ore = _make_resource_label("Ore: 0", res_inner_hbox)
	lbl_stone = _make_resource_label("Stone: 0", res_inner_hbox)

	# ── Faction Info (top-left, below god tools) ──
	var faction_margin := MarginContainer.new()
	faction_margin.anchors_preset = Control.PRESET_TOP_LEFT
	faction_margin.offset_top = 90
	faction_margin.offset_right = 280
	faction_margin.offset_bottom = 180
	faction_margin.add_theme_constant_override("margin_left", 16)
	faction_margin.add_theme_constant_override("margin_top", 8)
	faction_margin.add_theme_constant_override("margin_right", 8)
	faction_margin.add_theme_constant_override("margin_bottom", 8)
	add_child(faction_margin)

	faction_panel = PanelContainer.new()
	faction_margin.add_child(faction_panel)

	var faction_inner := MarginContainer.new()
	faction_inner.add_theme_constant_override("margin_left", 8)
	faction_inner.add_theme_constant_override("margin_top", 6)
	faction_inner.add_theme_constant_override("margin_right", 8)
	faction_inner.add_theme_constant_override("margin_bottom", 6)
	faction_panel.add_child(faction_inner)

	var faction_vbox := VBoxContainer.new()
	faction_vbox.add_theme_constant_override("separation", 4)
	faction_inner.add_child(faction_vbox)

	lbl_population = Label.new()
	lbl_population.text = "Population: 0"
	faction_vbox.add_child(lbl_population)

	lbl_development = Label.new()
	lbl_development.text = "Development: 0"
	faction_vbox.add_child(lbl_development)

	lbl_territory = Label.new()
	lbl_territory.text = "Territory: 0"
	faction_vbox.add_child(lbl_territory)

	# ── Action Panel (bottom-center) ──
	var action_margin := MarginContainer.new()
	action_margin.anchors_preset = Control.PRESET_BOTTOM_WIDE
	action_margin.anchor_top = 1.0
	action_margin.anchor_bottom = 1.0
	action_margin.anchor_right = 1.0
	action_margin.offset_top = -70
	action_margin.add_theme_constant_override("margin_left", 200)
	action_margin.add_theme_constant_override("margin_bottom", 16)
	action_margin.add_theme_constant_override("margin_right", 200)
	add_child(action_margin)

	action_panel = PanelContainer.new()
	action_margin.add_child(action_panel)

	var action_inner := MarginContainer.new()
	action_inner.add_theme_constant_override("margin_left", 8)
	action_inner.add_theme_constant_override("margin_top", 6)
	action_inner.add_theme_constant_override("margin_right", 8)
	action_inner.add_theme_constant_override("margin_bottom", 6)
	action_panel.add_child(action_inner)

	var action_hbox := HBoxContainer.new()
	action_hbox.add_theme_constant_override("separation", 8)
	action_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	action_inner.add_child(action_hbox)

	btn_spawn = Button.new()
	btn_spawn.text = " 👤 Spawn Human [H] "
	btn_spawn.toggle_mode = true
	btn_spawn.pressed.connect(_on_spawn_pressed)
	action_hbox.add_child(btn_spawn)

	var sep := VSeparator.new()
	action_hbox.add_child(sep)

	btn_house = Button.new()
	btn_house.text = " 🏠 House "
	btn_house.pressed.connect(func(): _on_build_pressed(GameData.BuildingType.HOUSE))
	action_hbox.add_child(btn_house)

	btn_forge = Button.new()
	btn_forge.text = " ⚒ Forge "
	btn_forge.pressed.connect(func(): _on_build_pressed(GameData.BuildingType.FORGE))
	action_hbox.add_child(btn_forge)

	btn_mine = Button.new()
	btn_mine.text = " ⛏ Mine "
	btn_mine.pressed.connect(func(): _on_build_pressed(GameData.BuildingType.MINE))
	action_hbox.add_child(btn_mine)

	# ── Combat Log (bottom-left) ──
	var log_margin := MarginContainer.new()
	log_margin.anchors_preset = Control.PRESET_BOTTOM_LEFT
	log_margin.anchor_top = 1.0
	log_margin.anchor_bottom = 1.0
	log_margin.offset_top = -100
	log_margin.offset_right = 400
	log_margin.add_theme_constant_override("margin_left", 16)
	log_margin.add_theme_constant_override("margin_bottom", 80)
	add_child(log_margin)

	combat_log_label = Label.new()
	combat_log_label.add_theme_color_override("font_color", Color.YELLOW)
	log_margin.add_child(combat_log_label)

	# ── Mode Info ──
	info_label = Label.new()
	info_label.anchors_preset = Control.PRESET_TOP_WIDE
	info_label.offset_top = 70
	info_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.7))
	add_child(info_label)

func _make_resource_label(initial_text: String, parent: Control) -> Label:
	var lbl := Label.new()
	lbl.text = initial_text
	parent.add_child(lbl)
	return lbl

# ─── Updates ─────────────────────────────────────────────────────────

func _update_resources() -> void:
	if lbl_wood:
		lbl_wood.text = "Wood: %d" % player_faction.get_resource(GameData.ResourceType.WOOD)
	if lbl_gold:
		lbl_gold.text = "Gold: %d" % player_faction.get_resource(GameData.ResourceType.GOLD)
	if lbl_ore:
		lbl_ore.text = "Ore: %d" % player_faction.get_resource(GameData.ResourceType.ORE)
	if lbl_stone:
		lbl_stone.text = "Stone: %d" % player_faction.get_resource(GameData.ResourceType.STONE)

func _update_faction_info() -> void:
	if lbl_population:
		lbl_population.text = "Population: %d" % player_faction.units.size()
	if lbl_development:
		lbl_development.text = "Development: %d" % player_faction.development_level
	if lbl_territory:
		lbl_territory.text = "Territory: %d tiles" % player_faction.territory_tiles.size()

func _update_action_buttons() -> void:
	# Update spawn button visual state
	if btn_spawn and unit_spawner:
		btn_spawn.button_pressed = unit_spawner.is_spawn_mode

	# Update build button availability (grey out if can't afford)
	_update_build_button(btn_house, GameData.BuildingType.HOUSE)
	_update_build_button(btn_forge, GameData.BuildingType.FORGE)
	_update_build_button(btn_mine, GameData.BuildingType.MINE)

func _update_build_button(btn: Button, btype: GameData.BuildingType) -> void:
	if btn == null:
		return
	var def: Dictionary = GameData.BUILDING_DEFS[btype]
	var can_afford: bool = player_faction.can_afford(def["cost"])
	btn.disabled = not can_afford
	btn.modulate = Color.WHITE if can_afford else Color(0.5, 0.5, 0.5)

# ─── Button Handlers ─────────────────────────────────────────────────

func _on_spawn_pressed() -> void:
	if unit_spawner:
		unit_spawner.toggle()
		# Cancel building placement if active
		if building_placer and building_placer.is_placing:
			building_placer.cancel_placement()
	if info_label:
		if unit_spawner and unit_spawner.is_spawn_mode:
			info_label.text = "Click on the map to spawn a human"
		else:
			info_label.text = ""

func _on_build_pressed(btype: GameData.BuildingType) -> void:
	if building_placer:
		building_placer.start_placement(btype)
		# Deactivate spawn mode
		if unit_spawner and unit_spawner.is_spawn_mode:
			unit_spawner.deactivate()
			if btn_spawn:
				btn_spawn.button_pressed = false
	if info_label:
		var def: Dictionary = GameData.BUILDING_DEFS[btype]
		info_label.text = "Place %s — Left Click to place, Right Click to cancel" % def["name"]

# ─── Events ──────────────────────────────────────────────────────────

func _on_combat(_attacker: Faction, _defender: Faction, result: String) -> void:
	if combat_log_label:
		combat_log_label.text = "⚔ " + result
		combat_log_timer = 8.0

func _on_game_over(winner: Faction) -> void:
	if info_label:
		if winner.is_player:
			info_label.text = "🏆 VICTORY! Your faction has won!"
		else:
			info_label.text = "💀 DEFEAT! %s has conquered all!" % winner.faction_name
		info_label.add_theme_font_size_override("font_size", 24)

# ─── Input (hotkeys) ────────────────────────────────────────────────

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_H:
				_on_spawn_pressed()
