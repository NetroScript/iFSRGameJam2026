@tool
class_name AntHill
extends Node2D

## A resource was added. Returns new number of resources
signal resource_added(new_resources: float)
## A resource was removed. Returns new number of resources
signal resource_removed(new_resources: float)
## The resources are depleted. The ant queen is very unhappy with you!
signal depleted

@export_group("Resources")
## The number of resources the ant hill starts with
@export var start_resources: float = 100.0
## Maximum resource count that can be stored in this ant hill
@export var max_resources: float = 100.0
## How fast (in seconds) the resource draining should happen (tick).
@export var tick_rate: float = 1.0
## Resource drain rate per tick
@export var drain_rate: float = 1.0
## Should resource draining happen from object instantiation
@export var drain_on_start: bool = true
@export_group("")

@export_category("Ant Spawning")

@export var world_level: WorldLevel
@export var ant_scene: PackedScene = preload("res://objects/Ant.tscn")
## Between how many Ants should be spawned at the beginning of the game (min,max)
@export var spawn_range: Vector2i = Vector2i(5, 5000)
## The minimum distance and the maximum distance (in grid cells) in which the ants should be spawned from the ant hill
@export var spawn_distance_range: Vector2i = Vector2i(5, 100)
## Fraction of the visual hill bounds that should count as nest grid cells.
@export_range(0.1, 1.0, 0.01)
var nest_grid_coverage := 0.5:
	set(value):
		nest_grid_coverage = clampf(value, 0.1, 1.0)
		_redraw_world_level_debug()

@onready var resource_bar: ProgressBar = %ResourceBar
@onready var resource_timer: Timer = %ResourceTimer
# Current number of resources
@onready var resources: float = start_resources

var _rng := RandomNumberGenerator.new()
var _start_ants_spawned := false
var _spawn_retry_count := 0
var _nest_cells: Array[Vector2i] = []

func _ready() -> void:
	_rng.randomize()
	# Setup resource bar
	resource_bar.max_value = max_resources
	resource_bar.min_value = 0.0
	resource_bar.value = resources

	if Engine.is_editor_hint():
		if world_level == null:
			world_level = _find_world_level()
		_redraw_world_level_debug()
		return

	# Setup resource drain timer
	resource_timer.wait_time = tick_rate
	resource_timer.one_shot = false
	if not resource_timer.timeout.is_connected(_on_resource_timer_timeout):
		resource_timer.timeout.connect(_on_resource_timer_timeout)
	if drain_on_start:
		resource_timer.start()

	if world_level == null:
		world_level = _find_world_level()
	call_deferred("_spawn_start_ants")


func start_resource_draining() -> void:
	if Engine.is_editor_hint():
		return

	resource_timer.start()


func add_resource(food: Food) -> void:
	if food == null:
		return
	resources += food.calories
	resources = clamp(resources, 0.0, max_resources)
	resource_added.emit(resources)
	_update_resource_bar()


func remove_resource(amount: float) -> void:
	if resources <= 0.0:
		return
	resources -= amount
	Gamestate.resources_consumed(floori(amount))
	resources = clamp(resources, 0.0, max_resources)
	resource_removed.emit(resources)
	_update_resource_bar()

	if resources == 0.0:
		depleted.emit()
		Gamestate.end_run()
		push_warning("Resources depleted")


func _on_resource_timer_timeout() -> void:
	remove_resource(drain_rate)


func _update_resource_bar() -> void:
	if resource_bar != null:
		resource_bar.value = resources


func _spawn_start_ants() -> void:
	if _start_ants_spawned:
		return

	if ant_scene == null or world_level == null:
		_retry_spawn_start_ants()
		return

	var world := world_level.world
	if world == null:
		_retry_spawn_start_ants()
		return

	_start_ants_spawned = true
	_register_nest_cells()
	var spawn_count := _rng.randi_range(mini(spawn_range.x, spawn_range.y), maxi(spawn_range.x, spawn_range.y))
	for i in range(spawn_count):
		var ant := ant_scene.instantiate() as Ant
		if ant == null:
			continue

		var spawn_position := _random_spawn_position()
		get_parent().add_child(ant)
		ant.global_position = spawn_position
		ant.setup_grid_behavior(world_level, self)


