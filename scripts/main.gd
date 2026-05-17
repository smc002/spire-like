extends Node2D


func _ready() -> void:
	print("Spire-like booted.")
	var test_script: GDScript = preload("res://scripts/debug/test_battle.gd")
	var test_node: Node = test_script.new()
	test_node.name = "TestBattle"
	add_child(test_node)
	test_node.run_test()
