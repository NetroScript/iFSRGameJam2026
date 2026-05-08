class_name FoodResource
extends Node2D

## This food resource is depleted
signal depleted
## A chunk of resources was added.
signal resource_added(available_chunks: int)
## A chunk of resources was removed.
signal resource_removed(available_chunks: int)


@export_group("Resources")
## The food contained in this food resource
@export var food: Food
## Maximum number of chunks this food resource can contain.
## Equals to number of bites the ants can maximally take.
@export var max_chunks: int = 100
@export_group("")

@onready var sprite_2d: Sprite2D = %Sprite2D

@onready var available_chunks: int = max_chunks
@onready var original_scale := sprite_2d.scale

func add_resource(amount: int) -> void:
	available_chunks += amount
	available_chunks = clamp(available_chunks, 0, max_chunks)
	resource_added.emit(available_chunks)
	_adapt_sprite_scale()


func remove_resource(amount: int) -> Food:
	if available_chunks == 0:
		queue_free()
		return null
	available_chunks -= amount
	available_chunks = clamp(available_chunks, 0, max_chunks)
	resource_removed.emit(available_chunks)
	_adapt_sprite_scale()

	if available_chunks == 0:
		depleted.emit()
		queue_free()
		push_warning("Removing food resource")
	return food


func _adapt_sprite_scale() -> void:
	if max_chunks == 0:
		return
	var ratio := float(available_chunks) / float(max_chunks)
	ratio = clamp(ratio, 0.0, 1.0)
	sprite_2d.scale = original_scale * ratio
