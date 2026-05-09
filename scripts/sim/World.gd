class_name World extends Resource

@export var size: Vector2i
@export var nest: Vector2i

const PHERO_MAX := 30_000 # milliseconds until pheromone disappears
const NO_FOOD := 255

var time: int

func init():
	int_data.resize(size.x * size.y * IntField.Count)
	int_data.fill(-PHERO_MAX)

	food_id.resize(size.x * size.y)
	food_id.fill(NO_FOOD)

enum Pheromone {Home, Food}
func phero_dir(pos: Vector2i, phero: Pheromone) -> Vector2:
	const SQRT2 := sqrt(2)

	time = Time.get_ticks_msec()

	var dir := Vector2(0, 0)
	var max := 0.0
	var stren: int
	if pos.x > 0:
		if pos.y > 0:
			stren = phero_at(pos.x - 1, pos.y - 1, phero)
			dir += Vector2(-SQRT2, -SQRT2) * stren
			max = max(max, stren)
		stren = phero_at(pos.x - 1, pos.y, phero)
		dir += Vector2(-1, 0) * stren
		max = max(max, stren)
		if pos.y < size.y - 1:
			stren = phero_at(pos.x - 1, pos.y + 1, phero)
			dir += Vector2(-SQRT2, SQRT2) * stren
			max = max(max, stren)

	if pos.y > 0:
		stren = phero_at(pos.x, pos.y - 1, phero)
		dir += Vector2(0, -1) * stren
		max = max(max, stren)
	if pos.y < size.y - 1:
		stren = phero_at(pos.x, pos.y + 1, phero)
		dir += Vector2(0, 1) * stren
		max = max(max, stren)
		
	if pos.x < size.x - 1:
		if pos.y > 0:
			stren = phero_at(pos.x + 1, pos.y - 1, phero)
			dir += Vector2(SQRT2, -SQRT2) * stren
			max = max(max, stren)
			
		stren = phero_at(pos.x + 1, pos.y, phero)
		dir += Vector2(1, 0) * stren
		max = max(max, stren)
		
		if pos.y < size.y - 1:
			stren = phero_at(pos.x + 1, pos.y + 1, phero)
			dir += Vector2(SQRT2, SQRT2) * stren
			max = max(max, stren)

	var weight = float(max) / PHERO_MAX
	return dir.normalized()# * weight

func phero_at(x: int, y: int, phero: Pheromone) -> int:
	return max(0, PHERO_MAX - (time - get_int(x, y, IntField.PheroBase + phero)))
func put_phero(x: int, y: int, phero: Pheromone, strength: int):
	set_int(x, y, IntField.PheroBase + phero, Time.get_ticks_msec() - PHERO_MAX + strength)

func food_at(x: int, y: int) -> int:
	return food_id[y * size.x + x]
func put_food(x: int, y: int, id: int):
	food_id[y * size.x + x] = id

var int_data: PackedInt32Array
enum IntField {PheroHome, PheroFood, Count, PheroBase = PheroHome}

var food_instances: Array[Food]
var food_id: PackedByteArray

func get_int(x: int, y: int, field: IntField) -> int:
	return int_data[(y * size.x + x) * IntField.Count + field]
func set_int(x: int, y: int, field: IntField, val: int):
	int_data[(y * size.x + x) * IntField.Count + field] = val
