@tool
class_name GameState
extends Node

signal score_changed(score: int)
signal resources_collected_changed(resources_collected: int)
signal resources_consumed_changed(resources_consumed: int)
signal run_started
signal run_ended(final_score: int)

var second_counter: float = 0.0
var score: int = 0
var res_consumed: int = 0
var res_collected: int = 0
var game_running: bool = false

func _process(delta: float) -> void:
	if game_running:
		second_counter += delta
		if second_counter >= 1.0:
			score += 1
			second_counter -= 1
			score_changed.emit(score)


func start_run():
	score = 0
	score_changed.emit(score)
	res_collected = 0
	resources_collected_changed.emit(res_collected)
	res_consumed = 0
	resources_consumed_changed.emit(res_consumed)
	second_counter = 0.0
	game_running = true
	run_started.emit()


func end_run():
	if not game_running:
		return

	game_running = false
	run_ended.emit(score)


func resources_collected(amount: int):
	res_collected += amount
	resources_collected_changed.emit(res_collected)


func resources_consumed(amount: int):
	res_consumed += amount
	resources_consumed_changed.emit(res_consumed)
