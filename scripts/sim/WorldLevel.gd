@tool
class_name WorldLevel
extends Node2D

@export
var grid_size: = Vector2i(200, 200):
	set(value):
		grid_size = value
		_recreate_world()

@export
var cell_size: = Vector2i(100, 100):
	set(value):
		cell_size = value
		_update_world_visuals()

@export_group("Debug Drawing")
@export
var draw_world_border := false:
	set(value):
		draw_world_border = value
		queue_redraw()

@export
var world_border_color := Color(1.0, 0.92, 0.25, 0.9):
	set(value):
		world_border_color = value
		queue_redraw()

@export_range(1.0, 100.0, 0.5)
var world_border_width := 3.0:
	set(value):
		world_border_width = value
		queue_redraw()

@export
var draw_editor_grid_lines := false:
	set(value):
		draw_editor_grid_lines = value
		queue_redraw()

@export
var editor_grid_line_color := Color(0.35, 0.85, 1.0, 0.22):
	set(value):
		editor_grid_line_color = value
		queue_redraw()

@export_range(1, 64, 1)
var editor_grid_line_step := 1:
	set(value):
		editor_grid_line_step = maxi(1, value)
		queue_redraw()

@export_group("Shader Grid Data")
@export
var send_grid_data_to_background_shader := true:
	set(value):
		send_grid_data_to_background_shader = value
		_update_background_shader(true)
@export_range(0.0, 60.0, 0.1, "suffix:Hz")
var grid_data_updates_per_second := 10.0

@export_group("World Camera")
@export var camera_controls_enabled := true
@export_range(0.01, 20.0, 0.001) var min_camera_zoom := 0.25:
	set(value):
		min_camera_zoom = value
		_clamp_camera_zoom()
@export_range(0.05, 20.0, 0.05) var max_camera_zoom := 3.0:
	set(value):
		max_camera_zoom = value
		_clamp_camera_zoom()
@export_range(0.01, 2.0, 0.01) var camera_zoom_step := 0.12
@export_range(1.0, 5000.0, 1.0, "suffix:px/s") var camera_pan_speed := 900.0
@export var camera_drag_button := MOUSE_BUTTON_MIDDLE

@export_group("Ant Selection")
@export var ant_highlight: CanvasGroup
@export var target_point_scene: PackedScene = preload("res://objects/TargetPoint.tscn")
@export_range(1.0, 500.0, 1.0, "suffix:px") var ant_selection_radius := 120.0
@export_range(1.0, 500.0, 1.0, "suffix:px") var target_point_toggle_radius := 120.0

@onready var grid_background: Sprite2D = %GridBackground
@onready var world_camera: Camera2D = %WorldCamera
@onready var default_ant_parent: Node = self

var world: World
var _grid_data_image: Image
var _grid_data_texture: ImageTexture
var _grid_data_bytes := PackedByteArray()
var _grid_data_dirty := true
var _grid_data_update_accumulator := 0.0
var _grid_data_timestamp_ms := 0.0
var _should_restore_grid_data_texture_after_save := false
var _camera_dragging := false
var _camera_drag_last_position := Vector2.ZERO
var _selected_ants: Array[Ant] = []
var _ant_original_parents: Dictionary[int, Node] = {}
var _target_point: Node2D

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	if ant_highlight == null and has_node("%AntHighlight"):
		ant_highlight = %AntHighlight
	_recreate_world()
	_setup_world_camera()
	Gamestate.start_run()

func _notification(what: int) -> void:
	if not Engine.is_editor_hint():
		return

	if what == NOTIFICATION_EDITOR_PRE_SAVE:
		_clear_grid_data_texture_before_save()
	elif what == NOTIFICATION_EDITOR_POST_SAVE:
		_restore_grid_data_texture_after_save()

func _recreate_world():
	if not is_inside_tree():
		return

	world = World.new()
	world.size = grid_size
	world.init()
	_grid_data_dirty = true
	_update_world_visuals()

func _update_world_visuals() -> void:
	if not is_inside_tree():
		return

	var world_size := _world_pixel_size()
	if is_instance_valid(grid_background) and grid_background.texture:
		grid_background.scale = world_size / grid_background.texture.get_size()

	queue_redraw()
	_update_background_shader(true)
	_clamp_camera_to_world()


func _setup_world_camera() -> void:
	if not is_instance_valid(world_camera):
		return

	world_camera.make_current()
	_clamp_camera_zoom()
	_clamp_camera_to_world()


