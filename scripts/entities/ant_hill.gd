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

@export var size: Vector2

@onready var resource_bar: ProgressBar = %ResourceBar
@onready var resource_timer: Timer = %ResourceTimer
# Current number of resources
@onready var resources: float = start_resources

var _rng := RandomNumberGenerator.new()
var _start_ants_spawned := false
var _spawn_retry_count := 0

func _ready() -> void:
	_rng.randomize()
	# Setup resource bar
	resource_bar.max_value = max_resources
	resource_bar.min_value = 0.0
	resource_bar.value = resources
	# Setup resource drain timer
	resource_timer.wait_time = tick_rate
	resource_timer.one_shot = false
	resource_timer.timeout.connect(_on_resource_timer_timeout)
	if drain_on_start:
		resource_timer.start()

	if not Engine.is_editor_hint():
		if world_level == null:
			world_level = _find_world_level()
		call_deferred("_spawn_start_ants")


func start_resource_draining() -> void:
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
	world.place_nest(Rect2(global_position, size), world_level)
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
