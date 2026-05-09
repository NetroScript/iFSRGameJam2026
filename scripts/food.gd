class_name Food
extends Resource

## World texture of the food
@export var world_texture: Texture2D
## Particle texture of the food (carried by ants)
@export var particle_texture: Texture2D
## Name of the food
@export var name: String
## Calories of one unit of the food. More = better
@export var calories: float
## Minimum distance from base this food resource should
## be spawned. Units are percent grid size.
@export_group("Spawn")
@export_range(0.0, 1.0) var min_range: float = 0.0
## Maximum distance from base this food resource should
## be spawned. Units are percent grid size.
@export_range(0.0, 1.0) var max_range: float = 1.0
## Random ranges of available chunks. X ... Minimum, Y ... Maximum
@export var chunks_range: Vector2i = Vector2i(10, 50)
## Scaling of world texture with randomized max chunk size
@export var world_texture_scale_with_chunk_size: Vector2 = Vector2(0.2, 1.5)
