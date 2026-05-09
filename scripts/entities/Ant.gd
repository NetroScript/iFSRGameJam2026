@tool
class_name Ant
extends Node2D

@onready var bbox_area: Area2D = %BBoxArea
@onready var bbox: CollisionShape2D = %BBox

@onready var mandible_left: Polygon2D = %MandibleLeft
@onready var mandible_right: Polygon2D = %MandibleRight
@onready var top_leg_left: Polygon2D = %TopLegLeft
@onready var top_leg_right: Polygon2D = %TopLegRight
@onready var middle_leg_left: Polygon2D = %MiddleLegLeft
@onready var middle_leg_right: Polygon2D = %MiddleLegRight
@onready var bottom_leg_left: Polygon2D = %BottomLegLeft
@onready var bottom_leg_right: Polygon2D = %BottomLegRight
@onready var body: Polygon2D = %Body
@onready var antenna_left: Polygon2D = %AntennaLeft
@onready var antenna_right: Polygon2D = %AntennaRight

@onready var carried_food_particle: TextureRect = %CarriedFoodParticle


@export_category("Animation")
@export var animate_on_ready := true
@export var animate_in_editor := false:
	set(value):
		animate_in_editor = value
		
		if not _is_ready or not Engine.is_editor_hint():
			return
		
		if animate_in_editor and animate_on_ready:
			start_animations()
		else:
			stop_animations()

@export_category("Mandibles")
@export_range(0.0, 45.0, 0.1, "degrees") var mandible_open_rotation := 10.0
@export_range(0.0, 45.0, 0.1, "degrees") var mandible_close_rotation := 2.0
@export_range(0.01, 2.0, 0.01, "suffix:s") var mandible_close_duration := 0.08
@export_range(0.01, 2.0, 0.01, "suffix:s") var mandible_open_duration := 0.14
@export_range(0.0, 5.0, 0.01, "suffix:s") var mandible_min_wait := 0.35
@export_range(0.0, 5.0, 0.01, "suffix:s") var mandible_max_wait := 1.6
@export_range(0.0, 1.0, 0.01) var mandible_rotation_randomness := 0.25
@export_range(0.0, 1.0, 0.01) var mandible_duration_randomness := 0.35
@export_range(0.0, 0.5, 0.01, "suffix:s") var mandible_closed_hold_max := 0.08
@export_range(0.0, 1.0, 0.01) var mandible_double_click_chance := 0.18

@export_category("Antennae")
@export_range(0.0, 40.0, 0.1, "degrees") var antenna_rotation := 8.0
@export_range(0.01, 5.0, 0.01, "suffix:s") var antenna_cycle_duration := 1.2
@export_range(0.0, 1.0, 0.01) var antenna_independence := 0.35
@export_range(0.0, 1.0, 0.01) var antenna_rotation_randomness := 0.35
@export_range(0.0, 1.0, 0.01) var antenna_duration_randomness := 0.3
@export_range(0.0, 1.0, 0.01, "suffix:s") var antenna_pause_max := 0.15

@export_category("Legs")
@export var walking := false:
	set(value):
		walking = value
		if _is_ready and not value and _base_rotations.size() > 0:
			_reset_leg_rotations()
@export_range(0.1, 5.0, 0.01, "suffix:s") var walk_cycle_duration := 0.5
## X = forward swing (degrees), Y = backward swing (degrees)
@export var front_leg_angle_range := Vector2(18.0, 22.0)
@export var middle_leg_angle_range := Vector2(18.0, 22.0)
@export var back_leg_angle_range := Vector2(18.0, 22.0)
@export_range(0.1, 0.9, 0.01) var leg_stance_fraction := 0.62

