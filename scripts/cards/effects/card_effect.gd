class_name CardEffect extends Resource

func apply(_ctx: CardPlayContext) -> void:
	push_error("CardEffect.apply() must be overridden in " + str(get_script().resource_path))
