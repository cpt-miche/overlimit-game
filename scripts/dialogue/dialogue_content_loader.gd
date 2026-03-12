extends RefCounted

const DIALOGUE_DIR := "res://resources/dialogue"
const DIALOGUES_SUBDIR := "dialogues"

var _validation_errors: PackedStringArray = PackedStringArray()

func load_dialogues(path: String = "%s/%s" % [DIALOGUE_DIR, DIALOGUES_SUBDIR]) -> Dictionary:
	_validation_errors.clear()
	var output: Dictionary = {}

	if path.ends_with(".json"):
		var single_file := _load_json(path)
		if single_file.is_empty():
			return {}
		_parse_dialogue_document(path, single_file, output)
		return output

	for file_path: String in _list_json_files(path):
		var parsed := _load_json(file_path)
		if parsed.is_empty():
			continue
		_parse_dialogue_document(file_path, parsed, output)

	return output

func _parse_dialogue_document(path: String, parsed: Dictionary, output: Dictionary) -> void:
	var raw_dialogues: Variant = parsed.get("dialogues", {})
	if raw_dialogues is not Dictionary:
		_add_error(path, "Expected 'dialogues' to be a Dictionary.")
		return
	var raw_dialogues_dict: Dictionary = raw_dialogues

	for dialogue_id_variant: Variant in raw_dialogues_dict.keys():
		var dialogue_id := StringName(dialogue_id_variant)
		if output.has(dialogue_id):
			_add_error(path, "Duplicate dialogue id '%s' found across dialogue files." % String(dialogue_id))
			continue
		var parsed_sequence := _parse_dialogue_sequence(path, dialogue_id, raw_dialogues_dict[dialogue_id_variant])
		if parsed_sequence != null:
			output[dialogue_id] = parsed_sequence

	var raw_scenes: Variant = parsed.get("scenes", {})
	if raw_scenes is Dictionary:
		var raw_scenes_dict: Dictionary = raw_scenes
		for scene_id_variant: Variant in raw_scenes_dict.keys():
			var scene_id := StringName(scene_id_variant)
			if output.has(scene_id):
				_add_error(path, "Duplicate dialogue id '%s' found across dialogue/scenes files." % String(scene_id))
				continue
			var scene_sequence := _parse_linear_scene(path, scene_id, raw_scenes_dict[scene_id_variant])
			if scene_sequence != null:
				output[scene_id] = scene_sequence
	elif parsed.has("scenes"):
		_add_error(path, "Expected 'scenes' to be a Dictionary.")

func _list_json_files(root_path: String) -> Array[String]:
	var files: Array[String] = []
	_collect_json_files(root_path, files)
	files.sort()
	return files

func _collect_json_files(path: String, files: Array[String]) -> void:
	var dir := DirAccess.open(path)
	if dir == null:
		_add_error(path, "Unable to open dialogue directory.")
		return

	dir.list_dir_begin()
	while true:
		var name := dir.get_next()
		if name == "":
			break
		if name.begins_with("."):
			continue

		var full_path := "%s/%s" % [path, name]
		if dir.current_is_dir():
			_collect_json_files(full_path, files)
			continue
		if name.ends_with(".json"):
			files.append(full_path)
	dir.list_dir_end()

