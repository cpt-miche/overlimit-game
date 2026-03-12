extends Node

const DialogueRunnerScript = preload("res://scripts/dialogue/dialogue_runner.gd")
const DialoguePresenterScript = preload("res://scripts/dialogue/dialogue_presenter.gd")
const SpeakerRegistryScript = preload("res://scripts/dialogue/speaker_registry.gd")
const DialogueContentLoaderScript = preload("res://scripts/dialogue/dialogue_content_loader.gd")
const DialogueLocalizationScript = preload("res://scripts/dialogue/dialogue_localization.gd")
const MainGameStateQuery = preload("res://scripts/main/main_game_state_query.gd")

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
@onready var dialogue_box: CanvasLayer = $DialogueBox
@onready var player_node: Node = $WorldIso/Player

var enemy_map := {
	&"martial_artist": preload("res://resources/fighters/martial_artist.tres"),
	&"saibaman": preload("res://resources/fighters/saibaman.tres"),
	&"raditz_scout": preload("res://resources/fighters/raditz_scout.tres"),
	&"frieza_force": preload("res://resources/fighters/frieza_force.tres"),
	&"frieza": preload("res://resources/fighters/frieza.tres"),
}

var speaker_registry_data: Dictionary = {}
var dialogue_data: Dictionary = {}
var dialogue_localization: Dictionary = {}

var active_enemy_id: StringName = &""
var current_state: GameState = GameState.WORLD
var pending_enemy_id: StringName = &""
var _dialogue_runner: Node
var _quest_flags: Dictionary = {}
var _victories: Dictionary = {}
var _inventory: Dictionary = {}
var _dialogue_presenter: RefCounted

func _ready() -> void:
	world.encounter_requested.connect(_on_encounter_requested)
	battle_controller.battle_finished.connect(_on_battle_finished)
	rest_button.pressed.connect(_rest_outside_battle)
	eat_button.pressed.connect(_eat_outside_battle)
	dialogue_box.continue_requested.connect(_on_dialogue_continue_requested)
	dialogue_box.choice_selected.connect(_on_dialogue_choice_selected)
	_load_dialogue_content()
	_setup_dialogue_runner()
	battle.visible = false
	stat_screen.visible = false
	_set_state(GameState.WORLD)

func _setup_dialogue_runner() -> void:
	_dialogue_runner = DialogueRunnerScript.new()
	add_child(_dialogue_runner)
	_dialogue_runner.line_ready.connect(_on_dialogue_line_ready)
	_dialogue_runner.choices_ready.connect(_on_dialogue_choices_ready)
	_dialogue_runner.dialogue_completed.connect(_on_dialogue_completed)
	_dialogue_runner.battle_requested.connect(_on_dialogue_battle_requested)
	_dialogue_runner.set_state_query(MainGameStateQuery.new(_quest_flags, _victories, _inventory))
	var speaker_registry: RefCounted = SpeakerRegistryScript.new()
	speaker_registry.configure(speaker_registry_data)
	_dialogue_presenter = DialoguePresenterScript.new(speaker_registry)
	var localization: RefCounted = DialogueLocalizationScript.new()
	localization.configure(dialogue_localization)
	_dialogue_runner.set_localization(localization)

func _load_dialogue_content() -> void:
	var loader: RefCounted = DialogueContentLoaderScript.new()
	dialogue_data = loader.load_dialogues()
	if loader.has_method("get_validation_errors"):
		for error_message: String in loader.get_validation_errors():
			push_warning(error_message)
	speaker_registry_data = loader.load_speakers()
	dialogue_localization = loader.load_localization()
	if _dialogue_presenter != null:
		var speaker_registry: RefCounted = SpeakerRegistryScript.new()
		speaker_registry.configure(speaker_registry_data)
		_dialogue_presenter = DialoguePresenterScript.new(speaker_registry)
	if _dialogue_runner != null:
		var localization: RefCounted = DialogueLocalizationScript.new()
		localization.configure(dialogue_localization)
		_dialogue_runner.set_localization(localization)

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

	var entry: DialogueSequence = dialogue_data.get(key_to_use, null)
	if entry == null:
		_start_battle(enemy_id)
		return

	var defaults: DialogueSessionDefaults = _dialogue_presenter.begin_dialogue(entry)
	dialogue_box.open_dialogue(defaults.player_portrait, defaults.npc_portrait)
	_set_state(GameState.DIALOGUE)
	_dialogue_runner.start(entry, {
		"enemy_id": enemy_id,
		"display_name": display_name,
	})

func _on_dialogue_line_ready(line: DialogueLine) -> void:
	dialogue_box.display_line(_dialogue_presenter.present_line(line))

func _on_dialogue_choices_ready(choices: Array[DialogueChoice]) -> void:
	dialogue_box.display_choices(choices)

func _on_dialogue_continue_requested() -> void:
	_dialogue_runner.advance()

func _on_dialogue_choice_selected(choice_index: int) -> void:
	_dialogue_runner.choose(choice_index)

func _on_dialogue_battle_requested(enemy_id: StringName) -> void:
	dialogue_box.close_dialogue()
	var resolved_enemy_id: StringName = enemy_id
	if resolved_enemy_id == &"":
		resolved_enemy_id = pending_enemy_id
	pending_enemy_id = &""
	_start_battle(resolved_enemy_id)

func _on_dialogue_completed() -> void:
	dialogue_box.close_dialogue()
	if pending_enemy_id != &"":
		var enemy_id := pending_enemy_id
		pending_enemy_id = &""
		_start_battle(enemy_id)
		return
	_set_state(GameState.WORLD)

func _start_battle(enemy_id: StringName) -> void:
	active_enemy_id = enemy_id
	battle_controller.start_battle(enemy_map[enemy_id])
	_set_state(GameState.BATTLE)
	if stat_screen.visible:
		_refresh_stat_screen()

func _on_battle_finished(result: String) -> void:
	_set_state(GameState.WORLD)
	if result == "player" and active_enemy_id != &"":
		_victories[active_enemy_id] = true
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
