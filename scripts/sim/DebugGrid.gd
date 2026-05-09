extends Node2D

@export
var world: World

var ants: Array[SimAnt]

func _ready():
	world.init()
	
	var ant = SimAnt.new()
	ant.pos = Vector2i(55, 35)
	ant.heading = Vector2(1, 0)
	ant.phero = World.Pheromone.Food
	ants.push_back(ant)

func _draw():
	if world.int_data.size() == 0: return
	world.time = Time.get_ticks_msec()

	for x in range(world.size.x):
		for y in range(world.size.y):
			var color = Color(
				world.phero_at(x, y, World.Pheromone.Food) / float(World.PHERO_MAX),
				0,
				world.phero_at(x, y, World.Pheromone.Home) / float(World.PHERO_MAX),
			)
			draw_rect(Rect2(10*x, 10*y, 10, 10), color)

func _process(_delta: float):
	if Time.get_ticks_msec() / 5000 > ants.size():
		var ant = SimAnt.new()
		ant.pos = Vector2i(55, 35)
		ant.phero = World.Pheromone.Food
		ants.push_back(ant)
	for i in range(ants.size()):
		ants[i].step(world, i == 0)
	queue_redraw()