func _parse_linear_scene(path: String, scene_id: StringName, raw_value: Variant) -> DialogueSequence:
	if raw_value is not Dictionary:
		_add_error(path, "Scene '%s' must be a Dictionary." % String(scene_id))
		return null

	var source: Dictionary = raw_value
	var raw_lines: Variant = source.get("lines", [])
	if raw_lines is not Array or raw_lines.is_empty():
		_add_error(path, "Scene '%s' must define a non-empty 'lines' Array." % String(scene_id))
		return null
	var raw_lines_array: Array = raw_lines

	var sequence := DialogueSequence.new()
	sequence.id = scene_id
	sequence.player_speaker_id = StringName(source.get("player_speaker_id", &""))
	sequence.npc_speaker_id = StringName(source.get("npc_speaker_id", &""))
	sequence.player_portrait = source.get("player_portrait", null)
	sequence.npc_portrait = source.get("npc_portrait", null)

	var line_index: int = 0
	var previous_node_id: StringName = &""
	for raw_line: Variant in raw_lines_array:
		if raw_line is not Dictionary:
			_add_error(path, "Scene '%s' line[%d] must be a Dictionary." % [String(scene_id), line_index])
			line_index += 1
			continue
		var line_dict: Dictionary = raw_line
		var node_id := StringName("line_%d" % [line_index + 1])
		var node := DialogueNode.new()
		node.id = node_id
		node.node_type = &"line"
		node.speaker_id = StringName(line_dict.get("speaker_id", &""))
		node.speaker = String(line_dict.get("speaker", ""))
		node.side = String(line_dict.get("side", ""))
		node.text = String(line_dict.get("text", ""))
		node.text_key = StringName(line_dict.get("text_key", &""))
		node.player_speaker_id = StringName(line_dict.get("player_speaker_id", &""))
		node.npc_speaker_id = StringName(line_dict.get("npc_speaker_id", &""))
		node.player_portrait = line_dict.get("player_portrait", null)
		node.npc_portrait = line_dict.get("npc_portrait", null)

		if node.speaker_id == &"":
			_add_error(path, "Scene '%s' line[%d] is missing 'speaker_id'." % [String(scene_id), line_index])
		if node.text == "" and node.text_key == &"":
			_add_error(path, "Scene '%s' line[%d] must define either 'text' or 'text_key'." % [String(scene_id), line_index])

		sequence.nodes[node_id] = node
		if line_index == 0:
			sequence.start_node_id = node_id
		if previous_node_id != &"" and sequence.nodes.has(previous_node_id):
			var previous_node: DialogueNode = sequence.nodes[previous_node_id]
			previous_node.next_node_id = node_id
		previous_node_id = node_id
		line_index += 1

	if sequence.start_node_id == &"":
		_add_error(path, "Scene '%s' has no valid lines to build nodes." % String(scene_id))
		return null

	var end_action := StringName(source.get("end_action", &""))
	if end_action != &"":
		var event_node := DialogueNode.new()
		event_node.id = &"scene_event"
		event_node.node_type = &"event"
		event_node.action = end_action
		event_node.enemy_id = StringName(source.get("enemy_id", &""))
		sequence.nodes[event_node.id] = event_node
		if previous_node_id != &"" and sequence.nodes.has(previous_node_id):
			var last_line: DialogueNode = sequence.nodes[previous_node_id]
			last_line.next_node_id = event_node.id
	else:
		var end_node := DialogueNode.new()
		end_node.id = &"scene_end"
		end_node.node_type = &"end"
		sequence.nodes[end_node.id] = end_node
		if previous_node_id != &"" and sequence.nodes.has(previous_node_id):
			var final_line: DialogueNode = sequence.nodes[previous_node_id]
			final_line.next_node_id = end_node.id

	return sequence

func load_speakers(path: String = "%s/speakers.json" % DIALOGUE_DIR) -> Dictionary:
	var parsed := _load_json(path)
	if parsed.is_empty():
		return {}
	return _string_name_keyed_dictionary(parsed.get("speakers", {}))

func load_localization(path: String = "%s/localization/en.json" % DIALOGUE_DIR) -> Dictionary:
	var parsed := _load_json(path)
	if parsed.is_empty():
		return {}
	return _string_name_keyed_dictionary(parsed.get("entries", {}))

func get_validation_errors() -> PackedStringArray:
	return _validation_errors.duplicate()

func _parse_dialogue_sequence(path: String, dialogue_id: StringName, raw_value: Variant) -> DialogueSequence:
	if raw_value is not Dictionary:
		_add_error(path, "Dialogue '%s' must be a Dictionary." % String(dialogue_id))
		return null

	var source: Dictionary = raw_value
	var sequence := DialogueSequence.new()
	sequence.id = dialogue_id
	sequence.start_node_id = StringName(source.get("start", &""))
	sequence.player_speaker_id = StringName(source.get("player_speaker_id", &""))
	sequence.npc_speaker_id = StringName(source.get("npc_speaker_id", &""))
	sequence.player_portrait = source.get("player_portrait", null)
	sequence.npc_portrait = source.get("npc_portrait", null)

	if sequence.start_node_id == &"":
		_add_error(path, "Dialogue '%s' is missing a valid 'start' node id." % String(dialogue_id))

	var raw_nodes: Variant = source.get("nodes", {})
	if raw_nodes is not Dictionary:
		_add_error(path, "Dialogue '%s' has invalid 'nodes' (expected Dictionary)." % String(dialogue_id))
		return sequence
	var raw_nodes_dict: Dictionary = raw_nodes

	for node_id_variant: Variant in raw_nodes_dict.keys():
		var node_id := StringName(node_id_variant)
		var node := _parse_dialogue_node(path, dialogue_id, node_id, raw_nodes_dict[node_id_variant])
		if node != null:
			sequence.nodes[node_id] = node

	if sequence.start_node_id != &"" and not sequence.nodes.has(sequence.start_node_id):
		_add_error(path, "Dialogue '%s' start node '%s' does not exist in node graph." % [String(dialogue_id), String(sequence.start_node_id)])

	return sequence

