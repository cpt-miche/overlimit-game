extends RefCounted
class_name DialogueNode

var id: StringName = &""
var node_type: StringName = &"line"
var next_node_id: StringName = &""

var speaker_id: StringName = &""
var speaker: String = ""
var side: String = ""
var text: String = ""
var text_key: StringName = &""
var player_speaker_id: StringName = &""
var npc_speaker_id: StringName = &""
var player_portrait: Variant = null
var npc_portrait: Variant = null

var choices: Array[DialogueChoice] = []

var condition: DialogueCondition = null
var true_next_node_id: StringName = &""
var false_next_node_id: StringName = &""

var action: StringName = &""
var event_flags: Dictionary = {}
var enemy_id: StringName = &""

var target_node_id: StringName = &""