func _unhandled_input(event: InputEvent) -> void:
	if Engine.is_editor_hint() or not camera_controls_enabled or not is_instance_valid(world_camera):
		return

	if event is InputEventMouseButton:
		_handle_camera_mouse_button(event as InputEventMouseButton)
	elif event is InputEventMouseMotion and _camera_dragging:
		_pan_camera_by_screen_delta((event as InputEventMouseMotion).relative)


func _handle_camera_mouse_button(event: InputEventMouseButton) -> void:
	if event.button_index == camera_drag_button:
		_camera_dragging = event.pressed
		_camera_drag_last_position = event.position
		get_viewport().set_input_as_handled()
	elif event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_select_ants_at(get_global_mouse_position())
		get_viewport().set_input_as_handled()
	elif event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		_toggle_selected_ants_target(get_global_mouse_position())
		get_viewport().set_input_as_handled()
	elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_UP:
		_zoom_camera(1.0 + camera_zoom_step)
		get_viewport().set_input_as_handled()
	elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
		_zoom_camera(1.0 / (1.0 + camera_zoom_step))
		get_viewport().set_input_as_handled()


func _update_camera_keyboard_pan(delta: float) -> void:
	if Engine.is_editor_hint() or not camera_controls_enabled or not is_instance_valid(world_camera):
		return

	var direction := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	if direction == Vector2.ZERO:
		return

	var zoom := _camera_zoom_value()
	world_camera.global_position += direction * camera_pan_speed * delta / zoom
	_clamp_camera_to_world()


func _pan_camera_by_screen_delta(screen_delta: Vector2) -> void:
	var zoom := _camera_zoom_value()
	world_camera.global_position -= screen_delta / zoom
	_clamp_camera_to_world()


func _zoom_camera(factor: float) -> void:
	var zoom := clampf(_camera_zoom_value() * factor, _min_camera_zoom_value(), _max_camera_zoom_value())
	world_camera.zoom = Vector2(zoom, zoom)
	_clamp_camera_to_world()


func _clamp_camera_zoom() -> void:
	if not is_instance_valid(world_camera):
		return

	var zoom := clampf(_camera_zoom_value(), _min_camera_zoom_value(), _max_camera_zoom_value())
	world_camera.zoom = Vector2(zoom, zoom)
	_clamp_camera_to_world()


func _clamp_camera_to_world() -> void:
	if not is_instance_valid(world_camera):
		return

	var world_rect := _world_rect_global()
	var viewport_size := get_viewport_rect().size / _camera_zoom_value()
	var min_position := world_rect.position + viewport_size * 0.5
	var max_position := world_rect.end - viewport_size * 0.5
	var position := world_camera.global_position

	if min_position.x > max_position.x:
		position.x = world_rect.get_center().x
	else:
		position.x = clampf(position.x, min_position.x, max_position.x)

	if min_position.y > max_position.y:
		position.y = world_rect.get_center().y
	else:
		position.y = clampf(position.y, min_position.y, max_position.y)

	world_camera.global_position = position


func _camera_zoom_value() -> float:
	if not is_instance_valid(world_camera):
		return 1.0

	return maxf(world_camera.zoom.x, 0.001)


func _min_camera_zoom_value() -> float:
	return minf(min_camera_zoom, max_camera_zoom)


func _max_camera_zoom_value() -> float:
	return maxf(min_camera_zoom, max_camera_zoom)


func _select_ants_at(world_position: Vector2) -> void:
	var ants := _get_ants_in_radius(world_position, ant_selection_radius)
	_set_selected_ants(ants)


func _set_selected_ants(ants: Array[Ant]) -> void:
	for ant in _selected_ants:
		if not is_instance_valid(ant):
			continue
		if not ants.has(ant):
			_deselect_ant(ant)

	for ant in ants:
		if not is_instance_valid(ant):
			continue
		if not _selected_ants.has(ant):
			_select_ant(ant)

	_selected_ants = ants

	if _selected_ants.is_empty():
		_clear_target_point()


func _select_ant(ant: Ant) -> void:
	if ant_highlight == null:
		return

	var parent := ant.get_parent()
	if parent != ant_highlight:
		_ant_original_parents[ant.get_instance_id()] = parent
		_reparent_node2d_preserve_global_transform(ant, ant_highlight)

	ant.selected_for_player_control = true
	if _target_point != null:
		ant.set_player_target(_target_point.global_position)


func _deselect_ant(ant: Ant) -> void:
	ant.clear_player_target()
	ant.selected_for_player_control = false

	var original_parent := _ant_original_parents.get(ant.get_instance_id(), default_ant_parent) as Node
	if original_parent != null and is_instance_valid(original_parent) and ant.get_parent() != original_parent:
		_reparent_node2d_preserve_global_transform(ant, original_parent)

	_ant_original_parents.erase(ant.get_instance_id())


