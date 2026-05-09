class_name SimAnt extends Resource

var heading: Vector2
var pos: Vector2i

var goal := World.Pheromone.Food
var food_id := World.NO_FOOD
var start_t: int

const PHERO_MAX := World.PHERO_MAX
const PHERO_MIN := PHERO_MAX / 2

func _init():
	start_t = Time.get_ticks_msec()

func step(world: World, steering: Vector2):
	# Move.
	if steering == Vector2.ZERO:
		heading = (heading + world.phero_dir(pos, goal)).normalized()
	else: heading = steering

	if heading == Vector2(0, 0): heading = Vector2.from_angle(randf_range(0, TAU))
	else: heading = heading.rotated(randfn(0, PI/32))

	const THRESH = sin(TAU/16)
	if   heading.x >  THRESH: pos.x = min(pos.x + 1, world.size.x - 1)
	elif heading.x < -THRESH: pos.x = max(pos.x - 1, 0)

	if   heading.y >  THRESH: pos.y = min(pos.y + 1, world.size.y - 1)
	elif heading.y < -THRESH: pos.y = max(pos.y - 1, 0)

	# Update state.
	var phero_stren = PHERO_MAX - 2*(Time.get_ticks_msec() - start_t)

	if pos == world.nest: # Returned to nest
		food_id = World.NO_FOOD
		goal = World.Pheromone.Food
		heading = Vector2.ZERO
		start_t = Time.get_ticks_msec()
		phero_stren = PHERO_MAX

	if food_id == World.NO_FOOD:
		var food = world.food_at(pos.x, pos.y)
		if food != World.NO_FOOD: # Found food
			food_id = food
			world.put_food(pos.x, pos.y, World.NO_FOOD)
			goal = World.Pheromone.Home
			heading = -heading
			start_t = Time.get_ticks_msec()
			phero_stren = PHERO_MAX
		elif goal == World.Pheromone.Food and phero_stren < PHERO_MIN: # Give up
			goal = World.Pheromone.Home
			heading = -heading

	if steering != Vector2.ZERO: phero_stren *= 5 # Boost controlled ant.
	# Update pheromones.
	if phero_stren > PHERO_MIN:
		world.put_phero(pos.x, pos.y, 1 - goal, phero_stren)
