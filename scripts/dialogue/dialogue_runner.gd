extends Node

signal line_ready(line: DialogueLine)
signal choices_ready(choices: Array[DialogueChoice])
signal dialogue_completed
signal battle_requested(enemy_id: StringName)

var current_node: StringName = &""
var current_choices: Array[DialogueChoice] = []
var flags: Dictionary = {}

var _dialogue_nodes: Dictionary = {}
var _context: Dictionary = {}
var _state_query: GameStateQuery
var _localization: RefCounted
var _running: bool = false

func set_state_query(state_query: GameStateQuery) -> void:
	_state_query = state_query

func set_localization(localization: RefCounted) -> void:
	_localization = localization

func start(dialogue_sequence: DialogueSequence, context: Dictionary = {}) -> void:
	_context = context.duplicate(true)
	current_choices = []
	flags = {}
	_running = true

	if dialogue_sequence == null:
		_dialogue_nodes = {}
		_complete_dialogue()
		return

	_dialogue_nodes = dialogue_sequence.nodes

	var start_node: StringName = dialogue_sequence.start_node_id
	if start_node == &"":
		_complete_dialogue()
		return

	current_node = start_node
	_process_until_input()

func advance() -> void:
	if not _running:
		return
	if not current_choices.is_empty():
		return
	_step_to_next_node()
	_process_until_input()

func choose(choice_index: int) -> void:
	if not _running:
		return
	if choice_index < 0 or choice_index >= current_choices.size():
		push_warning("Dialogue choice index out of bounds: %d" % choice_index)
		return

	var choice: DialogueChoice = current_choices[choice_index]
	_apply_flag_changes(choice.set_flags)
	current_choices = []
	current_node = choice.next_node_id
	_process_until_input()

func _process_until_input() -> void:
	while _running:
		var node: DialogueNode = _dialogue_nodes.get(current_node, null)
		if node == null:
			push_warning("Dialogue node not found: %s" % String(current_node))
			_complete_dialogue()
			return

		match String(node.node_type):
			"line":
				_emit_line(node)
				return
			"choice":
				_emit_choices(node)
				return
			"condition":
				var passed := _evaluate_condition(node.condition)
				current_node = node.true_next_node_id if passed else node.false_next_node_id
				if current_node == &"":
					_complete_dialogue()
					return
			"event":
				_handle_event(node)
				if not _running:
					return
			"jump":
				current_node = node.target_node_id
				if current_node == &"":
					_complete_dialogue()
					return
			"end":
				_complete_dialogue()
				return
			_:
				push_warning("Unknown dialogue node type: %s" % String(node.node_type))
				_complete_dialogue()
				return

func _step_to_next_node() -> void:
	var node: DialogueNode = _dialogue_nodes.get(current_node, null)
	if node == null:
		_complete_dialogue()
		return
	current_node = node.next_node_id
	if current_node == &"":
		_complete_dialogue()

func _emit_line(node: DialogueNode) -> void:
	var line_payload := DialogueLine.new()
	line_payload.speaker_id = node.speaker_id
	line_payload.speaker = node.speaker
	line_payload.side = node.side
	line_payload.text = _resolve_text(node.text, node.text_key, "...")
	line_payload.text_key = node.text_key
	line_payload.player_speaker_id = node.player_speaker_id
	line_payload.npc_speaker_id = node.npc_speaker_id
	line_payload.player_portrait = node.player_portrait
	line_payload.npc_portrait = node.npc_portrait
	emit_signal("line_ready", line_payload)

func _emit_choices(node: DialogueNode) -> void:
	current_choices = []
	for choice: DialogueChoice in node.choices:
		var resolved_choice := choice.clone()
		resolved_choice.text = _resolve_text(choice.text, choice.text_key, "...")
		current_choices.append(resolved_choice)
	emit_signal("choices_ready", current_choices)

func _resolve_text(text: String, text_key: StringName, fallback: String) -> String:
	var fallback_text := text if text != "" else fallback
	if text_key == &"":
		return fallback_text
	if _localization != null and _localization.has_method("resolve_text"):
		return _localization.resolve_text(text_key, fallback_text)
	return fallback_text

func _handle_event(node: DialogueNode) -> void:
	match String(node.action):
		"set_flags":
			_apply_flag_changes(node.event_flags)
		"request_battle":
			var enemy_id := node.enemy_id
			if enemy_id == &"":
				enemy_id = StringName(_context.get("enemy_id", &""))
			emit_signal("battle_requested", enemy_id)
			_running = false
			return
		_:
			push_warning("Unhandled dialogue event action: %s" % String(node.action))

	current_node = node.next_node_id
	if current_node == &"":
		_complete_dialogue()

func _apply_flag_changes(flag_changes: Variant) -> void:
	if flag_changes is not Dictionary:
		return
	for key: Variant in flag_changes.keys():
		flags[StringName(key)] = bool(flag_changes[key])

func _evaluate_condition(condition: DialogueCondition) -> bool:
	if condition == null:
		return false

	match String(condition.operator):
		"all":
			for child: DialogueCondition in condition.children:
				if not _evaluate_condition(child):
					return false
			return true
		"any":
			for child: DialogueCondition in condition.children:
				if _evaluate_condition(child):
					return true
			return false
		"not":
			if condition.children.is_empty():
				return true
			return not _evaluate_condition(condition.children[0])
		"kind":
			var id := condition.id
			match String(condition.kind):
				"local_flag", "quest_flag":
					if flags.has(id):
						return bool(flags[id])
					return _state_query != null and _state_query.has_quest_flag(id)
				"prior_victory":
					if _state_query == null:
						return false
					return _state_query.has_prior_victory(id)
				"inventory_item":
					if _state_query == null:
						return false
					return _state_query.has_inventory_item(id)
				_:
					return false
		_:
			return false

func _complete_dialogue() -> void:
	_running = false
	current_node = &""
	current_choices = []
	emit_signal("dialogue_completed")