func _parse_dialogue_node(path: String, dialogue_id: StringName, node_id: StringName, raw_value: Variant) -> DialogueNode:
	if raw_value is not Dictionary:
		_add_error(path, "Dialogue '%s' node '%s' must be a Dictionary." % [String(dialogue_id), String(node_id)])
		return null

	var source: Dictionary = raw_value
	var node := DialogueNode.new()
	node.id = node_id
	node.node_type = StringName(source.get("type", "line"))
	node.next_node_id = StringName(source.get("next", &""))
	node.speaker_id = StringName(source.get("speaker_id", &""))
	node.speaker = String(source.get("speaker", ""))
	node.side = String(source.get("side", ""))
	node.text = String(source.get("text", ""))
	node.text_key = StringName(source.get("text_key", &""))
	node.player_speaker_id = StringName(source.get("player_speaker_id", &""))
	node.npc_speaker_id = StringName(source.get("npc_speaker_id", &""))
	node.player_portrait = source.get("player_portrait", null)
	node.npc_portrait = source.get("npc_portrait", null)
	node.true_next_node_id = StringName(source.get("true_next", &""))
	node.false_next_node_id = StringName(source.get("false_next", &""))
	node.action = StringName(source.get("action", &""))
	node.event_flags = _parse_bool_flag_dictionary(source.get("flags", {}))
	node.enemy_id = StringName(source.get("enemy_id", &""))
	node.target_node_id = StringName(source.get("target", &""))
	node.condition = _parse_condition(path, dialogue_id, node_id, source.get("check", null))
	node.choices = _parse_choices(path, dialogue_id, node_id, source.get("choices", []))

	_validate_node_shape(path, dialogue_id, node)
	return node

func _parse_choices(path: String, dialogue_id: StringName, node_id: StringName, raw_choices: Variant) -> Array[DialogueChoice]:
	var choices: Array[DialogueChoice] = []
	if raw_choices == null:
		return choices
	if raw_choices is not Array:
		_add_error(path, "Dialogue '%s' node '%s' choices must be an Array." % [String(dialogue_id), String(node_id)])
		return choices

	for i: int in range(raw_choices.size()):
		var raw_choice: Variant = raw_choices[i]
		if raw_choice is not Dictionary:
			_add_error(path, "Dialogue '%s' node '%s' choice[%d] must be a Dictionary." % [String(dialogue_id), String(node_id), i])
			continue

		var source: Dictionary = raw_choice
		var choice := DialogueChoice.new()
		choice.text = String(source.get("text", ""))
		choice.text_key = StringName(source.get("text_key", &""))
		choice.next_node_id = StringName(source.get("next", &""))
		choice.set_flags = _parse_bool_flag_dictionary(source.get("set_flags", {}))
		if choice.next_node_id == &"":
			_add_error(path, "Dialogue '%s' node '%s' choice[%d] must define 'next'." % [String(dialogue_id), String(node_id), i])
		choices.append(choice)
	return choices

