extends Node

enum GameState {
	WORLD,
	DIALOGUE,
	BATTLE,
}

@onready var world: Node = $WorldIso
@onready var battle: Control = $Battle
@onready var battle_controller: Node = $Battle/BattleController
@onready var stat_screen: PanelContainer = $StatScreen
@onready var menu_tabs: TabContainer = $StatScreen/Margin/VBox/Tabs
@onready var stat_label: RichTextLabel = $StatScreen/Margin/VBox/Tabs/Inventory/Margin/VBox/Stats
@onready var rest_button: Button = $StatScreen/Margin/VBox/Tabs/Inventory/Margin/VBox/Actions/Rest
@onready var eat_button: Button = $StatScreen/Margin/VBox/Tabs/Inventory/Margin/VBox/Actions/Eat
@onready var dialogue_box: Node = $DialogueBox
@onready var player_node: Node = $WorldIso/Player

var enemy_map := {
	&"martial_artist": preload("res://resources/fighters/martial_artist.tres"),
	&"saibaman": preload("res://resources/fighters/saibaman.tres"),
	&"raditz_scout": preload("res://resources/fighters/raditz_scout.tres"),
	&"frieza_force": preload("res://resources/fighters/frieza_force.tres"),
	&"frieza": preload("res://resources/fighters/frieza.tres"),
}

var dialogue_data := {
	&"raditz_intro": {
		"npc_portrait": preload("res://assets/sprites/enemies/raditz_idle.svg"),
		"lines": [
			{"speaker": "Raditz", "side": "npc", "text": "Kakarot's weakling friend? You're in my way."},
			{"speaker": "You", "side": "player", "text": "I'm done letting raiders run this place."},
			{"speaker": "Raditz", "side": "npc", "text": "Show me if you've got Saiyan blood to back that up."},
		],
	},
}

var player_dialogue_portrait: Texture2D = preload("res://assets/sprites/player/player_idle.svg")

var active_enemy_id: StringName = &""
var current_state: GameState = GameState.WORLD
var pending_enemy_id: StringName = &""

func _ready() -> void:
	world.encounter_requested.connect(_on_encounter_requested)
	battle_controller.battle_finished.connect(_on_battle_finished)
	rest_button.pressed.connect(_rest_outside_battle)
	eat_button.pressed.connect(_eat_outside_battle)
	dialogue_box.connect("dialogue_finished", _on_dialogue_finished)
	battle.visible = false
	stat_screen.visible = false
	_set_state(GameState.WORLD)

func _unhandled_input(event: InputEvent) -> void:
	if current_state == GameState.DIALOGUE:
		return
	if event.is_action_pressed("ui_cancel"):
		_toggle_stat_screen()
		get_viewport().set_input_as_handled()

func _toggle_stat_screen() -> void:
	stat_screen.visible = not stat_screen.visible
	if stat_screen.visible:
		menu_tabs.current_tab = 0
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
	stat_label.text = "[b]Overview[/b]\n" + "\n".join(lines)

func _rest_outside_battle() -> void:
	if battle.visible:
		return
	battle_controller.player_base.hp = battle_controller.player_base.max_hp
	battle_controller.player_base.stamina = battle_controller.player_base.max_stamina
	battle_controller.player_base.form_level = battle_controller.player_base.base_form_override_level
	battle_controller.player_base.highest_form_rewarded_this_rest = battle_controller.player_base.base_form_override_level
	battle_controller.player_base.active_shuten_transformation_id = &""
	_refresh_stat_screen()

func _eat_outside_battle() -> void:
	if battle.visible:
		return
	battle_controller.player_base.stored_ki = battle_controller.player_base.max_stored_ki
	_refresh_stat_screen()

func _on_encounter_requested(enemy_id: StringName, trigger_dialogue: bool, dialogue_key: StringName, display_name: String) -> void:
	if not enemy_map.has(enemy_id):
		push_warning("Unknown enemy id: %s" % enemy_id)
		return
	if trigger_dialogue:
		_start_optional_dialogue(enemy_id, dialogue_key, display_name)
		return
	_start_battle(enemy_id)

func _start_optional_dialogue(enemy_id: StringName, dialogue_key: StringName, display_name: String) -> void:
	pending_enemy_id = enemy_id
	var key_to_use: StringName = dialogue_key
	if key_to_use == &"":
		key_to_use = StringName("%s_intro" % String(enemy_id))

	var entry: Dictionary = dialogue_data.get(key_to_use, {})
	if entry.is_empty():
		_start_battle(enemy_id)
		return

	var npc_portrait: Texture2D = entry.get("npc_portrait", null)
	var lines: Array = entry.get("lines", [])
	if npc_portrait == null or lines.is_empty():
		lines = [{"speaker": display_name, "side": "npc", "text": "Let's settle this in battle."}]

	_set_state(GameState.DIALOGUE)
	dialogue_box.call("start_dialogue", player_dialogue_portrait, npc_portrait, lines)

func _on_dialogue_finished() -> void:
	if pending_enemy_id == &"":
		_set_state(GameState.WORLD)
		return
	var enemy_id := pending_enemy_id
	pending_enemy_id = &""
	_start_battle(enemy_id)

func _start_battle(enemy_id: StringName) -> void:
	active_enemy_id = enemy_id
	battle_controller.start_battle(enemy_map[enemy_id])
	_set_state(GameState.BATTLE)
	if stat_screen.visible:
		_refresh_stat_screen()

func _on_battle_finished(result: String) -> void:
	_set_state(GameState.WORLD)
	if result == "player" and active_enemy_id != &"":
		world.mark_enemy_defeated(active_enemy_id)
	active_enemy_id = &""
	if stat_screen.visible:
		_refresh_stat_screen()

func _set_state(new_state: GameState) -> void:
	current_state = new_state
	match current_state:
		GameState.WORLD:
			world.visible = true
			battle.visible = false
			dialogue_box.visible = false
			battle.process_mode = Node.PROCESS_MODE_DISABLED
			player_node.process_mode = Node.PROCESS_MODE_INHERIT
		GameState.DIALOGUE:
			world.visible = true
			battle.visible = false
			dialogue_box.visible = true
			battle.process_mode = Node.PROCESS_MODE_DISABLED
			player_node.process_mode = Node.PROCESS_MODE_DISABLED
		GameState.BATTLE:
			world.visible = false
			battle.visible = true
			dialogue_box.visible = false
			battle.process_mode = Node.PROCESS_MODE_INHERIT
			player_node.process_mode = Node.PROCESS_MODE_DISABLED
