class_name DrawCards extends CardEffect

@export var count: int = 1


func apply(_ctx: CardPlayContext) -> void:
	BattleManager.draw_cards(count)