func _toggle_selected_ants_target(world_position: Vector2) -> void:
	if _selected_ants.is_empty():
		return

	if _target_point != null and is_instance_valid(_target_point):
		if _target_point.global_position.distance_to(world_position) <= target_point_toggle_radius:
			_clear_target_point()
			return

	_clear_target_point()
	_target_point = _create_target_point(world_position)
	for ant in _selected_ants:
		if is_instance_valid(ant):
			ant.set_player_target(world_position)


func _create_target_point(world_position: Vector2) -> Node2D:
	var target: Node2D
	if target_point_scene != null:
		target = target_point_scene.instantiate() as Node2D

	if target == null:
		target = Node2D.new()
		target.name = "TargetPoint"

	add_child(target)
	target.global_position = world_position
	return target


func _clear_target_point() -> void:
	for ant in _selected_ants:
		if is_instance_valid(ant):
			ant.clear_player_target()

	if _target_point != null and is_instance_valid(_target_point):
		_target_point.queue_free()
	_target_point = null


func _get_ants_in_radius(world_position: Vector2, radius: float) -> Array[Ant]:
	var ants: Array[Ant] = []
	var radius_squared := radius * radius
	for ant in _get_all_ants():
		if ant.global_position.distance_squared_to(world_position) <= radius_squared:
			ants.append(ant)

	return ants


func _get_all_ants() -> Array[Ant]:
	var ants: Array[Ant] = []
	_collect_ants(self, ants)
	return ants


func _collect_ants(node: Node, ants: Array[Ant]) -> void:
	if node is Ant:
		ants.append(node as Ant)

	for child in node.get_children():
		_collect_ants(child, ants)


func _reparent_node2d_preserve_global_transform(node: Node2D, new_parent: Node) -> void:
	var previous_global_transform := node.global_transform
	node.get_parent().remove_child(node)
	new_parent.add_child(node)
	node.global_transform = previous_global_transform

func _draw() -> void:
	var world_rect := _world_rect()

	if draw_editor_grid_lines and Engine.is_editor_hint():
		_draw_editor_grid(world_rect)

	if draw_world_border:
		draw_rect(world_rect, world_border_color, false, world_border_width)

func _draw_editor_grid(world_rect: Rect2) -> void:
	var step := maxi(1, editor_grid_line_step)
	var line_width := 3.0

	for x in range(0, grid_size.x + 1, step):
		var local_x := world_rect.position.x + x * cell_size.x
		draw_line(
			Vector2(local_x, world_rect.position.y),
			Vector2(local_x, world_rect.position.y + world_rect.size.y),
			editor_grid_line_color,
			line_width
		)

	for y in range(0, grid_size.y + 1, step):
		var local_y := world_rect.position.y + y * cell_size.y
		draw_line(
			Vector2(world_rect.position.x, local_y),
			Vector2(world_rect.position.x + world_rect.size.x, local_y),
			editor_grid_line_color,
			line_width
		)

func _update_background_shader(update_grid_texture := false) -> void:
	if not is_inside_tree() or not is_instance_valid(grid_background):
		return

	var material := grid_background.material as ShaderMaterial
	if material == null:
		return

	material.set_shader_parameter("grid_world_rect", _world_rect_shader_value())
	material.set_shader_parameter("grid_resolution", grid_size)
	material.set_shader_parameter("grid_cell_size", Vector2(cell_size))
	_set_background_shader_parameter(material, "grid_timestamp_ms", _grid_data_timestamp_ms, true)
	material.set_shader_parameter("grid_phero_max", float(World.PHERO_MAX))
	material.set_shader_parameter("grid_field_count", World.IntField.Count)
	material.set_shader_parameter("show_grid_data", send_grid_data_to_background_shader)

	if send_grid_data_to_background_shader and world != null:
		if update_grid_texture:
			_update_grid_data_texture()
		if _grid_data_texture != null:
			_set_background_shader_parameter(material, "grid_data_texture", _grid_data_texture, true)

func _clear_grid_data_texture_before_save() -> void:
	var material := _background_shader_material()
	if material == null:
		return

	_should_restore_grid_data_texture_after_save = material.get_shader_parameter("grid_data_texture") != null
	material.set_shader_parameter("grid_data_texture", null)
	material.set_shader_parameter("grid_timestamp_ms", 0.0)

func _restore_grid_data_texture_after_save() -> void:
	if not _should_restore_grid_data_texture_after_save:
		return

	_should_restore_grid_data_texture_after_save = false
	_grid_data_dirty = true
	_update_background_shader(true)

func _background_shader_material() -> ShaderMaterial:
	if not is_instance_valid(grid_background):
		return null

	return grid_background.material as ShaderMaterial