@export_category("Grid Behavior")
@export var grid_behavior_enabled := true
@export_range(1.0, 2000.0, 1.0, "suffix:px/s") var base_move_speed := 140.0
@export_range(0.0, 1.0, 0.01) var move_speed_jitter := 0.12
@export_range(0.0, 1.0, 0.01) var heading_randomness := 0.28
@export_range(0.1, 64.0, 0.1, "suffix:px") var arrive_distance := 6.0
@export var selected_for_player_control := false:
	set(value):
		selected_for_player_control = value
		if not selected_for_player_control:
			player_target_active = false
@export var player_target_active := false
@export var player_target_position := Vector2.ZERO

@export_category("Idle Wander")
@export var idle_wander_enabled := false:
	set(value):
		idle_wander_enabled = value
		if _is_ready:
			_start_idle_wander()
			_refresh_process_enabled()
@export_range(1.0, 2000.0, 1.0, "suffix:px/s") var idle_move_speed := 120.0
@export_range(0.0, 1.0, 0.01) var idle_move_speed_jitter := 0.2
@export_range(0.0, 512.0, 1.0, "suffix:px") var idle_screen_margin := 80.0
@export_range(0.1, 64.0, 0.1, "suffix:px") var idle_arrive_distance := 8.0
@export_range(0.0, 10.0, 0.01, "suffix:s") var idle_pause_min := 0.2
@export_range(0.0, 10.0, 0.01, "suffix:s") var idle_pause_max := 1.4

var _rng := RandomNumberGenerator.new()
var rendered_components: Array[Polygon2D]
var _base_rotations: Dictionary[int, float] = {}
var _animation_running := false
var _animation_generation := 0
var _is_ready := false
var _antenna_states: Array[Dictionary] = []
var _animation_time := 0.0
var _mandible_state := 0
var _mandible_timer := 0.0
var _mandible_elapsed := 0.0
var _mandible_duration := 0.0
var _mandible_start_degrees := 0.0
var _mandible_target_degrees := 0.0
var _mandible_current_degrees := 0.0
var _mandible_clicks_remaining := 0
var _leg_phase := 0.0
var _legs_data: Array[Dictionary] = []
var _world_level: WorldLevel
var _world: World
var _home_hill: AntHill
var _grid_cell := Vector2i.ZERO
var _target_grid_cell := Vector2i.ZERO
var _target_position := Vector2.ZERO
var _move_speed := 0.0
var _sim_ant: SimAnt
var _behavior_ready := false
var _carried_food: Food = null
var _idle_wander_ready := false
var _idle_target_position := Vector2.ZERO
var _idle_current_speed := 0.0
var _idle_pause_timer := 0.0

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	_rng.randomize()
	
	for child in find_children("*", "Polygon2D", true, false):
		var polygon := child as Polygon2D
		rendered_components.append(polygon)
		_base_rotations[polygon.get_instance_id()] = polygon.rotation
			
	_setup_rendering_rects()
	_is_ready = true
	
	if animate_on_ready and (not Engine.is_editor_hint() or animate_in_editor):
		start_animations()
	
	_move_speed = base_move_speed * _random_factor(move_speed_jitter)
	if _world_level != null:
		_start_grid_behavior()
	elif idle_wander_enabled:
		_start_idle_wander()


func _notification(what: int) -> void:
	if not Engine.is_editor_hint():
		return
	
	match what:
		NOTIFICATION_EDITOR_PRE_SAVE:
			stop_animations()
		NOTIFICATION_EDITOR_POST_SAVE:
			if animate_on_ready and animate_in_editor:
				start_animations.call_deferred()


func _setup_rendering_rects() -> void:
	var bounding_box = (bbox.shape as RectangleShape2D).get_rect()
	
	for polygon in rendered_components:
		# Convert rect into local space of polygon
		var bbox_to_polygon = polygon.get_global_transform().affine_inverse() * bbox.get_global_transform()
		var corners = [
			bounding_box.position,
			bounding_box.position + Vector2(bounding_box.size.x, 0.0),
			bounding_box.position + bounding_box.size,
			bounding_box.position + Vector2(0.0, bounding_box.size.y),
		]
		var rect = Rect2(bbox_to_polygon * corners[0], Vector2.ZERO)
		
		for corner in corners:
			rect = rect.expand(bbox_to_polygon * corner)
		
		RenderingServer.canvas_item_set_custom_rect(polygon.get_canvas_item(), true, rect)


