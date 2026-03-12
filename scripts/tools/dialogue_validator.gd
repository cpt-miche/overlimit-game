extends SceneTree

const ROOT_DIR := "res://resources/dialogue"

var _errors: PackedStringArray = []

func _init() -> void:
	var speakers: Dictionary = {}
	var dialogues: Dictionary = {}
	var localization: Dictionary = {}

	_load_dialogue_directory(ROOT_DIR, speakers, dialogues, localization)
	_validate_speakers(speakers)
	_validate_dialogues(dialogues, speakers, localization)

	if _errors.is_empty():
		print("Dialogue validation passed (%d dialogues, %d speakers)." % [dialogues.size(), speakers.size()])
		quit(0)
		return

	for issue: String in _errors:
		push_error(issue)
	print("Dialogue validation failed with %d issue(s)." % _errors.size())
	quit(1)

func _load_dialogue_directory(path: String, speakers: Dictionary, dialogues: Dictionary, localization: Dictionary) -> void:
	var dir := DirAccess.open(path)
	if dir == null:
		_errors.append("Unable to open dialogue directory: %s" % path)
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
			_load_dialogue_directory(full_path, speakers, dialogues, localization)
			continue
		if not name.ends_with(".json"):
			continue
		_consume_json(full_path, speakers, dialogues, localization)
	dir.list_dir_end()

func _consume_json(path: String, speakers: Dictionary, dialogues: Dictionary, localization: Dictionary) -> void:
	var text := FileAccess.get_file_as_string(path)
	if text == "":
		_errors.append("JSON file is empty: %s" % path)
		return

	var json := JSON.new()
	if json.parse(text) != OK:
		_errors.append("Invalid JSON (%s): %s" % [path, json.get_error_message()])
		return
	if json.data is not Dictionary:
		_errors.append("JSON root must be an object: %s" % path)
		return

	var data: Dictionary = json.data
	if data.has("speakers"):
		_merge_named_map(path, "speakers", data["speakers"], speakers)
	if data.has("dialogues"):
		_merge_named_map(path, "dialogues", data["dialogues"], dialogues)
	if data.has("entries"):
		_merge_named_map(path, "entries", data["entries"], localization)

func _merge_named_map(path: String, label: String, source: Variant, target: Dictionary) -> void:
	if source is not Dictionary:
		_errors.append("%s.%s must be an object." % [path, label])
		return
	for key: Variant in source.keys():
		if target.has(key):
			_errors.append("Duplicate %s id '%s' across dialogue resources." % [label, String(key)])
		target[key] = source[key]

func _validate_speakers(speakers: Dictionary) -> void:
	for speaker_id: Variant in speakers.keys():
		var speaker: Variant = speakers[speaker_id]
		if speaker is not Dictionary:
			_errors.append("Speaker '%s' must be an object." % String(speaker_id))
			continue
		var speaker_dict: Dictionary = speaker
		if String(speaker_dict.get("display_name", "")).strip_edges() == "":
			_errors.append("Speaker '%s' is missing display_name." % String(speaker_id))
		var portrait_path := String(speaker_dict.get("default_portrait", ""))
		if portrait_path == "":
			_errors.append("Speaker '%s' is missing default_portrait." % String(speaker_id))
		elif not ResourceLoader.exists(portrait_path):
			_errors.append("Speaker '%s' portrait does not exist: %s" % [String(speaker_id), portrait_path])

func _validate_dialogues(dialogues: Dictionary, speakers: Dictionary, localization: Dictionary) -> void:
	for dialogue_id: Variant in dialogues.keys():
		var dialogue: Variant = dialogues[dialogue_id]
		if dialogue is not Dictionary:
			_errors.append("Dialogue '%s' must be an object." % String(dialogue_id))
			continue
		var dialogue_dict: Dictionary = dialogue
		var nodes: Dictionary = dialogue_dict.get("nodes", {})
		if nodes.is_empty():
			_errors.append("Dialogue '%s' has no nodes." % String(dialogue_id))
			continue
		var start_id := String(dialogue_dict.get("start", ""))
		if start_id == "" or not nodes.has(start_id):
			_errors.append("Dialogue '%s' has invalid start node '%s'." % [String(dialogue_id), start_id])
		_validate_speaker_ref("Dialogue '%s' player_speaker_id" % String(dialogue_id), dialogue_dict.get("player_speaker_id", ""), speakers)
		_validate_speaker_ref("Dialogue '%s' npc_speaker_id" % String(dialogue_id), dialogue_dict.get("npc_speaker_id", ""), speakers)
		_validate_optional_portrait("Dialogue '%s' player_portrait" % String(dialogue_id), dialogue_dict.get("player_portrait", ""))
		_validate_optional_portrait("Dialogue '%s' npc_portrait" % String(dialogue_id), dialogue_dict.get("npc_portrait", ""))
		_validate_nodes(String(dialogue_id), nodes, speakers, localization)

