extends Node2D

@export
var world: World

var ants: Array[SimAnt]

func _ready():
	world.init()

	const NEST := Vector2i(50, 30)
	world.put_item(Rect2i(NEST, Vector2i(5, 5)), World.ITEM_NEST)

	world.put_item(Rect2i(10, 0, 5, 70), 0)
	world.put_item(Rect2i(90, 0, 5, 70), 0)

	ants.resize(20)
	for i in range(ants.size()):
		var ant := SimAnt.new()
		ant.pos = NEST + Vector2i(2, 2)
		ant.heading = Vector2.ZERO
		ant.goal = World.Pheromone.Food
		ants[i] = ant

func _draw():
	if world.int_data.size() == 0: return
	world.time = Time.get_ticks_msec()

	for y in range(world.size.y):
		for x in range(world.size.x):
			var color = Color(
				world.phero_at(x, y, World.Pheromone.Food) / float(World.PHERO_MAX),
				0 if world.get_int(x, y, World.IntField.Item) == World.ITEM_NONE else 1,
				world.phero_at(x, y, World.Pheromone.Home) / float(World.PHERO_MAX),
			)
			draw_rect(Rect2(10*x, 10*y, 10, 10), color)
	for ant in ants:
		draw_rect(
			Rect2(10*ant.pos.x, 10*ant.pos.y, 10, 10),
			Color(0.5, 0.5 ,0.5) if ant.food_id == World.ITEM_NONE else Color.WHITE
		)

var redraw: int = 0
func _process(_delta: float):
	for i in range(ants.size()):
		ants[i].step(world, Vector2.ZERO)

	if redraw < 5:
		redraw += 1
		return
	redraw = 0
	queue_redraw()