func start_animations() -> void:
	stop_animations()
	_animation_running = true
	_animation_generation += 1
	_animation_time = 0.0
	_setup_antenna_animation_state()
	_setup_mandible_animation_state()
	_setup_leg_animation_state()
	_refresh_process_enabled()


func stop_animations() -> void:
	_animation_running = false
	_animation_generation += 1
	_antenna_states.clear()
	_legs_data.clear()
	_refresh_process_enabled()
	_reset_component_rotations()


func setup_grid_behavior(world_level: WorldLevel, home_hill: AntHill) -> void:
	_world_level = world_level
	_home_hill = home_hill
	if _is_ready:
		_start_grid_behavior()


func set_player_target(target_position: Vector2) -> void:
	selected_for_player_control = true
	player_target_active = true
	player_target_position = target_position


func clear_player_target() -> void:
	player_target_active = false


func _start_grid_behavior() -> void:
	if Engine.is_editor_hint() or not grid_behavior_enabled or _world_level == null:
		return

	_world = _world_level.get("world") as World
	if _world == null:
		return

	if _move_speed <= 0.0:
		_move_speed = base_move_speed * _random_factor(move_speed_jitter)

	_grid_cell = _world_level.world_position_to_cell(global_position)
	_sim_ant = SimAnt.new()
	_sim_ant.pos = _grid_cell
	_sim_ant.heading = Vector2.from_angle(_rng.randf_range(0.0, TAU))
	_behavior_ready = true
	walking = true
	_choose_next_target()
	_refresh_process_enabled()


func _start_idle_wander() -> void:
	if Engine.is_editor_hint() or not idle_wander_enabled or _world_level != null:
		_idle_wander_ready = false
		return

	_idle_wander_ready = true
	walking = true
	_idle_current_speed = idle_move_speed * _random_factor(idle_move_speed_jitter)
	_choose_next_idle_target()
	_refresh_process_enabled()


func _refresh_process_enabled() -> void:
	set_process(_animation_running or _behavior_ready or _idle_wander_ready)


func _reset_component_rotations() -> void:
	for component in rendered_components:
		component.rotation = _base_rotations[component.get_instance_id()]



func _setup_antenna_animation_state() -> void:
	_antenna_states = [
		_create_antenna_state(antenna_left, 1.0, 0.0),
		_create_antenna_state(antenna_right, -1.0, antenna_independence * 0.5),
	]


func _create_antenna_state(antenna: Polygon2D, direction: float, phase: float) -> Dictionary:
	return {
		"node": antenna,
		"direction": direction,
		"phase": (phase + _rng.randf_range(0.0, antenna_independence)) * TAU,
		"speed": _random_factor(antenna_duration_randomness),
		"speed_target": _random_factor(antenna_duration_randomness),
		"amplitude": _random_factor(antenna_rotation_randomness),
		"amplitude_target": _random_factor(antenna_rotation_randomness),
		"drift_timer": _rng.randf_range(0.0, max(antenna_cycle_duration, 0.01)),
	}


func _setup_mandible_animation_state() -> void:
	_mandible_state = 0
	_mandible_timer = _rng.randf_range(mandible_min_wait, max(mandible_min_wait, mandible_max_wait))
	_mandible_elapsed = 0.0
	_mandible_duration = 0.0
	_mandible_current_degrees = mandible_open_rotation
	_mandible_start_degrees = mandible_open_rotation
	_mandible_target_degrees = mandible_open_rotation
	_mandible_clicks_remaining = 0
	_set_mandible_rotation(_mandible_current_degrees)


