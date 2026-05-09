class_name FoodSpawner
extends Node2D


@export var spawn_entries: Array[FoodSpawnSettings] = []
@export var world_level: WorldLevel = null
@export var food_resource: PackedScene = preload("uid://cvor5dmn2lje5")

# Maximum world grid coordinates (i.e. lower right corner of it)
var world_max_coords: Vector2i = Vector2i.ZERO


func _ready() -> void:
	if world_level == null:
		push_error("[%s]: Food spawner has invalid reference to WorldLevel" % get_path())
		return
	if food_resource == null:
		push_error("[%s]: Food spawner has invalid reference to FoodResource scene" % get_path())
		return
	world_max_coords = world_level.grid_size * world_level.cell_size
	randomize()
	spawn_all_resources()


## Spawns all resources based on their settings
func spawn_all_resources():
	if not is_instance_valid(world_level):
		return
	if food_resource == null:
		return
	for spawn_entry in spawn_entries:
		_spawn_resource(spawn_entry)


func _spawn_resource(spawn_settings: FoodSpawnSettings) -> void:
	if spawn_settings == null:
		return

	for i in spawn_settings.amount:
		# Calculate spawn position
		var min_range := float(world_max_coords.x) / 2.0 * spawn_settings.food.min_range
		var max_range := float(world_max_coords.x) / 2.0 * spawn_settings.food.max_range
		var spawn_position := _get_random_position_in_ring(Vector2.ZERO, min_range, max_range)
		# Calculate how many chunks of food it contains
		var max_chunks = randi_range(spawn_settings.food.chunks_range.x, spawn_settings.food.chunks_range.y)
		# Calculate scaling of food resource's world texture according to max chunks calculated above
		var scale_value = remap(
			max_chunks,
			spawn_settings.food.chunks_range.x, spawn_settings.food.chunks_range.y,
			spawn_settings.food.world_texture_scale_with_chunk_size.x, spawn_settings.food.world_texture_scale_with_chunk_size.y
		)
		# Instantiate new food resource and set values
		var new_food_resource := food_resource.instantiate() as FoodResource
		if new_food_resource == null:
			push_error("[%s] Instantiated food resource is not of expected type FoodResource." % get_path())
			return
		new_food_resource.world_level = world_level
		new_food_resource.assign_food(spawn_settings.food, max_chunks, scale_value)
		add_child(new_food_resource)
		new_food_resource.global_position = spawn_position



## Calculates a random position in a ring (in same coordinates as given parameters)
func _get_random_position_in_ring(center: Vector2, min_radius: float, max_radius: float) -> Vector2:
	var angle := randf() * TAU

	var min_radius_squared := min_radius * min_radius
	var max_radius_squared := max_radius * max_radius

	var distance := sqrt(randf_range(min_radius_squared, max_radius_squared))

	var direction := Vector2.RIGHT.rotated(angle)
	return center + direction * distance
