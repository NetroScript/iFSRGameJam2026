class_name AntHill
extends Node2D

## A resource was added. Returns new number of resources
signal resource_added(new_resources: float)
## A resource was removed. Returns new number of resources
signal resource_removed(new_resources: float)
## The resources are depleted. The ant queen is very unhappy with you!
signal depleted

@export_group("Resources")
## The number of resources the ant hill starts with
@export var start_resources: float = 100.0
## Maximum resource count that can be stored in this ant hill
@export var max_resources: float = 100.0
## How fast (in seconds) the resource draining should happen (tick).
@export var tick_rate: float = 1.0
## Resource drain rate per tick
@export var drain_rate: float = 1.0
## Should resource draining happen from object instantiation
@export var drain_on_start: bool = true
@export_group("")

@onready var resource_bar: ProgressBar = %ResourceBar
@onready var resource_timer: Timer = %ResourceTimer
# Current number of resources
@onready var resources: float = start_resources

func _ready() -> void:
	# Setup resource bar
	resource_bar.max_value = max_resources
	resource_bar.min_value = 0.0
	resource_bar.value = resources
	# Setup resource drain timer
	resource_timer.wait_time = tick_rate
	resource_timer.one_shot = false
	resource_timer.timeout.connect(_on_resource_timer_timeout)
	if drain_on_start:
		resource_timer.start()


func start_resource_draining() -> void:
	resource_timer.start()


func add_resource(food: Food) -> void:
	resources += food.calories
	resources = clamp(resources, 0.0, max_resources)
	resource_added.emit(resources)
	_update_resource_bar()


func remove_resource(amount: float) -> void:
	if resources <= 0.0:
		return
	resources -= amount
	Gamestate.resources_consumed(floori(amount))
	resources = clamp(resources, 0.0, max_resources)
	resource_removed.emit(resources)
	_update_resource_bar()

	if resources == 0.0:
		depleted.emit()
		Gamestate.end_run()
		push_warning("Resources depleted")


func _on_resource_timer_timeout() -> void:
	remove_resource(drain_rate)


func _update_resource_bar() -> void:
	if resource_bar != null:
		resource_bar.value = resources