func _random_factor(amount: float) -> float:
	return max(0.0, 1.0 + _rng.randf_range(-amount, amount))


func _update_antenna_animations(delta: float) -> void:
	for state in _antenna_states:
		var drift_timer: float = state["drift_timer"] - delta
		
		if drift_timer <= 0.0:
			state["speed_target"] = _random_factor(antenna_duration_randomness)
			state["amplitude_target"] = _random_factor(antenna_rotation_randomness)
			drift_timer = max(antenna_cycle_duration * _random_factor(antenna_duration_randomness) + _rng.randf_range(0.0, antenna_pause_max), 0.01)
		
		state["drift_timer"] = drift_timer
		state["speed"] = lerpf(state["speed"], state["speed_target"], _smooth_delta(delta, antenna_cycle_duration))
		state["amplitude"] = lerpf(state["amplitude"], state["amplitude_target"], _smooth_delta(delta, antenna_cycle_duration))
		state["phase"] = state["phase"] + (delta * TAU * state["speed"] / max(antenna_cycle_duration, 0.01))
		
		var antenna: Polygon2D = state["node"]
		var base_rotation: float = _base_rotations[antenna.get_instance_id()]
		var wave = sin(state["phase"]) + sin(state["phase"] * 2.17) * 0.18 * antenna_independence
		var offset = deg_to_rad(antenna_rotation * state["amplitude"]) * state["direction"] * wave
		
		antenna.rotation = base_rotation + offset


func _update_mandible_animation(delta: float) -> void:
	match _mandible_state:
		0:
			_mandible_timer -= delta
			
			if _mandible_timer <= 0.0:
				if _mandible_clicks_remaining <= 0:
					_mandible_clicks_remaining = 2 if _rng.randf() < mandible_double_click_chance else 1
				
				_begin_mandible_phase(1)
		1, 3:
			_mandible_elapsed += delta
			var progress = clampf(_mandible_elapsed / max(_mandible_duration, 0.01), 0.0, 1.0)
			var eased_progress = _ease_in_out(progress)
			_mandible_current_degrees = lerpf(_mandible_start_degrees, _mandible_target_degrees, eased_progress)
			
			if progress >= 1.0:
				if _mandible_state == 1:
					_mandible_state = 2
					_mandible_timer = _rng.randf_range(0.0, mandible_closed_hold_max)
				else:
					_mandible_clicks_remaining -= 1
					
					if _mandible_clicks_remaining > 0:
						_mandible_timer = _rng.randf_range(0.03, 0.12)
						_mandible_state = 0
					else:
						_mandible_timer = _rng.randf_range(mandible_min_wait, max(mandible_min_wait, mandible_max_wait))
						_mandible_state = 0
		2:
			_mandible_timer -= delta
			
			if _mandible_timer <= 0.0:
				_begin_mandible_phase(3)
	
	_set_mandible_rotation(_mandible_current_degrees)


func _begin_mandible_phase(state: int) -> void:
	_mandible_state = state
	_mandible_elapsed = 0.0
	_mandible_start_degrees = _mandible_current_degrees
	
	if state == 1:
		_mandible_target_degrees = mandible_close_rotation * _random_factor(mandible_rotation_randomness)
		_mandible_duration = mandible_close_duration * _random_factor(mandible_duration_randomness)
	else:
		_mandible_target_degrees = mandible_open_rotation * _random_factor(mandible_rotation_randomness)
		_mandible_duration = mandible_open_duration * _random_factor(mandible_duration_randomness)
	
	_mandible_duration = max(_mandible_duration, 0.01)


func _smooth_delta(delta: float, duration: float) -> float:
	return clampf(delta / max(duration, 0.01) * 3.0, 0.0, 1.0)


func _ease_in_out(value: float) -> float:
	return value * value * (3.0 - 2.0 * value)


