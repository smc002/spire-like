class_name Player extends Actor

var deck: Array[Card] = []
var draw_pile: Array[Card] = []
var hand: Array[Card] = []
var discard_pile: Array[Card] = []
var exhaust_pile: Array[Card] = []

var energy: int = 0
var max_energy: int = 3
var draw_count: int = 5


# Called once per run (not per battle)
func setup_run(p_max_hp: int, p_deck: Array[Card]) -> void:
	setup(p_max_hp)
	deck.clear()
	for c in p_deck:
		deck.append(c.duplicate(true) as Card)


# Called at the start of each battle
func setup_combat() -> void:
	draw_pile.clear()
	for c in deck:
		draw_pile.append(c.duplicate(true) as Card)
	draw_pile.shuffle()
	hand.clear()
	discard_pile.clear()
	exhaust_pile.clear()
	energy = 0
	block = 0