func _validate_nodes(dialogue_id: String, nodes: Dictionary, speakers: Dictionary, localization: Dictionary) -> void:
	for node_id: Variant in nodes.keys():
		var node: Variant = nodes[node_id]
		if node is not Dictionary:
			_errors.append("Dialogue '%s' node '%s' must be an object." % [dialogue_id, String(node_id)])
			continue
		var node_dict: Dictionary = node
		var node_type := String(node_dict.get("type", "line"))
		match node_type:
			"line":
				_validate_speaker_ref("Dialogue '%s' node '%s'" % [dialogue_id, String(node_id)], node_dict.get("speaker_id", ""), speakers)
				_validate_text_key("Dialogue '%s' node '%s'" % [dialogue_id, String(node_id)], node_dict, localization)
				_validate_node_link(dialogue_id, String(node_id), "next", node_dict.get("next", ""), nodes)
				_validate_optional_portrait("Dialogue '%s' node '%s' player_portrait" % [dialogue_id, String(node_id)], node_dict.get("player_portrait", ""))
				_validate_optional_portrait("Dialogue '%s' node '%s' npc_portrait" % [dialogue_id, String(node_id)], node_dict.get("npc_portrait", ""))
			"choice":
				var choices: Variant = node_dict.get("choices", [])
				if choices is not Array or (choices as Array).is_empty():
					_errors.append("Dialogue '%s' node '%s' choice list is empty." % [dialogue_id, String(node_id)])
				else:
					for idx: int in range(choices.size()):
						var choice: Variant = choices[idx]
						if choice is not Dictionary:
							_errors.append("Dialogue '%s' node '%s' choice #%d must be an object." % [dialogue_id, String(node_id), idx])
							continue
						var choice_dict: Dictionary = choice
						_validate_text_key("Dialogue '%s' node '%s' choice #%d" % [dialogue_id, String(node_id), idx], choice_dict, localization)
						_validate_node_link(dialogue_id, String(node_id), "choice.next", choice_dict.get("next", ""), nodes)
			"condition":
				_validate_node_link(dialogue_id, String(node_id), "true_next", node_dict.get("true_next", ""), nodes)
				_validate_node_link(dialogue_id, String(node_id), "false_next", node_dict.get("false_next", ""), nodes)
			"jump":
				_validate_node_link(dialogue_id, String(node_id), "target", node_dict.get("target", ""), nodes)
			"event":
				if node_dict.has("next"):
					_validate_node_link(dialogue_id, String(node_id), "next", node_dict.get("next", ""), nodes)
			"end":
				pass
			_:
				_errors.append("Dialogue '%s' node '%s' has unsupported type '%s'." % [dialogue_id, String(node_id), node_type])

func _validate_node_link(dialogue_id: String, node_id: String, key: String, target: Variant, nodes: Dictionary) -> void:
	var target_id := String(target)
	if target_id == "":
		_errors.append("Dialogue '%s' node '%s' has empty '%s'." % [dialogue_id, node_id, key])
		return
	if not nodes.has(target_id):
		_errors.append("Dialogue '%s' node '%s' points to missing node '%s' via '%s'." % [dialogue_id, node_id, target_id, key])

func _validate_speaker_ref(context: String, speaker_id: Variant, speakers: Dictionary) -> void:
	var id := String(speaker_id)
	if id == "":
		_errors.append("%s is missing speaker_id." % context)
		return
	if not speakers.has(id):
		_errors.append("%s references unknown speaker '%s'." % [context, id])

func _validate_text_key(context: String, item: Dictionary, localization: Dictionary) -> void:
	var text_key := String(item.get("text_key", ""))
	if text_key == "":
		_errors.append("%s is missing text_key." % context)
		return
	if not localization.has(text_key):
		_errors.append("%s uses unknown text_key '%s'." % [context, text_key])

func _validate_optional_portrait(context: String, portrait: Variant) -> void:
	if portrait is not String:
		return
	var path := String(portrait)
	if path == "":
		return
	if not ResourceLoader.exists(path):
		_errors.append("%s portrait does not exist: %s" % [context, path])