func _set_mandible_rotation(degrees: float) -> void:
	var offset = deg_to_rad(degrees)
	
	mandible_left.rotation = _base_rotations[mandible_left.get_instance_id()] + offset
	mandible_right.rotation = _base_rotations[mandible_right.get_instance_id()] - offset


func _setup_leg_animation_state() -> void:
	_leg_phase = _rng.randf()
	# Tripod gait: group A (phase 0.0) and group B (phase 0.5) alternate.
	# direction: -1.0 for left-side legs, +1.0 for right-side legs.
	_legs_data = [
		{"node": top_leg_left,     "phase_offset": 0.0, "direction": -1.0, "angle_range": front_leg_angle_range},
		{"node": middle_leg_right, "phase_offset": 0.0, "direction":  1.0, "angle_range": middle_leg_angle_range},
		{"node": bottom_leg_left,  "phase_offset": 0.0, "direction": -1.0, "angle_range": back_leg_angle_range},
		{"node": top_leg_right,    "phase_offset": 0.5, "direction":  1.0, "angle_range": front_leg_angle_range},
		{"node": middle_leg_left,  "phase_offset": 0.5, "direction": -1.0, "angle_range": middle_leg_angle_range},
		{"node": bottom_leg_right, "phase_offset": 0.5, "direction":  1.0, "angle_range": back_leg_angle_range},
	]


func _reset_leg_rotations() -> void:
	for leg_data in _legs_data:
		var leg: Polygon2D = leg_data["node"]
		if _base_rotations.has(leg.get_instance_id()):
			leg.rotation = _base_rotations[leg.get_instance_id()]


func _get_leg_rotation_offset(phase: float, angle_range: Vector2) -> float:
	# Returns radians: positive = forward swing, negative = backward stance.
	# Stance phase (foot on ground) is longer; swing phase is faster and eased.
	var fwd := deg_to_rad(angle_range.x)
	var bck := deg_to_rad(angle_range.y)
	if phase < leg_stance_fraction:
		return lerpf(fwd, -bck, phase / leg_stance_fraction)
	else:
		var t := (phase - leg_stance_fraction) / (1.0 - leg_stance_fraction)
		return lerpf(-bck, fwd, _ease_in_out(t))


func _update_leg_animations(delta: float) -> void:
	_leg_phase = fmod(_leg_phase + delta / max(walk_cycle_duration, 0.01), 1.0)

	for leg_data in _legs_data:
		var leg: Polygon2D = leg_data["node"]
		var phase := fmod(_leg_phase + leg_data["phase_offset"], 1.0)
		var offset : float = _get_leg_rotation_offset(phase, leg_data["angle_range"]) * leg_data["direction"]
		leg.rotation = _base_rotations[leg.get_instance_id()] + offset


func _update_grid_behavior(delta: float) -> void:
	if not _behavior_ready or _world == null or _world_level == null:
		return

	var to_target := _target_position - global_position
	var distance_to_target := to_target.length()
	if distance_to_target <= arrive_distance:
		global_position = _target_position
		_on_target_reached()
		return

	var direction := to_target / distance_to_target
	var move_distance := _move_speed * delta
	if move_distance >= distance_to_target:
		global_position = _target_position
		rotation = direction.angle() + PI * 0.5
		_on_target_reached()
		return

	global_position += direction * move_distance
	rotation = direction.angle() + PI * 0.5


func _update_idle_wander(delta: float) -> void:
	if not _idle_wander_ready:
		return

	if _idle_pause_timer > 0.0:
		_idle_pause_timer -= delta
		if _idle_pause_timer > 0.0:
			return

	var to_target := _idle_target_position - global_position
	var distance_to_target := to_target.length()
	if distance_to_target <= idle_arrive_distance:
		global_position = _idle_target_position
		_begin_idle_pause()
		return

	var direction := to_target / distance_to_target
	var move_distance := _idle_current_speed * delta
	if move_distance >= distance_to_target:
		global_position = _idle_target_position
		rotation = direction.angle() + PI * 0.5
		_begin_idle_pause()
		return

	global_position += direction * move_distance
	rotation = direction.angle() + PI * 0.5


