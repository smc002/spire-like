class_name GainEnergy extends CardEffect

@export var amount: int = 1


func apply(_ctx: CardPlayContext) -> void:
	BattleManager.player.energy += amount
