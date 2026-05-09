class_name SimAnt extends Resource

var heading: Vector2
var pos:     Vector2i

var goal        := World.Pheromone.Food
var leave_trail := true
var food_id     := World.ITEM_NONE
var start_t: int

const PHERO_MAX := World.PHERO_MAX
const PHERO_MIN := PHERO_MAX / 2

func _init():
	start_t = Time.get_ticks_msec()

enum Event {None, FoundFood, FoundNest}
func step(world: World, steering: Vector2) -> Event:
	# Move.
	if steering == Vector2.ZERO:
		heading = (heading + world.phero_dir(pos, goal)).normalized()
	else: heading = steering

	if heading == Vector2.ZERO: heading = Vector2.from_angle(randf_range(0, TAU))
	else: heading = heading.rotated(randfn(0, PI/32))

	const THRESH = sin(TAU/16)
	if   heading.x >  THRESH: pos.x = min(pos.x + 1, world.size.x - 1)
	elif heading.x < -THRESH: pos.x = max(pos.x - 1, 0)

	if   heading.y >  THRESH: pos.y = min(pos.y + 1, world.size.y - 1)
	elif heading.y < -THRESH: pos.y = max(pos.y - 1, 0)

	# Update state.
	var phero_stren = PHERO_MAX - 2*(Time.get_ticks_msec() - start_t)
	var item        = world.get_int(pos.x, pos.y, World.IntField.Item)
	var event       = Event.None
	
	if item == World.ITEM_NEST: # Returned to nest
		event       = Event.FoundNest
		food_id     = World.ITEM_NONE
		goal        = World.Pheromone.Food
		leave_trail = true
		heading     = Vector2.ZERO
		start_t     = Time.get_ticks_msec()
		phero_stren = PHERO_MAX
	elif food_id == World.ITEM_NONE:
		if item != World.ITEM_NONE: # Found food
			event = Event.FoundFood
			food_id = item
			world.set_int(pos.x, pos.y, World.IntField.Item, World.ITEM_NONE)
			goal        = World.Pheromone.Home
			leave_trail = true
			heading     = -heading
			start_t     = Time.get_ticks_msec()
			phero_stren = PHERO_MAX
		elif goal == World.Pheromone.Food and phero_stren < PHERO_MIN: # Give up
			goal        = World.Pheromone.Home
			leave_trail = false
			heading     = -heading

	if steering != Vector2.ZERO: phero_stren *= 5 # Boost controlled ant.
	# Update pheromones.
	if leave_trail:
		world.put_phero(pos.x, pos.y, 1 - goal, phero_stren)

	return event

func carried_food_res(world: World) -> FoodResource:
	if food_id == World.ITEM_NONE: return null
	return world.food_items[food_id]