func _begin_idle_pause() -> void:
	_idle_pause_timer = _rng.randf_range(
		minf(idle_pause_min, idle_pause_max),
		maxf(idle_pause_min, idle_pause_max)
	)
	_idle_current_speed = idle_move_speed * _random_factor(idle_move_speed_jitter)
	_choose_next_idle_target()


func _choose_next_idle_target() -> void:
	_idle_target_position = _random_point_in_viewport()


func _random_point_in_viewport() -> Vector2:
	var rect := get_viewport_rect()
	var max_margin := minf(idle_screen_margin, minf(rect.size.x, rect.size.y) * 0.45)
	var min_position := rect.position + Vector2(max_margin, max_margin)
	var max_position := rect.end - Vector2(max_margin, max_margin)

	if min_position.x > max_position.x:
		min_position.x = rect.get_center().x
		max_position.x = rect.get_center().x
	if min_position.y > max_position.y:
		min_position.y = rect.get_center().y
		max_position.y = rect.get_center().y

	return Vector2(
		_rng.randf_range(min_position.x, max_position.x),
		_rng.randf_range(min_position.y, max_position.y)
	)


func _on_target_reached() -> void:
	if _sim_ant == null:
		return

	_sim_ant.pos = _world_level.world_position_to_cell(global_position)
	var event := _sim_ant.step(_world, _get_player_control_direction())
	_grid_cell = _sim_ant.pos

	if event == SimAnt.Event.FoundFood:

		var currently_carried_food := _sim_ant.carried_food_res(_world)
		if currently_carried_food != null and _carried_food == null:
			_collect_resource(currently_carried_food)
			if _carried_food != null:
				print_verbose("Ant %s collected food resource %s" % [self.get_instance_id(), _carried_food.name])
		else:
			print_verbose("Ant %s found food but failed to collect it" % self.get_instance_id())
	
	elif event == SimAnt.Event.FoundNest and _carried_food != null:
		print_verbose("Ant %s deposited food resource %s at nest" % [self.get_instance_id(), _carried_food.name])
		_deposit_food()
	
	_choose_next_target()


func _collect_resource(resource: FoodResource) -> void:
	if resource == null or _carried_food != null or not is_instance_valid(resource):
		return
	
	var collected_food := resource.remove_resource(1)
	if collected_food == null:
		return

	_carried_food = collected_food
	carried_food_particle.texture = collected_food.particle_texture
	carried_food_particle.offset_transform_rotation = deg_to_rad(_rng.randf_range(0.0, 360.0))
	carried_food_particle.visible = true



func _deposit_food() -> void:
	if _home_hill == null or _world == null:
		return

	if _carried_food == null:
		return

	_home_hill.add_resource(_carried_food)
	_carried_food = null
	carried_food_particle.visible = false
	carried_food_particle.texture = null


func _choose_next_target() -> void:
	_target_grid_cell = _choose_next_grid_cell()
	_target_position = _world_level.random_point_in_cell(_target_grid_cell)


func _choose_next_grid_cell() -> Vector2i:
	if _world == null or _sim_ant == null:
		return _grid_cell

	return _world_level.clamp_cell(_sim_ant.pos)


func _get_player_control_direction() -> Vector2:
	if not selected_for_player_control or not player_target_active:
		return Vector2.ZERO

	var direction := player_target_position - global_position
	if direction.length_squared() <= arrive_distance * arrive_distance:
		return Vector2.ZERO

	return direction.normalized()



# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if _behavior_ready:
		_update_grid_behavior(delta)
	elif _idle_wander_ready:
		_update_idle_wander(delta)
	
	if not _animation_running:
		return
	
	_animation_time += delta
	_update_antenna_animations(delta)
	_update_mandible_animation(delta)
	if walking:
		_update_leg_animations(delta)
