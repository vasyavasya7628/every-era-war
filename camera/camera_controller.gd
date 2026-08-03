class_name CameraController
extends Camera2D

@export var min_zoom: float = 0.2
@export var max_zoom: float = 4.0
@export var zoom_speed: float = 0.15

var is_panning: bool = false

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		# Panning start / stop with RMB or MMB
		if event.button_index == MOUSE_BUTTON_RIGHT or event.button_index == MOUSE_BUTTON_MIDDLE:
			if event.pressed:
				is_panning = true
			else:
				is_panning = false

		# Zooming with Wheel Up / Wheel Down
		elif event.pressed and (event.button_index == MOUSE_BUTTON_WHEEL_UP or event.button_index == MOUSE_BUTTON_WHEEL_DOWN):
			# Do not zoom if Ctrl is held down (Ctrl+Wheel is for brush size)
			if event.ctrl_pressed:
				return
				
			var old_zoom := zoom
			var zoom_factor := 1.15
			if event.button_index == MOUSE_BUTTON_WHEEL_UP:
				zoom *= zoom_factor
			else:
				zoom /= zoom_factor
				
			zoom = zoom.clamp(Vector2(min_zoom, min_zoom), Vector2(max_zoom, max_zoom))
			
			# Maintain mouse position anchor while zooming
			var mouse_pos := get_viewport().get_mouse_position()
			var viewport_size := get_viewport_rect().size
			var zoom_diff := (mouse_pos - viewport_size * 0.5)
			position += zoom_diff * (1.0 / old_zoom.x - 1.0 / zoom.x)

	elif event is InputEventMouseMotion and is_panning:
		# Translate camera position inversely proportional to zoom
		position -= event.relative / zoom.x
