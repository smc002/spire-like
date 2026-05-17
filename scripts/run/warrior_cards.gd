class_name WarriorCards extends RefCounted

# Factory for the warrior's card pool. Each call returns a fresh Card instance.
# Numerical values follow the standard mid-school deckbuilder roguelike baseline.


# ─────────────────────────────────────────────────────────────────────
# Starter deck
# ─────────────────────────────────────────────────────────────────────

static func starter_deck() -> Array[Card]:
	var d: Array[Card] = []
	for _i in 5:
		d.append(basic_attack())
	for _i in 4:
		d.append(basic_block())
	d.append(heavy_swing())
	return d


# ─────────────────────────────────────────────────────────────────────
# Basic cards (only in starter deck — never in reward pool)
# ─────────────────────────────────────────────────────────────────────

static func basic_attack() -> Card:
	var c := Card.new()
	c.id = &"basic_attack"
	c.display_name = "Basic Attack"
	c.description = "Deal 6 damage."
	c.cost = 1
	c.type = Card.Type.ATTACK
	c.rarity = Card.Rarity.BASIC
	c.target = Card.Target.ENEMY
	var dmg := DealDamage.new()
	dmg.amount = 6
	c.effects.append(dmg)
	return c


static func basic_block() -> Card:
	var c := Card.new()
	c.id = &"basic_block"
	c.display_name = "Basic Block"
	c.description = "Gain 5 Block."
	c.cost = 1
	c.type = Card.Type.SKILL
	c.rarity = Card.Rarity.BASIC
	c.target = Card.Target.SELF
	var blk := GainBlock.new()
	blk.amount = 5
	c.effects.append(blk)
	return c


static func heavy_swing() -> Card:
	var c := Card.new()
	c.id = &"heavy_swing"
	c.display_name = "Heavy Swing"
	c.description = "Deal 8 damage. Apply 2 Vulnerable."
	c.cost = 2
	c.type = Card.Type.ATTACK
	c.rarity = Card.Rarity.BASIC
	c.target = Card.Target.ENEMY
	var dmg := DealDamage.new()
	dmg.amount = 8
	c.effects.append(dmg)
	var vuln := ApplyStatusEffect.new()
	vuln.status_id = &"vulnerable"
	vuln.stacks = 2
	c.effects.append(vuln)
	return c


# ─────────────────────────────────────────────────────────────────────
# Common reward pool
# ─────────────────────────────────────────────────────────────────────

static func sweep() -> Card:
	var c := Card.new()
	c.id = &"sweep"
	c.display_name = "Sweep"
	c.description = "Deal 8 damage to ALL enemies."
	c.cost = 1
	c.type = Card.Type.ATTACK
	c.rarity = Card.Rarity.COMMON
	c.target = Card.Target.ALL_ENEMIES
	var dmg := DealDamage.new()
	dmg.amount = 8
	dmg.hits_all = true
	c.effects.append(dmg)
	return c


static func forearm_smash() -> Card:
	var c := Card.new()
	c.id = &"forearm_smash"
	c.display_name = "Forearm Smash"
	c.description = "Deal 12 damage. Apply 2 Weak."
	c.cost = 2
	c.type = Card.Type.ATTACK
	c.rarity = Card.Rarity.COMMON
	c.target = Card.Target.ENEMY
	var dmg := DealDamage.new()
	dmg.amount = 12
	c.effects.append(dmg)
	var weak := ApplyStatusEffect.new()
	weak.status_id = &"weak"
	weak.stacks = 2
	c.effects.append(weak)
	return c


static func iron_wave() -> Card:
	var c := Card.new()
	c.id = &"iron_wave"
	c.display_name = "Iron Wave"
	c.description = "Deal 5 damage. Gain 5 Block."
	c.cost = 1
	c.type = Card.Type.ATTACK
	c.rarity = Card.Rarity.COMMON
	c.target = Card.Target.ENEMY
	var dmg := DealDamage.new()
	dmg.amount = 5
	c.effects.append(dmg)
	var blk := GainBlock.new()
	blk.amount = 5
	c.effects.append(blk)
	return c


static func pommel_strike() -> Card:
	var c := Card.new()
	c.id = &"pommel_strike"
	c.display_name = "Pommel Strike"
	c.description = "Deal 9 damage. Draw 1 card."
	c.cost = 1
	c.type = Card.Type.ATTACK
	c.rarity = Card.Rarity.COMMON
	c.target = Card.Target.ENEMY
	var dmg := DealDamage.new()
	dmg.amount = 9
	c.effects.append(dmg)
	var draw := DrawCards.new()
	draw.count = 1
	c.effects.append(draw)
	return c


