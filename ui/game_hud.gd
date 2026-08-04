class_name GameHUD
extends CanvasLayer

## In-game HUD showing spawn controls and action buttons.

var unit_spawner: UnitSpawner = null
var building_placer: BuildingPlacer = null
var game_manager: GameManager = null

var action_panel: PanelContainer
var btn_spawn: Button
var btn_house: Button
var btn_forge: Button
var btn_mine: Button

var info_label: Label
var combat_log_label: Label
var combat_log_timer: float = 0.0

var lbl_stats: Label
var total_game_time: float = 0.0

func _ready() -> void:
	layer = 1
	_build_ui()

func initialize(_faction: Faction, spawner: UnitSpawner, placer: BuildingPlacer, gm: GameManager) -> void:
	unit_spawner = spawner
	building_placer = placer
	game_manager = gm

	# Connect signals
	if game_manager:
		game_manager.combat_occurred.connect(_on_combat)
		game_manager.game_over_signal.connect(_on_game_over)

func _process(delta: float) -> void:
	total_game_time += delta
	_update_stats()
	_update_action_buttons()

	# Fade combat log
	if combat_log_timer > 0:
		combat_log_timer -= delta
		if combat_log_timer <= 0 and combat_log_label:
			combat_log_label.text = ""

func _update_stats() -> void:
	if lbl_stats:
		# 1 year = 20 seconds real-time
		var current_year: int = int(total_game_time / 20.0) + 1
		var fps: int = Engine.get_frames_per_second()
		lbl_stats.text = "Year %d  |  FPS: %d" % [current_year, fps]

# ─── UI Construction ─────────────────────────────────────────────────

func _build_ui() -> void:
	# ── Stats Bar (Year & FPS top-right) ──
	var stats_margin := MarginContainer.new()
	stats_margin.anchors_preset = Control.PRESET_TOP_RIGHT
	stats_margin.anchor_left = 1.0
	stats_margin.anchor_right = 1.0
	stats_margin.offset_left = -220
	stats_margin.offset_bottom = 50
	stats_margin.add_theme_constant_override("margin_left", 8)
	stats_margin.add_theme_constant_override("margin_top", 8)
	stats_margin.add_theme_constant_override("margin_right", 8)
	stats_margin.add_theme_constant_override("margin_bottom", 8)
	add_child(stats_margin)

	var stats_panel := PanelContainer.new()
	stats_margin.add_child(stats_panel)

	var stats_inner := MarginContainer.new()
	stats_inner.add_theme_constant_override("margin_left", 8)
	stats_inner.add_theme_constant_override("margin_top", 4)
	stats_inner.add_theme_constant_override("margin_right", 8)
	stats_inner.add_theme_constant_override("margin_bottom", 4)
	stats_panel.add_child(stats_inner)

	lbl_stats = Label.new()
	lbl_stats.text = "Year 1  |  FPS: --"
	stats_inner.add_child(lbl_stats)

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

# ─── Updates ─────────────────────────────────────────────────────────

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
	var pf: Faction = building_placer.player_faction if building_placer != null else null
	if pf == null:
		btn.disabled = true
		btn.modulate = Color(0.5, 0.5, 0.5)
		return
	var def: Dictionary = GameData.BUILDING_DEFS[btype]
	var can_afford: bool = pf.can_afford(def["cost"])
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
