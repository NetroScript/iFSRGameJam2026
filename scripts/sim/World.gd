class_name World extends Resource

enum Pheromone {Home, Food}

@export var size: Vector2i

const PHERO_MAX := 30_000 # milliseconds until pheromone disappears

const ITEM_NEST := -2
const ITEM_NONE := -1

var time: int

var int_data: PackedInt32Array
enum IntField {PheroHome, PheroFood, Item, Count, PheroBase = PheroHome}

var food_items: Array[FoodResource]

func init():
	int_data.resize(size.x * size.y * IntField.Count)
	for i in range(0, size.x * size.y):
		var base = i * IntField.Count
		int_data[base + IntField.PheroHome] = -PHERO_MAX
		int_data[base + IntField.PheroFood] = -PHERO_MAX
		int_data[base + IntField.Item]      = ITEM_NONE

var max_dir: Vector2
var max_phero: int
func _check_cell(x: int, y: int, phero: Pheromone, dir: Vector2):
	var stren = phero_at(x, y, phero)
	if stren > max_phero:
		max_phero = stren
		max_dir = dir

func phero_dir(pos: Vector2i, phero: Pheromone) -> Vector2:
	const SQRT2 := sqrt(2)

	time = Time.get_ticks_msec()

	max_dir   = Vector2(0, 0)
	max_phero = 0
	if pos.x > 0:
		if pos.y > 0:          _check_cell(pos.x - 1, pos.y - 1, phero, Vector2(-SQRT2, -SQRT2))
		if true:               _check_cell(pos.x - 1, pos.y    , phero, Vector2(    -1,      0))
		if pos.y < size.y - 1: _check_cell(pos.x - 1, pos.y + 1, phero, Vector2(-SQRT2,  SQRT2))

	if pos.y > 0:          _check_cell(pos.x, pos.y - 1, phero, Vector2(0, -1))
	if pos.y < size.y - 1: _check_cell(pos.x, pos.y + 1, phero, Vector2(0,  1))

	if pos.x < size.x - 1:
		if pos.y > 0:          _check_cell(pos.x + 1, pos.y - 1, phero, Vector2(SQRT2, -SQRT2))
		if true:               _check_cell(pos.x + 1, pos.y    , phero, Vector2(    1,      0))
		if pos.y < size.y - 1: _check_cell(pos.x + 1, pos.y + 1, phero, Vector2(SQRT2,  SQRT2))

	var weight = float(max_phero) / PHERO_MAX
	return max_dir * weight

func phero_at(x: int, y: int, phero: Pheromone) -> int:
	return max(0, PHERO_MAX - (time - get_int(x, y, IntField.PheroBase + phero)))
func put_phero(x: int, y: int, phero: Pheromone, strength: int):
	var current = get_int(x, y, IntField.PheroBase + phero)
	var new = Time.get_ticks_msec() - PHERO_MAX + strength
	set_int(x, y, IntField.PheroBase + phero, max(current, new))

func _food_aabb_world(food: FoodResource, level: WorldLevel) -> Rect2:
	var aabb := food.sprite_2d.get_rect()
	return Rect2(
		food.sprite_2d.to_global(aabb.position),
		aabb.size * food.sprite_2d.scale / Vector2(level.cell_size)
	)
func add_food(food: FoodResource, level: WorldLevel):
	food_items.push_back(food)
	put_world_item(_food_aabb_world(food, level), level, food_items.size() - 1)
func clear_food(food: FoodResource, level: WorldLevel):
	put_world_item(_food_aabb_world(food, level), level, ITEM_NONE)
func put_world_item(aabb: Rect2, level: WorldLevel, item: int):
	var size = aabb.size / Vector2(level.cell_size)
	put_item(
		Rect2i(level.world_position_to_cell(aabb.position) - Vector2i(size/2), size),
		item,
	)
func put_item(aabb: Rect2i, id: int):
	print("Add item %s at %s}" % [id, aabb])
	for y in range(aabb.position.y, aabb.end.y):
		for x in range(aabb.position.x, aabb.end.x):
			set_int(x, y, IntField.Item, id)

func get_int(x: int, y: int, field: IntField) -> int:
	return int_data[(y * size.x + x) * IntField.Count + field]
func set_int(x: int, y: int, field: IntField, val: int):
	int_data[(y * size.x + x) * IntField.Count + field] = val
