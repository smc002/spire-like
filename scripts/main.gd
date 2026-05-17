extends Node2D

# Entry point. Set USE_AUTO_PLAY=true to run the headless multi-battle
# test driver instead of the human-playable UI.

const USE_AUTO_PLAY: bool = false


func _ready() -> void:
	print("Spire-like booted.")
	if USE_AUTO_PLAY:
		_start_auto_play()
	else:
		call_deferred("_switch_to_battle_ui")


func _switch_to_battle_ui() -> void:
	get_tree().change_scene_to_file("res://scenes/battle_scene.tscn")


func _start_auto_play() -> void:
	var t: Node = preload("res://scripts/debug/test_run.gd").new()
	t.name = "TestRun"
	add_child(t)
	t.run()
