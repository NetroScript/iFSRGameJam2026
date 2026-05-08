class_name World extends Resource

@export
var size: Vector2i

const PHERO_MAX := 30_000 # 30 seconds

var time: int

func init():
	int_data.resize(size.x * size.y * IntField.Count)
	int_data.fill(-PHERO_MAX)

enum Pheromone {Home, Food}
func phero_gradient(pos: Vector2i, phero: Pheromone) -> Vector2:
	const SQRT2 := sqrt(2)

	time = Time.get_ticks_msec()

	var dir = Vector2(0, 0)
	if pos.x > 0:
		if pos.y > 0:          dir += Vector2(-SQRT2, -SQRT2) * phero_at(pos.x - 1, pos.y - 1, phero)
		if true:               dir += Vector2(    -1,      0) * phero_at(pos.x - 1, pos.y,     phero)
		if pos.y < size.y - 1: dir += Vector2(-SQRT2,  SQRT2) * phero_at(pos.x - 1, pos.y + 1, phero)

	if pos.y > 0:          dir += Vector2(0, -1) * phero_at(pos.x, pos.y - 1, phero)
	if pos.y < size.y - 1: dir += Vector2(0,  1) * phero_at(pos.x, pos.y + 1, phero)

	if pos.x < size.x - 1:
		if pos.y > 0:          dir += Vector2(SQRT2, -SQRT2) * phero_at(pos.x + 1, pos.y - 1, phero)
		if true:               dir += Vector2(    1,      0) * phero_at(pos.x + 1, pos.y,     phero)
		if pos.y < size.y - 1: dir += Vector2(SQRT2,  SQRT2) * phero_at(pos.x + 1, pos.y + 1, phero)

	return dir.normalized()

func phero_at(x: int, y: int, phero: Pheromone) -> int:
	return max(0, PHERO_MAX - (time - get_int(x, y, IntField.PheroBase + phero)))
func put_phero(x: int, y: int, phero: Pheromone, bonus: int):
	set_int(x, y, IntField.PheroBase + phero, Time.get_ticks_msec() + bonus)

func food_at(x: int, y: int) -> Food:
	return food[y * size.x + x]
func put_food(x: int, y: int, food: Food):
	self.food[y * size.x + x] = food

var int_data: PackedInt32Array
enum IntField {PheroHome, PheroFood, Count, PheroBase = PheroHome}

var food: Array[Food]

func get_int(x: int, y: int, field: IntField) -> int:
	return int_data[(y * size.x + x) * IntField.Count + field]
func set_int(x: int, y: int, field: IntField, val: int):
	int_data[(y * size.x + x) * IntField.Count + field] = val
