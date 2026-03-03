extends Node

@onready var world: Node = $WorldIso
@onready var battle: Control = $Battle
@onready var battle_controller: Node = $Battle/BattleController
@onready var stat_screen: PanelContainer = $StatScreen
@onready var stat_label: RichTextLabel = $StatScreen/Margin/VBox/Stats
@onready var rest_button: Button = $StatScreen/Margin/VBox/Actions/Rest
@onready var eat_button: Button = $StatScreen/Margin/VBox/Actions/Eat

var enemy_map := {
	&"martial_artist": preload("res://resources/fighters/martial_artist.tres"),
	&"saibaman": preload("res://resources/fighters/saibaman.tres"),
	&"raditz_scout": preload("res://resources/fighters/raditz_scout.tres"),
	&"frieza_force": preload("res://resources/fighters/frieza_force.tres"),
	&"frieza": preload("res://resources/fighters/frieza.tres"),
}

var active_enemy_id: StringName = &""

func _ready() -> void:
	world.encounter_requested.connect(_on_encounter_requested)
	battle_controller.battle_finished.connect(_on_battle_finished)
	rest_button.pressed.connect(_rest_outside_battle)
	eat_button.pressed.connect(_eat_outside_battle)
	battle.visible = false
	stat_screen.visible = false

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_toggle_stat_screen()
		get_viewport().set_input_as_handled()

func _toggle_stat_screen() -> void:
	stat_screen.visible = not stat_screen.visible
	if stat_screen.visible:
		_refresh_stat_screen()

func _refresh_stat_screen() -> void:
	rest_button.disabled = battle.visible
	eat_button.disabled = battle.visible
	var lines: PackedStringArray
	if battle.visible:
		lines = battle_controller.get_player_stat_lines()
	else:
		lines = PackedStringArray([
			"Name: %s" % battle_controller.player_base.fighter_name,
			"HP: %d / %d" % [battle_controller.player_base.hp, battle_controller.player_base.max_hp],
			"Stamina: %d / %d" % [battle_controller.player_base.stamina, battle_controller.player_base.max_stamina],
			"Stored Ki: %d / %d" % [battle_controller.player_base.stored_ki, battle_controller.player_base.max_stored_ki],
			"Drawn Ki: %d / %d" % [battle_controller.player_base.drawn_ki, battle_controller.player_base.max_drawn_ki],
			"Physical Strength: %d" % battle_controller.player_base.physical_strength,
			"Ki Strength: %d" % battle_controller.player_base.ki_strength,
			"Speed: %d" % battle_controller.player_base.speed,
		])
	stat_label.text = "[b]Stat Screen[/b]\n" + "\n".join(lines)

func _rest_outside_battle() -> void:
	if battle.visible:
		return
	battle_controller.player_base.hp = battle_controller.player_base.max_hp
	battle_controller.player_base.stamina = battle_controller.player_base.max_stamina
	battle_controller.player_base.form_level = battle_controller.player_base.base_form_override_level
	battle_controller.player_base.highest_form_rewarded_this_rest = battle_controller.player_base.base_form_override_level
	battle_controller.player_base.kaioken_active = false
	_refresh_stat_screen()

func _eat_outside_battle() -> void:
	if battle.visible:
		return
	battle_controller.player_base.stored_ki = battle_controller.player_base.max_stored_ki
	_refresh_stat_screen()

func _on_encounter_requested(enemy_id: StringName) -> void:
	if not enemy_map.has(enemy_id):
		push_warning("Unknown enemy id: %s" % enemy_id)
		return
	active_enemy_id = enemy_id
	battle_controller.start_battle(enemy_map[enemy_id])
	world.visible = false
	battle.visible = true
	battle.process_mode = Node.PROCESS_MODE_INHERIT
	if stat_screen.visible:
		_refresh_stat_screen()

func _on_battle_finished(result: String) -> void:
	battle.visible = false
	world.visible = true
	if result == "player" and active_enemy_id != &"":
		world.mark_enemy_defeated(active_enemy_id)
	active_enemy_id = &""
	if stat_screen.visible:
		_refresh_stat_screen()