static func brace() -> Card:
	var c := Card.new()
	c.id = &"brace"
	c.display_name = "Brace"
	c.description = "Gain 8 Block. Draw 1 card."
	c.cost = 1
	c.type = Card.Type.SKILL
	c.rarity = Card.Rarity.COMMON
	c.target = Card.Target.SELF
	var blk := GainBlock.new()
	blk.amount = 8
	c.effects.append(blk)
	var draw := DrawCards.new()
	draw.count = 1
	c.effects.append(draw)
	return c


static func thunderclap() -> Card:
	var c := Card.new()
	c.id = &"thunderclap"
	c.display_name = "Thunderclap"
	c.description = "Deal 4 damage and apply 1 Vulnerable to ALL enemies."
	c.cost = 1
	c.type = Card.Type.ATTACK
	c.rarity = Card.Rarity.COMMON
	c.target = Card.Target.ALL_ENEMIES
	var dmg := DealDamage.new()
	dmg.amount = 4
	dmg.hits_all = true
	c.effects.append(dmg)
	var vuln := ApplyStatusEffect.new()
	vuln.status_id = &"vulnerable"
	vuln.stacks = 1
	vuln.to_all_enemies = true
	c.effects.append(vuln)
	return c


static func double_strike() -> Card:
	var c := Card.new()
	c.id = &"double_strike"
	c.display_name = "Double Strike"
	c.description = "Deal 5 damage twice."
	c.cost = 1
	c.type = Card.Type.ATTACK
	c.rarity = Card.Rarity.COMMON
	c.target = Card.Target.ENEMY
	var dmg := DealDamage.new()
	dmg.amount = 5
	dmg.times = 2
	c.effects.append(dmg)
	return c


# ─────────────────────────────────────────────────────────────────────
# Uncommon reward pool
# ─────────────────────────────────────────────────────────────────────

static func adrenaline_rush() -> Card:
	var c := Card.new()
	c.id = &"adrenaline_rush"
	c.display_name = "Adrenaline Rush"
	c.description = "Gain 2 Energy. Exhaust."
	c.cost = 1
	c.type = Card.Type.SKILL
	c.rarity = Card.Rarity.UNCOMMON
	c.target = Card.Target.SELF
	c.exhaust = true
	var eng := GainEnergy.new()
	eng.amount = 2
	c.effects.append(eng)
	return c


static func shockwave() -> Card:
	var c := Card.new()
	c.id = &"shockwave"
	c.display_name = "Shockwave"
	c.description = "Apply 3 Weak and 3 Vulnerable to ALL enemies. Exhaust."
	c.cost = 2
	c.type = Card.Type.SKILL
	c.rarity = Card.Rarity.UNCOMMON
	c.target = Card.Target.ALL_ENEMIES
	c.exhaust = true
	var weak := ApplyStatusEffect.new()
	weak.status_id = &"weak"
	weak.stacks = 3
	weak.to_all_enemies = true
	c.effects.append(weak)
	var vuln := ApplyStatusEffect.new()
	vuln.status_id = &"vulnerable"
	vuln.stacks = 3
	vuln.to_all_enemies = true
	c.effects.append(vuln)
	return c


static func stoke_rage() -> Card:
	var c := Card.new()
	c.id = &"stoke_rage"
	c.display_name = "Stoke Rage"
	c.description = "Gain 2 Strength."
	c.cost = 1
	c.type = Card.Type.POWER
	c.rarity = Card.Rarity.UNCOMMON
	c.target = Card.Target.SELF
	c.exhaust = true   # Power cards are removed for the rest of combat
	var st := ApplyStatusEffect.new()
	st.status_id = &"strength"
	st.stacks = 2
	st.to_self = true
	c.effects.append(st)
	return c


# ─────────────────────────────────────────────────────────────────────
# Pool lookup
# ─────────────────────────────────────────────────────────────────────

static func by_rarity(rarity: int) -> Array[Card]:
	var result: Array[Card] = []
	match rarity:
		Card.Rarity.COMMON:
			result.append(sweep())
			result.append(forearm_smash())
			result.append(iron_wave())
			result.append(pommel_strike())
			result.append(brace())
			result.append(thunderclap())
			result.append(double_strike())
		Card.Rarity.UNCOMMON:
			result.append(adrenaline_rush())
			result.append(shockwave())
			result.append(stoke_rage())
		Card.Rarity.RARE:
			pass   # TODO when rare card archetypes are implemented
	return result


static func all_rewardable() -> Array[Card]:
	var result: Array[Card] = []
	for r in [Card.Rarity.COMMON, Card.Rarity.UNCOMMON, Card.Rarity.RARE]:
		for c in by_rarity(r):
			result.append(c)
	return result