func _random_spawn_position() -> Vector2:
	if world_level == null:
		return global_position

	var world_cell := world_level.call("world_position_to_cell", global_position) as Vector2i
	var min_distance := mini(spawn_distance_range.x, spawn_distance_range.y)
	var max_distance := maxi(spawn_distance_range.x, spawn_distance_range.y)
	var distance := _rng.randi_range(maxi(0, min_distance), maxi(0, max_distance))
	var direction := Vector2.from_angle(_rng.randf_range(0.0, TAU))
	var offset := Vector2i(roundi(direction.x * distance), roundi(direction.y * distance))
	var spawn_cell: Vector2i = world_cell + offset
	var world := world_level.world

	if world != null:
		spawn_cell.x = clampi(spawn_cell.x, 0, world.size.x - 1)
		spawn_cell.y = clampi(spawn_cell.y, 0, world.size.y - 1)

	return world_level.call("random_point_in_cell", spawn_cell)


func debug_highlight_ant_hill_cells(enabled := true) -> void:
	if world_level == null:
		world_level = _find_world_level()
	if world_level == null:
		return

	world_level.debug_highlight_ant_hill_cells(enabled)


func get_nest_cells() -> Array[Vector2i]:
	if Engine.is_editor_hint() or _nest_cells.is_empty():
		return _grid_cells_covered_by_sprite()

	return _nest_cells.duplicate()


func _register_nest_cells() -> void:
	if world_level == null or world_level.world == null:
		return

	_nest_cells = _grid_cells_covered_by_sprite()
	if _nest_cells.is_empty():
		_nest_cells.append(world_level.world_position_to_cell(global_position))

	for cell in _nest_cells:
		world_level.world.set_int(cell.x, cell.y, World.IntField.Item, World.ITEM_NEST)

	world_level.queue_redraw()


func _grid_cells_covered_by_sprite() -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	if world_level == null:
		return cells

	var rect := _sprite_global_rect()
	var inset := rect.size * (1.0 - nest_grid_coverage) * 0.5
	rect = rect.grow_individual(-inset.x, -inset.y, -inset.x, -inset.y)
	if rect.size.x <= 0.0 or rect.size.y <= 0.0:
		return cells

	var start_cell := world_level.world_position_to_cell(rect.position)
	var end_cell := world_level.world_position_to_cell(rect.end - Vector2(0.001, 0.001))
	var min_x := mini(start_cell.x, end_cell.x)
	var max_x := maxi(start_cell.x, end_cell.x)
	var min_y := mini(start_cell.y, end_cell.y)
	var max_y := maxi(start_cell.y, end_cell.y)

	for y in range(min_y, max_y + 1):
		for x in range(min_x, max_x + 1):
			cells.append(Vector2i(x, y))

	return cells


func _sprite_global_rect() -> Rect2:
	var sprite := %Sprite2D as Sprite2D
	var sprite_rect := sprite.get_rect()
	var corners := [
		sprite_rect.position,
		sprite_rect.position + Vector2(sprite_rect.size.x, 0.0),
		sprite_rect.position + sprite_rect.size,
		sprite_rect.position + Vector2(0.0, sprite_rect.size.y),
	]
	var global_rect := Rect2(sprite.to_global(corners[0]), Vector2.ZERO)

	for corner in corners:
		global_rect = global_rect.expand(sprite.to_global(corner))

	return global_rect


func _redraw_world_level_debug() -> void:
	if not is_inside_tree():
		return

	if world_level == null:
		world_level = _find_world_level()
	if world_level != null:
		world_level.queue_redraw()


func _retry_spawn_start_ants() -> void:
	if world_level == null:
		world_level = _find_world_level()

	_spawn_retry_count += 1
	if _spawn_retry_count > 120:
		push_warning("AntHill could not spawn start ants because no ready WorldLevel was found.")
		return

	call_deferred("_spawn_start_ants")


func _find_world_level() -> WorldLevel:
	var node := get_parent()
	while node != null:
		if node is WorldLevel:
			return node as WorldLevel
		node = node.get_parent()

	return null
