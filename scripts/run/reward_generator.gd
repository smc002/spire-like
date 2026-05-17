class_name RewardGenerator extends RefCounted

# Generates a RewardPackage for a finished encounter.
# Rarity-distribution and gold-amount baselines follow the standard
# deckbuilder roguelike: common-heavy with uncommon spikes and rare drops.


const CARD_CHOICE_COUNT: int = 3


static func for_encounter(encounter: Encounter, rng: RandomNumberGenerator) -> RewardPackage:
	var pkg := RewardPackage.new()
	pkg.gold = _roll_gold(encounter.tier, rng)
	pkg.card_choices = _draw_card_options(encounter.tier, rng, CARD_CHOICE_COUNT)
	return pkg


static func _roll_gold(tier: int, rng: RandomNumberGenerator) -> int:
	match tier:
		Encounter.Tier.EASY:
			return rng.randi_range(10, 15)
		Encounter.Tier.NORMAL:
			return rng.randi_range(10, 20)
		Encounter.Tier.ELITE:
			return rng.randi_range(25, 35)
		Encounter.Tier.BOSS:
			return 100
		_:
			return 5


static func _draw_card_options(tier: int, rng: RandomNumberGenerator, count: int) -> Array[Card]:
	var picked: Array[Card] = []
	var used_ids: Array[StringName] = []
	for _i in count:
		var rarity := _roll_rarity(tier, rng)
		var picked_card := _pick_one_unused(rarity, used_ids, rng)
		if picked_card == null:
			# Fallback through other rarities
			for fallback in [Card.Rarity.COMMON, Card.Rarity.UNCOMMON, Card.Rarity.RARE]:
				picked_card = _pick_one_unused(fallback, used_ids, rng)
				if picked_card != null:
					break
		if picked_card == null:
			break
		used_ids.append(picked_card.id)
		picked.append(picked_card)
	return picked


static func _pick_one_unused(rarity: int, used_ids: Array[StringName], rng: RandomNumberGenerator) -> Card:
	var pool := WarriorCards.by_rarity(rarity)
	var available: Array[Card] = []
	for c in pool:
		if not (c.id in used_ids):
			available.append(c)
	if available.is_empty():
		return null
	return available[rng.randi_range(0, available.size() - 1)]


static func _roll_rarity(tier: int, rng: RandomNumberGenerator) -> int:
	var roll := rng.randf()
	match tier:
		Encounter.Tier.NORMAL, Encounter.Tier.EASY:
			if roll < 0.60: return Card.Rarity.COMMON
			if roll < 0.97: return Card.Rarity.UNCOMMON
			return Card.Rarity.RARE
		Encounter.Tier.ELITE:
			if roll < 0.50: return Card.Rarity.COMMON
			if roll < 0.90: return Card.Rarity.UNCOMMON
			return Card.Rarity.RARE
		Encounter.Tier.BOSS:
			return Card.Rarity.RARE
		_:
			return Card.Rarity.COMMON
