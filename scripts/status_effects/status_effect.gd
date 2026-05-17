class_name StatusEffect extends Resource

enum DecayRule { NONE, TURN_END_DECREMENT, TURN_END_RESET, ON_TRIGGER_DECREMENT, END_OF_BATTLE }
enum StackRule { ADD, REPLACE, MAX }

@export var id: StringName
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var is_debuff: bool = false
@export var decay_rule: DecayRule = DecayRule.NONE
@export var stack_rule: StackRule = StackRule.ADD
@export var icon: Texture2D

# The behavior Script (a subclass of StatusBehavior). Assigned by StatusRegistry
# at runtime rather than via @export because Scripts can't be edited inline.
var behavior_class: Script
