extends Area2D

@export var enemy_id: StringName = &"raditz_scout"
@export var display_name: String = "Enemy"
@export var trigger_dialogue: bool = false
@export var dialogue_key: StringName = &""

@onready var name_label: Label = $NameLabel

signal player_interacted(enemy_id: StringName, trigger_dialogue: bool, dialogue_key: StringName, display_name: String)

func _ready() -> void:
	name_label.text = display_name
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		set_meta("player_in_range", true)

func _on_body_exited(body: Node) -> void:
	if body.is_in_group("player"):
		set_meta("player_in_range", false)

func _unhandled_input(event: InputEvent) -> void:
	if not get_meta("player_in_range", false):
		return
	if event.is_action_pressed("interact"):
		emit_signal("player_interacted", enemy_id, trigger_dialogue, dialogue_key, display_name)
