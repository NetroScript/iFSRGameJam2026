class_name FoodResource
extends Node2D

## This food resource is depleted
signal depleted
## A chunk of resources was added.
signal resource_added(available_chunks: int)
## A chunk of resources was removed.
signal resource_removed(available_chunks: int)


@export_group("Resources")
## The food contained in this food resource
@export var food: Food = null
## Maximum number of chunks this food resource can contain.
## Equals to number of bites the ants can maximally take.
@export var max_chunks: int = 100
@export_group("")

@onready var sprite_2d: Sprite2D = %Sprite2D

@onready var available_chunks: int = max_chunks
var original_scale: Vector2

var world_level: WorldLevel = null
var _world_item_id: int = World.ITEM_NONE
var _covered_cells: Array[Vector2i] = []
var _registered_in_world := false

func _ready() -> void:
	if not is_instance_valid(food):
		return
	sprite_2d.texture = food.world_texture
	original_scale = sprite_2d.scale

	call_deferred("_register_food_in_world_grid")


func _exit_tree() -> void:
	_clear_food_from_world_grid()

func add_resource(amount: int) -> void:
	available_chunks += amount
	available_chunks = clamp(available_chunks, 0, max_chunks)
	resource_added.emit(available_chunks)
	_adapt_sprite_scale()


func remove_resource(amount: int) -> Food:
	if available_chunks == 0:
		queue_free()
		return null
	if not is_instance_valid(food):
		push_error("[%s] Invalid food reference while trying to remove resource." % get_path())
		return
	var chunks_taken = min(available_chunks, amount)
	available_chunks -= chunks_taken
	Gamestate.resources_collected(floori(food.calories * chunks_taken))
	available_chunks = clamp(available_chunks, 0, max_chunks)
	resource_removed.emit(available_chunks)
	_adapt_sprite_scale()

	if available_chunks == 0:
		_clear_food_from_world_grid()
		depleted.emit()
		queue_free()
		push_warning("Removing food resource")
	return food


func _adapt_sprite_scale() -> void:
	if max_chunks == 0:
		return
	var ratio := float(available_chunks) / float(max_chunks)
	ratio = clamp(ratio, 0.0, 1.0)
	sprite_2d.scale = original_scale * ratio
	_refresh_food_world_grid_cells()


func assign_food(new_food: Food, new_max_chunks: int, new_scale: float) -> void:
	if new_food == null:
		push_error("[%s] Assigned food is invalid." % get_path())
		return
	food = new_food
	max_chunks = new_max_chunks
	scale = Vector2(new_scale, new_scale)


func _register_food_in_world_grid() -> void:
	if _registered_in_world:
		return
	if not _can_use_world_grid():
		return

	world_level.world.food_items.push_back(self)
	_world_item_id = world_level.world.food_items.size() - 1
	_registered_in_world = true
	_refresh_food_world_grid_cells()


func _refresh_food_world_grid_cells() -> void:
	if not _registered_in_world or not _can_use_world_grid():
		return

	var new_cells := _grid_cells_covered_by_sprite()
	_clear_cells_not_covered(new_cells)
	_write_food_cells(new_cells)
	_covered_cells = new_cells


func _clear_food_from_world_grid() -> void:
	if not _registered_in_world or not _can_use_world_grid():
		return

	for cell in _covered_cells:
		_clear_cell_if_owned(cell)
	_covered_cells.clear()
	_registered_in_world = false


func _clear_cells_not_covered(new_cells: Array[Vector2i]) -> void:
	for cell in _covered_cells:
		if not new_cells.has(cell):
			_clear_cell_if_owned(cell)


func _write_food_cells(cells: Array[Vector2i]) -> void:
	for cell in cells:
		world_level.world.set_int(cell.x, cell.y, World.IntField.Item, _world_item_id)


func _clear_cell_if_owned(cell: Vector2i) -> void:
	if world_level.world.get_int(cell.x, cell.y, World.IntField.Item) == _world_item_id:
		world_level.world.set_int(cell.x, cell.y, World.IntField.Item, World.ITEM_NONE)


func _grid_cells_covered_by_sprite() -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	if not _can_use_world_grid():
		return cells

	var rect := _sprite_global_rect()
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
	var sprite_rect := sprite_2d.get_rect()
	var corners := [
		sprite_rect.position,
		sprite_rect.position + Vector2(sprite_rect.size.x, 0.0),
		sprite_rect.position + sprite_rect.size,
		sprite_rect.position + Vector2(0.0, sprite_rect.size.y),
	]
	var global_rect := Rect2(sprite_2d.to_global(corners[0]), Vector2.ZERO)

	for corner in corners:
		global_rect = global_rect.expand(sprite_2d.to_global(corner))

	return global_rect


func _can_use_world_grid() -> bool:
	return is_instance_valid(world_level) and world_level.world != null
