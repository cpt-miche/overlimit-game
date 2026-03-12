extends Node

signal line_ready(line: Dictionary)
signal choices_ready(choices: Array)
signal dialogue_completed
signal battle_requested(enemy_id: StringName)

var current_node: StringName = &""
var current_choices: Array = []
var flags: Dictionary = {}

var _dialogue_nodes: Dictionary = {}
var _context: Dictionary = {}
var _state_query: GameStateQuery
var _running: bool = false

func set_state_query(state_query: GameStateQuery) -> void:
	_state_query = state_query

func start(dialogue_schema: Dictionary, context: Dictionary = {}) -> void:
	_dialogue_nodes = dialogue_schema.get("nodes", {})
	_context = context.duplicate(true)
	current_choices = []
	flags = {}
	_running = true

	var start_node: StringName = StringName(dialogue_schema.get("start", &""))
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

	var choice: Dictionary = current_choices[choice_index]
	_apply_flag_changes(choice.get("set_flags", {}))
	current_choices = []
	current_node = StringName(choice.get("next", &""))
	_process_until_input()

func _process_until_input() -> void:
	while _running:
		var node: Dictionary = _dialogue_nodes.get(current_node, {})
		if node.is_empty():
			push_warning("Dialogue node not found: %s" % String(current_node))
			_complete_dialogue()
			return

		var node_type: String = String(node.get("type", "line"))
		match node_type:
			"line":
				_emit_line(node)
				return
			"choice":
				_emit_choices(node)
				return
			"condition":
				var passed := _evaluate_condition(node.get("check", {}))
				current_node = StringName(node.get("true_next", &"")) if passed else StringName(node.get("false_next", &""))
				if current_node == &"":
					_complete_dialogue()
					return
			"event":
				_handle_event(node)
				if not _running:
					return
			"jump":
				current_node = StringName(node.get("target", &""))
				if current_node == &"":
					_complete_dialogue()
					return
			"end":
				_complete_dialogue()
				return
			_:
				push_warning("Unknown dialogue node type: %s" % node_type)
				_complete_dialogue()
				return

func _step_to_next_node() -> void:
	var node: Dictionary = _dialogue_nodes.get(current_node, {})
	current_node = StringName(node.get("next", &""))
	if current_node == &"":
		_complete_dialogue()

func _emit_line(node: Dictionary) -> void:
	var line_payload := {
		"speaker": String(node.get("speaker", "")),
		"side": String(node.get("side", "npc")),
		"text": String(node.get("text", "...")),
		"player_portrait": node.get("player_portrait", null),
		"npc_portrait": node.get("npc_portrait", null),
	}
	emit_signal("line_ready", line_payload)

func _emit_choices(node: Dictionary) -> void:
	current_choices = []
	for entry: Variant in node.get("choices", []):
		if entry is Dictionary:
			current_choices.append(entry)
	emit_signal("choices_ready", current_choices)

func _handle_event(node: Dictionary) -> void:
	var action: String = String(node.get("action", ""))
	match action:
		"set_flags":
			_apply_flag_changes(node.get("flags", {}))
		"request_battle":
			var enemy_id := StringName(node.get("enemy_id", _context.get("enemy_id", &"")))
			emit_signal("battle_requested", enemy_id)
			_running = false
			return
		_:
			push_warning("Unhandled dialogue event action: %s" % action)

	current_node = StringName(node.get("next", &""))
	if current_node == &"":
		_complete_dialogue()

func _apply_flag_changes(flag_changes: Variant) -> void:
	if flag_changes is not Dictionary:
		return
	for key: Variant in flag_changes.keys():
		flags[key] = bool(flag_changes[key])

func _evaluate_condition(check: Variant) -> bool:
	if check is Dictionary:
		var check_dict: Dictionary = check
		if check_dict.has("all"):
			for child_check: Variant in check_dict["all"]:
				if not _evaluate_condition(child_check):
					return false
			return true
		if check_dict.has("any"):
			for child_check: Variant in check_dict["any"]:
				if _evaluate_condition(child_check):
					return true
			return false
		if check_dict.has("not"):
			return not _evaluate_condition(check_dict["not"])

		var kind: String = String(check_dict.get("kind", ""))
		var id: StringName = StringName(check_dict.get("id", &""))
		match kind:
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
	return false

func _complete_dialogue() -> void:
	_running = false
	current_node = &""
	current_choices = []
	emit_signal("dialogue_completed")
