class_name FighterStats
extends Resource

@export var fighter_name: String = "Fighter"

@export var max_hp: int = 450
@export var hp: int = 450

@export var max_stamina: int = 240
@export var stamina: int = 240

@export var max_stored_ki: int = 360
@export var stored_ki: int = 360

@export var max_drawn_ki: int = 240
@export var drawn_ki: int = 80

@export var physical_strength: int = 56
@export var ki_strength: int = 50
@export var speed: int = 46

@export var attack_skill_ids: PackedStringArray = PackedStringArray([&"strike", &"ki_blast", &"ki_volley", &"ki_barrage"])
@export var utility_skill_ids: PackedStringArray = PackedStringArray([&"power_up", &"transform_form", &"kaioken"])
@export var transformation_skill_ids: PackedStringArray = PackedStringArray([&"ss1", &"kaioken"])

@export_range(0, 5, 1) var base_form_override_level: int = 0
@export_range(0, 5, 1) var form_mastery_level: int = 0

var escalation: float = 0.0
var kaioken_active: bool = false
var form_level: int = 0
var highest_form_rewarded_this_rest: int = 0
var active_form_transformation_id: StringName = &""

var base_max_stamina: int = 0
var base_physical_strength: int = 0
var base_ki_strength: int = 0
var base_speed: int = 0

func duplicate_runtime() -> FighterStats:
	var copy := FighterStats.new()
	copy.fighter_name = fighter_name
	copy.max_hp = max_hp
	copy.hp = hp
	copy.max_stamina = max_stamina
	copy.stamina = stamina
	copy.max_stored_ki = max_stored_ki
	copy.stored_ki = stored_ki
	copy.max_drawn_ki = max_drawn_ki
	copy.drawn_ki = drawn_ki
	copy.physical_strength = physical_strength
	copy.ki_strength = ki_strength
	copy.speed = speed
	copy.attack_skill_ids = attack_skill_ids.duplicate()
	copy.utility_skill_ids = utility_skill_ids.duplicate()
	copy.transformation_skill_ids = transformation_skill_ids.duplicate()
	copy.base_form_override_level = base_form_override_level
	copy.form_mastery_level = form_mastery_level
	copy.form_level = base_form_override_level
	copy.highest_form_rewarded_this_rest = base_form_override_level
	copy.base_max_stamina = max_stamina
	copy.base_physical_strength = physical_strength
	copy.base_ki_strength = ki_strength
	copy.base_speed = speed
	return copy

func has_attack_skill(skill_id: StringName) -> bool:
	return attack_skill_ids.has(skill_id)

func has_utility_skill(skill_id: StringName) -> bool:
	return utility_skill_ids.has(skill_id)

func has_transformation_skill(skill_id: StringName) -> bool:
	return transformation_skill_ids.has(skill_id)

func clamp_resources() -> void:
	hp = clampi(hp, 0, max_hp)
	stamina = clampi(stamina, 0, max_stamina)
	stored_ki = clampi(stored_ki, 0, max_stored_ki)
	drawn_ki = clampi(drawn_ki, 0, max_drawn_ki)
