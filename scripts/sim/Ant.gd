class_name Ant extends Resource

var heading: Vector2
var pos: Vector2i

var phero: World.Pheromone

func step(world: World, is_controlled: bool):
	# Update pheromones.
	world.put_phero(pos.x, pos.y, phero, 10*World.PHERO_MAX if is_controlled else 0)

	# Move.
	if not is_controlled:
		heading = (5 * heading + world.phero_gradient(pos, phero)).normalized()

	if heading == Vector2(0, 0): heading = Vector2.from_angle(randf_range(0, TAU))
	else: heading = heading.rotated(randfn(0, PI/8))

	const THRESH = sin(TAU/16)
	if   heading.x >  THRESH: pos.x = min(pos.x + 1, world.size.x - 1)
	elif heading.x < -THRESH: pos.x = max(pos.x - 1, 0)

	if   heading.y >  THRESH: pos.y = min(pos.y + 1, world.size.y - 1)
	elif heading.y < -THRESH: pos.y = max(pos.y - 1, 0)
