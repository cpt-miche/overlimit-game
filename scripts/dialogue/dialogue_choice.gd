extends RefCounted
class_name DialogueChoice

var text: String = "..."
var text_key: StringName = &""
var next_node_id: StringName = &""
var set_flags: Dictionary = {}

func clone() -> DialogueChoice:
	var duplicate := DialogueChoice.new()
	duplicate.text = text
	duplicate.text_key = text_key
	duplicate.next_node_id = next_node_id
	duplicate.set_flags = set_flags.duplicate(true)
	return duplicate
