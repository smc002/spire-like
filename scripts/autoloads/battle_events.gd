extends Node

# Lifecycle
signal battle_started
signal battle_won
signal battle_lost

# Turns
signal turn_started(actor: Actor)
signal turn_ended(actor: Actor)

# Cards
signal card_drawn(card: Card)
signal card_played(card: Card, targets: Array)
signal card_resolved(card: Card)
signal card_discarded(card: Card)
signal card_exhausted(card: Card)

# Damage (intent is modifiable; dealt is post-resolution)
signal damage_intent(ctx: DamageContext)
signal damage_dealt(source: Actor, target: Actor, actual: int, blocked: int)

# Block (intent is modifiable)
signal block_intent(ctx: BlockContext)
signal block_gained(target: Actor, amount: int)

# Status
signal status_applied(target: Actor, status_id: StringName, total_stacks: int)

# Enemies
signal enemy_intent_changed(enemy: Enemy, move: EnemyMove)
signal actor_died(actor: Actor)
