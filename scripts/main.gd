extends Node2D


func _ready() -> void:
	print("Spire-like booted.")
	var test_script: GDScript = preload("res://scripts/debug/test_run.gd")
	var test_node: Node = test_script.new()
	test_node.name = "TestRun"
	add_child(test_node)
	test_node.run()
