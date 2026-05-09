extends Node2D

@export var bite_interval: float = 1.0
@export var start_delay: float = 3.0

@onready var ant_hill: AntHill = %AntHill
@onready var food_resource: FoodResource = %FoodResource
@onready var timer: Timer = %Timer

var time_since_start: float = 0.0

func _ready() -> void:
	timer.wait_time = bite_interval
	timer.one_shot = false
	timer.timeout.connect(_on_timer_timeout)
	Gamestate.start_run()


func _process(delta: float) -> void:
	if timer.is_stopped():
		time_since_start += delta
		if time_since_start >= start_delay:
			timer.start()


func _on_timer_timeout() -> void:
	if is_instance_valid(food_resource):
		var food := food_resource.remove_resource(1)
		if food != null:
			ant_hill.add_resource(food)
