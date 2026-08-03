class_name GodTools
extends CanvasLayer

const WorldScript = preload("res://world/world.gd")

signal tool_changed(tool_type: WorldScript.TerrainType)
signal brush_size_changed(size: int)

var current_tool: WorldScript.TerrainType = WorldScript.TerrainType.PLAIN
var brush_size: int = 1 # 1 = 1x1, 2 = 3x3, 3 = 5x5, 4 = 7x7

var is_painting: bool = false
var is_god_mode: bool = true  # Start in God Mode (terrain painting)
@export var world: Node2D
@export var brush_preview: Node2D

@onready var btn_land: Button = $MarginContainer/PanelContainer/HBoxContainer/BtnLand
@onready var btn_mountain: Button = $MarginContainer/PanelContainer/HBoxContainer/BtnMountain
@onready var btn_water: Button = $MarginContainer/PanelContainer/HBoxContainer/BtnWater
@onready var btn_brush_minus: Button = $MarginContainer/PanelContainer/HBoxContainer/BtnBrushMinus
@onready var btn_brush_plus: Button = $MarginContainer/PanelContainer/HBoxContainer/BtnBrushPlus
@onready var lbl_brush_size: Label = $MarginContainer/PanelContainer/HBoxContainer/LblBrushSize
@onready var lbl_status: Label = $MarginContainer/PanelContainer/HBoxContainer/LblStatus

func _ready() -> void:
	# Connect UI buttons
	btn_land.pressed.connect(func(): set_tool(WorldScript.TerrainType.PLAIN))
	btn_mountain.pressed.connect(func(): set_tool(WorldScript.TerrainType.MOUNTAIN))
	btn_water.pressed.connect(func(): set_tool(WorldScript.TerrainType.WATER))
	
	btn_brush_minus.pressed.connect(func(): set_brush_size(brush_size - 1))
	btn_brush_plus.pressed.connect(func(): set_brush_size(brush_size + 1))
	
	update_ui()
	_update_mode_visibility()

func set_tool(tool_type: WorldScript.TerrainType) -> void:
	current_tool = tool_type
	tool_changed.emit(current_tool)
	update_ui()

func set_brush_size(new_size: int) -> void:
	brush_size = clampi(new_size, 1, 5)
	brush_size_changed.emit(brush_size)
	update_ui()

func update_ui() -> void:
	if lbl_brush_size:
		lbl_brush_size.text = "Кисть: %dx%d" % [brush_size * 2 - 1, brush_size * 2 - 1]
		
	if lbl_status:
		var tool_name := "Суша (Равнина)"
		match current_tool:
			WorldScript.TerrainType.PLAIN:
				tool_name = "Суша (Равнина) [1]"
			WorldScript.TerrainType.MOUNTAIN:
				tool_name = "Горы [2]"
			WorldScript.TerrainType.WATER:
				tool_name = "Вода [3]"
		lbl_status.text = " Активный инструмент: " + tool_name

	# Update button styles / highlights
	if btn_land:
		btn_land.button_pressed = (current_tool == WorldScript.TerrainType.PLAIN)
	if btn_mountain:
		btn_mountain.button_pressed = (current_tool == WorldScript.TerrainType.MOUNTAIN)
	if btn_water:
		btn_water.button_pressed = (current_tool == WorldScript.TerrainType.WATER)

func _input(event: InputEvent) -> void:
	# Key shortcuts for tool selection (1, 2, 3)
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_1:
				set_tool(WorldScript.TerrainType.PLAIN)
			KEY_2:
				set_tool(WorldScript.TerrainType.MOUNTAIN)
			KEY_3:
				set_tool(WorldScript.TerrainType.WATER)
			KEY_BRACKETLEFT:
				set_brush_size(brush_size - 1)
			KEY_BRACKETRIGHT:
				set_brush_size(brush_size + 1)
			KEY_G:
				toggle_god_mode()
	# Mouse wheel + Ctrl for brush size adjust
	if event is InputEventMouseButton and event.pressed:
		if event.ctrl_pressed:
			if event.button_index == MOUSE_BUTTON_WHEEL_UP:
				set_brush_size(brush_size + 1)
				get_viewport().set_input_as_handled()
			elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				set_brush_size(brush_size - 1)
				get_viewport().set_input_as_handled()

func _unhandled_input(event: InputEvent) -> void:
	if not is_god_mode:
		return  # Disable terrain painting in Play Mode
	
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			is_painting = event.pressed
			if is_painting:
				_apply_paint()

	elif event is InputEventMouseMotion and is_painting:
		_apply_paint()

func _process(_delta: float) -> void:
	_update_brush_preview()

func _apply_paint() -> void:
	if world == null:
		return
	var mouse_world_pos: Vector2 = world.get_global_mouse_position()
	var tile_coords: Vector2i = world.world_to_tile(mouse_world_pos)
	if world.is_valid_coords(tile_coords):
		world.paint_cells(tile_coords, brush_size, current_tool)

func _update_brush_preview() -> void:
	if brush_preview == null or world == null:
		return
	var mouse_world_pos: Vector2 = world.get_global_mouse_position()
	var tile_coords: Vector2i = world.world_to_tile(mouse_world_pos)
	
	if brush_preview.has_method("update_preview"):
		brush_preview.update_preview(tile_coords, brush_size, world.is_valid_coords(tile_coords) and is_god_mode)

func toggle_god_mode() -> void:
	is_god_mode = not is_god_mode
	is_painting = false
	_update_mode_visibility()

func _update_mode_visibility() -> void:
	# Show/hide terrain painting UI based on mode
	var toolbar := $MarginContainer
	var info := $InfoMargin
	if toolbar:
		toolbar.visible = is_god_mode
	if info:
		info.visible = is_god_mode
	if brush_preview:
		brush_preview.visible = is_god_mode
