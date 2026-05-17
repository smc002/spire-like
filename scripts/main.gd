extends Node2D

# Entry point. Switches to main menu on boot. Flip USE_AUTO_PLAY to run
# the headless multi-battle test driver instead.

const USE_AUTO_PLAY: bool = false


func _ready() -> void:
	print("Spire-like booted.")
	if USE_AUTO_PLAY:
		_start_auto_play()
	else:
		call_deferred("_switch_to_main_menu")


func _switch_to_main_menu() -> void:
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")


func _start_auto_play() -> void:
	var t: Node = preload("res://scripts/debug/test_run.gd").new()
	t.name = "TestRun"
	add_child(t)
	t.run()