func _set_background_shader_parameter(material: ShaderMaterial, parameter: StringName, value: Variant, volatile_in_editor := false) -> void:
	if Engine.is_editor_hint() and volatile_in_editor:
		if value is Texture2D:
			value = value.get_rid()
		RenderingServer.material_set_param(material.get_rid(), parameter, value)
	else:
		material.set_shader_parameter(parameter, value)

func _update_grid_data_texture() -> void:
	if world == null or world.int_data.is_empty():
		return

	var width := world.size.x
	var height := world.size.y * World.IntField.Count
	if width <= 0 or height <= 0:
		return

	if _grid_data_image == null or _grid_data_image.get_width() != width or _grid_data_image.get_height() != height:
		_grid_data_image = Image.create(width, height, false, Image.FORMAT_RF)
		_grid_data_bytes.resize(width * height * 4)
		_grid_data_dirty = true

	if _grid_data_dirty:
		_grid_data_timestamp_ms = float(Time.get_ticks_msec())
		for y in range(world.size.y):
			for x in range(world.size.x):
				for phero in [World.IntField.PheroHome, World.IntField.PheroFood]:
					var texture_y = y * 2 + phero
					var pixel_index = texture_y * width + x
					_grid_data_bytes.encode_float(pixel_index * 4, float(world.phero_at(x, y, phero)))

		_grid_data_image.set_data(width, height, false, Image.FORMAT_RF, _grid_data_bytes)

		if _grid_data_texture == null:
			_grid_data_texture = ImageTexture.create_from_image(_grid_data_image)
		else:
			_grid_data_texture.update(_grid_data_image)

		_grid_data_dirty = false

func _world_pixel_size() -> Vector2:
	return Vector2(grid_size) * Vector2(cell_size)

func _world_rect() -> Rect2:
	var world_size := _world_pixel_size()
	if is_instance_valid(grid_background):
		if grid_background.centered:
			return Rect2(grid_background.position - world_size * 0.5, world_size)
		return Rect2(grid_background.position, world_size)

	return Rect2(-world_size * 0.5, world_size)

func _world_rect_global() -> Rect2:
	var rect := _world_rect()
	var corners := [
		rect.position,
		rect.position + Vector2(rect.size.x, 0.0),
		rect.position + rect.size,
		rect.position + Vector2(0.0, rect.size.y),
	]
	var global_rect := Rect2(to_global(corners[0]), Vector2.ZERO)

	for corner in corners:
		global_rect = global_rect.expand(to_global(corner))

	return global_rect

func _world_rect_shader_value() -> Vector4:
	var rect := _world_rect()
	return Vector4(rect.position.x, rect.position.y, rect.size.x, rect.size.y)

func world_position_to_cell(world_position: Vector2) -> Vector2i:
	var local_position := to_local(world_position)
	var rect := _world_rect()
	var cell := Vector2i(floor((local_position - rect.position) / Vector2(cell_size)))
	return clamp_cell(cell)

func cell_to_world_rect(cell: Vector2i) -> Rect2:
	var rect := _world_rect()
	var clamped_cell := clamp_cell(cell)
	var local_position := rect.position + Vector2(clamped_cell) * Vector2(cell_size)
	return Rect2(to_global(local_position), Vector2(cell_size) * global_scale.abs())

func cell_center_to_world(cell: Vector2i) -> Vector2:
	return cell_to_world_rect(cell).get_center()

func random_point_in_cell(cell: Vector2i) -> Vector2:
	var rect := cell_to_world_rect(cell)
	return Vector2(
		randf_range(rect.position.x, rect.position.x + rect.size.x),
		randf_range(rect.position.y, rect.position.y + rect.size.y)
	)

func clamp_cell(cell: Vector2i) -> Vector2i:
	if world == null:
		return cell

	return Vector2i(
		clampi(cell.x, 0, world.size.x - 1),
		clampi(cell.y, 0, world.size.y - 1)
	)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	_update_camera_keyboard_pan(_delta)

	if send_grid_data_to_background_shader:
		var should_update_grid_texture := _should_update_grid_data_texture(_delta)
		if should_update_grid_texture:
			_grid_data_dirty = true
		_update_background_shader(should_update_grid_texture)


func _should_update_grid_data_texture(delta: float) -> bool:
	if grid_data_updates_per_second <= 0.0:
		return false

	_grid_data_update_accumulator += delta
	var interval := 1.0 / grid_data_updates_per_second
	if _grid_data_update_accumulator < interval:
		return false

	_grid_data_update_accumulator = fmod(_grid_data_update_accumulator, interval)
	return true
