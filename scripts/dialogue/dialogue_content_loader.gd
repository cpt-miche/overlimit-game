extends RefCounted

const DIALOGUE_DIR := "res://resources/dialogue"

func load_dialogues(path: String = "%s/dialogues.json" % DIALOGUE_DIR) -> Dictionary:
	var parsed := _load_json(path)
	if parsed.is_empty():
		return {}
	return _string_name_keyed_dictionary(parsed.get("dialogues", {}))

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
