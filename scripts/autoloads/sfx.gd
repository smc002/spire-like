extends Node

# Sound effects + BGM. Silently no-ops when audio files are missing,
# so the game runs fine before you drop .ogg/.wav files into assets/audio/.
#
# To add a sound: put a file at one of the paths below and it gets picked
# up next launch. Naming convention: snake_case, .ogg preferred.


const POOL_SIZE: int = 8

const SFX_PATHS: Dictionary = {
	&"card_attack":   "res://assets/audio/sfx/card_attack.ogg",
	&"card_skill":    "res://assets/audio/sfx/card_skill.ogg",
	&"card_power":    "res://assets/audio/sfx/card_power.ogg",
	&"card_draw":     "res://assets/audio/sfx/card_draw.ogg",
	&"hit":           "res://assets/audio/sfx/hit.ogg",
	&"block":         "res://assets/audio/sfx/block.ogg",
	&"status_buff":   "res://assets/audio/sfx/status_buff.ogg",
	&"status_debuff": "res://assets/audio/sfx/status_debuff.ogg",
	&"enemy_death":   "res://assets/audio/sfx/enemy_death.ogg",
	&"end_turn":      "res://assets/audio/sfx/end_turn.ogg",
	&"victory":       "res://assets/audio/sfx/victory.ogg",
	&"defeat":        "res://assets/audio/sfx/defeat.ogg",
	&"ui_click":      "res://assets/audio/sfx/ui_click.ogg",
}

const BGM_PATHS: Dictionary = {
	&"battle":    "res://assets/audio/bgm/battle.ogg",
	&"menu":      "res://assets/audio/bgm/menu.ogg",
	&"victory":   "res://assets/audio/bgm/victory.ogg",
}


var _sfx_streams: Dictionary = {}
var _bgm_streams: Dictionary = {}
var _players: Array[AudioStreamPlayer] = []
var _bgm_player: AudioStreamPlayer
var _master_volume: float = 0.8  # 0..1


func _ready() -> void:
	for _i in POOL_SIZE:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_players.append(p)
	_bgm_player = AudioStreamPlayer.new()
	add_child(_bgm_player)

	for id in SFX_PATHS:
		var path: String = SFX_PATHS[id]
		if ResourceLoader.exists(path):
			_sfx_streams[id] = load(path)
	for id in BGM_PATHS:
		var path: String = BGM_PATHS[id]
		if ResourceLoader.exists(path):
			_bgm_streams[id] = load(path)

	# Connect to battle events for automatic SFX hooks
	BattleEvents.card_played.connect(_on_card_played)
	BattleEvents.card_drawn.connect(func(_c): play(&"card_draw"))
	BattleEvents.damage_dealt.connect(_on_damage_dealt)
	BattleEvents.block_gained.connect(_on_block_gained)
	BattleEvents.status_applied.connect(_on_status_applied)
	BattleEvents.actor_died.connect(_on_actor_died)
	BattleEvents.battle_won.connect(func(): play(&"victory"))
	BattleEvents.battle_lost.connect(func(): play(&"defeat"))


func play(id: StringName, volume_db: float = 0.0) -> void:
	if not _sfx_streams.has(id):
		return
	var stream: AudioStream = _sfx_streams[id]
	for p in _players:
		if not p.playing:
			p.stream = stream
			p.volume_db = volume_db + _db_offset()
			p.play()
			return


func play_bgm(id: StringName) -> void:
	if not _bgm_streams.has(id):
		if _bgm_player.playing:
			_bgm_player.stop()
		return
	if _bgm_player.stream == _bgm_streams[id] and _bgm_player.playing:
		return
	_bgm_player.stream = _bgm_streams[id]
	_bgm_player.volume_db = _db_offset()
	_bgm_player.play()


func stop_bgm() -> void:
	if _bgm_player.playing:
		_bgm_player.stop()


func set_master_volume(v: float) -> void:
	_master_volume = clampf(v, 0.0, 1.0)
	if _bgm_player.playing:
		_bgm_player.volume_db = _db_offset()


func get_master_volume() -> float:
	return _master_volume


func _db_offset() -> float:
	if _master_volume <= 0.001:
		return -80.0
	return linear_to_db(_master_volume)


func _on_card_played(card: Card, _targets) -> void:
	match card.type:
		Card.Type.ATTACK: play(&"card_attack")
		Card.Type.POWER: play(&"card_power")
		_: play(&"card_skill")


func _on_damage_dealt(_src, _tgt, actual: int, blocked: int) -> void:
	if actual > 0:
		play(&"hit")
	if blocked > 0 and actual == 0:
		play(&"block")


func _on_block_gained(_tgt, amount: int) -> void:
	if amount > 0:
		play(&"block", -4.0)


func _on_status_applied(_tgt, id: StringName, _total: int) -> void:
	var data := StatusRegistry.get_status(id)
	if data and data.is_debuff:
		play(&"status_debuff", -2.0)
	else:
		play(&"status_buff", -2.0)


func _on_actor_died(_a) -> void:
	play(&"enemy_death")
