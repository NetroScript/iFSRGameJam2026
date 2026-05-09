extends Node2D

@export
var world: World

var ants: Array[SimAnt]

const NEST_POS := Vector2(400, 300)

func _ready():
	world.init()

	var food = Food.new()
	food.size = Vector2(50, 200)
	#world.add_food(food, NEST_POS, 

	ants.resize(20)
	for i in range(ants.size()):
		var ant := SimAnt.new()
		ant.pos = world.nest
		ant.heading = Vector2.ZERO
		ant.goal = World.Pheromone.Food
		ants[i] = ant

func _draw():
	if world.int_data.size() == 0: return
	world.time = Time.get_ticks_msec()

	for x in range(world.size.x):
		for y in range(world.size.y):
			var color = Color(
				world.phero_at(x, y, World.Pheromone.Food) / float(World.PHERO_MAX),
				0 if world.food_at(x, y) == World.ITEM_NONE else 1,
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
	world.put_phero(world.nest.x, world.nest.y, World.Pheromone.Home, World.PHERO_MAX)

	for i in range(ants.size()):
		ants[i].step(world, Vector2.ZERO)

	if redraw < 5:
		redraw += 1
		return
	redraw = 0
	queue_redraw()
