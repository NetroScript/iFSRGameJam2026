class_name World extends Resource

enum Pheromone {Home, Food}

@export var size: Vector2i

const PHERO_MAX := 30_000 # milliseconds until pheromone disappears

const ITEM_NEST := -2
const ITEM_NONE := -1

var time: int

var int_data: PackedInt32Array
enum IntField {PheroHome, PheroFood, Item, Count, PheroBase = PheroHome}

var food_items: Array[Food]

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

func add_food(res: FoodResource, level: WorldLevel):
	food_items.push_back(res.food)
	var aabb := res.sprite_2d.get_rect()
	put_item(
		Rect2i(
			level.world_position_to_cell(res.sprite_2d.to_global(aabb.position)),
			aabb.size * res.sprite_2d.scale / Vector2(level.cell_size)
		),
		food_items.size() - 1,
	)
func place_nest(area: Rect2, level: WorldLevel):
	put_item(
		Rect2i(area.position / Vector2(level.cell_size), area.size / Vector2(level.cell_size)),
		ITEM_NEST,
	)
func put_item(area: Rect2i, id: int):
	for y in range(area.position.y, area.end.y):
		for x in range(area.position.x, area.end.x):
			set_int(x, y, IntField.Item, id)

func get_int(x: int, y: int, field: IntField) -> int:
	return int_data[(y * size.x + x) * IntField.Count + field]
func set_int(x: int, y: int, field: IntField, val: int):
	int_data[(y * size.x + x) * IntField.Count + field] = val