func _parse_condition(path: String, dialogue_id: StringName, node_id: StringName, raw_condition: Variant) -> DialogueCondition:
	if raw_condition == null:
		return null
	if raw_condition is not Dictionary:
		_add_error(path, "Dialogue '%s' node '%s' check must be a Dictionary." % [String(dialogue_id), String(node_id)])
		return null

	var source: Dictionary = raw_condition
	var condition := DialogueCondition.new()
	if source.has("all"):
		condition.operator = &"all"
		condition.children = _parse_condition_children(path, dialogue_id, node_id, "all", source["all"])
		return condition
	if source.has("any"):
		condition.operator = &"any"
		condition.children = _parse_condition_children(path, dialogue_id, node_id, "any", source["any"])
		return condition
	if source.has("not"):
		condition.operator = &"not"
		var child := _parse_condition(path, dialogue_id, node_id, source["not"])
		if child != null:
			condition.children.append(child)
		else:
			_add_error(path, "Dialogue '%s' node '%s' has invalid 'not' check." % [String(dialogue_id), String(node_id)])
		return condition

	condition.operator = &"kind"
	condition.kind = StringName(source.get("kind", &""))
	condition.id = StringName(source.get("id", &""))
	if condition.kind == &"":
		_add_error(path, "Dialogue '%s' node '%s' condition is missing 'kind'." % [String(dialogue_id), String(node_id)])
	var kinds_without_id := {
		&"prior_victory_current_enemy": true,
	}
	if condition.id == &"" and not kinds_without_id.has(condition.kind):
		_add_error(path, "Dialogue '%s' node '%s' condition is missing 'id'." % [String(dialogue_id), String(node_id)])
	return condition

func _parse_condition_children(path: String, dialogue_id: StringName, node_id: StringName, key: String, raw_children: Variant) -> Array[DialogueCondition]:
	var children: Array[DialogueCondition] = []
	if raw_children is not Array:
		_add_error(path, "Dialogue '%s' node '%s' condition '%s' must be an Array." % [String(dialogue_id), String(node_id), key])
		return children
	for raw_child: Variant in raw_children:
		var child := _parse_condition(path, dialogue_id, node_id, raw_child)
		if child != null:
			children.append(child)
	return children

func _parse_bool_flag_dictionary(raw_flags: Variant) -> Dictionary:
	if raw_flags is not Dictionary:
		return {}
	var flags: Dictionary = {}
	for key: Variant in raw_flags.keys():
		flags[StringName(key)] = bool(raw_flags[key])
	return flags

func _validate_node_shape(path: String, dialogue_id: StringName, node: DialogueNode) -> void:
	match String(node.node_type):
		"line":
			if node.next_node_id == &"":
				_add_error(path, "Dialogue '%s' line node '%s' must define 'next'." % [String(dialogue_id), String(node.id)])
		"choice":
			if node.choices.is_empty():
				_add_error(path, "Dialogue '%s' choice node '%s' has no valid choices." % [String(dialogue_id), String(node.id)])
		"condition":
			if node.condition == null:
				_add_error(path, "Dialogue '%s' condition node '%s' is missing 'check'." % [String(dialogue_id), String(node.id)])
			if node.true_next_node_id == &"" or node.false_next_node_id == &"":
				_add_error(path, "Dialogue '%s' condition node '%s' must define both true_next and false_next." % [String(dialogue_id), String(node.id)])
		"event":
			if node.action == &"":
				_add_error(path, "Dialogue '%s' event node '%s' is missing 'action'." % [String(dialogue_id), String(node.id)])
		"jump":
			if node.target_node_id == &"":
				_add_error(path, "Dialogue '%s' jump node '%s' is missing 'target'." % [String(dialogue_id), String(node.id)])
		"end":
			pass
		_:
			_add_error(path, "Dialogue '%s' node '%s' has unknown type '%s'." % [String(dialogue_id), String(node.id), String(node.node_type)])

func _load_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		push_warning("Dialogue content file missing: %s" % path)
		return {}

	var raw_text := FileAccess.get_file_as_string(path)
	if raw_text == "":
		push_warning("Dialogue content file is empty: %s" % path)
		return {}

	var json := JSON.new()
	var parse_error := json.parse(raw_text)
	if parse_error != OK:
		push_warning("Failed to parse %s: %s" % [path, json.get_error_message()])
		return {}

	if json.data is Dictionary:
		return json.data
	push_warning("Dialogue content root must be a Dictionary: %s" % path)
	return {}

func _string_name_keyed_dictionary(source: Variant) -> Dictionary:
	if source is not Dictionary:
		return {}
	var source_dict: Dictionary = source
	var output: Dictionary = {}
	for key: Variant in source_dict.keys():
		output[StringName(key)] = source_dict[key]
	return output

func _add_error(path: String, message: String) -> void:
	var formatted := "%s: %s" % [path, message]
	_validation_errors.append(formatted)
	push_warning(formatted)
