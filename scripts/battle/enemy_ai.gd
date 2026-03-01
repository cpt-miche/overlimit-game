class_name EnemyAI
extends RefCounted

func _can_use_attack(enemy: FighterStats, attack: AttackDef, infusion_ratio: float) -> bool:
	var infusion_cost := int(round(enemy.max_drawn_ki * infusion_ratio * attack.infusion_cap))
	if enemy.stamina < attack.stamina_cost or enemy.drawn_ki < (attack.ki_cost + infusion_cost):
		return false
	if attack.required_transformation_id == &"":
		return true
	if attack.required_transformation_id == &"kaioken":
		return enemy.kaioken_active
	return enemy.active_form_transformation_id == attack.required_transformation_id

func _has_attack(enemy: FighterStats, attack_id: StringName, attacks: Dictionary) -> bool:
	if not enemy.has_attack_skill(attack_id):
		return false
	return attacks.has(attack_id)

func _can_transform(enemy: FighterStats, transformations: Dictionary) -> bool:
	if not enemy.has_utility_skill(&"transform_form"):
		return false
	for id in enemy.transformation_skill_ids:
		var transform: TransformationDef = transformations.get(id, null)
		if transform == null or not transform.is_form_transformation:
			continue
		if transform.required_form_level == enemy.form_level and transform.can_activate(enemy):
			return true
	return false

func choose_action(enemy: FighterStats, attacks: Dictionary, transformations: Dictionary, infusion_ratio: float = 0.0) -> StringName:
	var low_ki := enemy.drawn_ki < 30
	var low_stamina := enemy.stamina < 25

	if low_ki and enemy.stored_ki > 20 and enemy.has_utility_skill(&"power_up"):
		return &"power_up"
	if low_stamina and enemy.has_utility_skill(&"guard"):
		return &"guard"
	if _can_transform(enemy, transformations):
		return &"transform_form"
	if enemy.form_level == 0 and not enemy.kaioken_active and enemy.hp < 220 and enemy.stamina > 60 and enemy.has_utility_skill(&"kaioken") and enemy.has_transformation_skill(&"kaioken"):
		return &"kaioken"

	var roll := randf()
	if roll < 0.35 and _has_attack(enemy, &"strike", attacks) and _can_use_attack(enemy, attacks[&"strike"], infusion_ratio):
		return &"strike"
	if roll < 0.72 and _has_attack(enemy, &"ki_blast", attacks) and _can_use_attack(enemy, attacks[&"ki_blast"], infusion_ratio):
		return &"ki_blast"
	if _has_attack(enemy, &"double_sunday", attacks) and _can_use_attack(enemy, attacks[&"double_sunday"], infusion_ratio):
		return &"double_sunday"
	if _has_attack(enemy, &"ki_volley", attacks) and _can_use_attack(enemy, attacks[&"ki_volley"], infusion_ratio):
		return &"ki_volley"
	if _has_attack(enemy, &"ki_barrage", attacks) and _can_use_attack(enemy, attacks[&"ki_barrage"], infusion_ratio):
		return &"ki_barrage"
	if _has_attack(enemy, &"strike", attacks) and _can_use_attack(enemy, attacks[&"strike"], infusion_ratio):
		return &"strike"
	if _has_attack(enemy, &"ki_blast", attacks) and _can_use_attack(enemy, attacks[&"ki_blast"], infusion_ratio):
		return &"ki_blast"
	if enemy.stored_ki > 0 and enemy.drawn_ki < enemy.max_drawn_ki and enemy.has_utility_skill(&"power_up"):
		return &"power_up"
	if enemy.has_utility_skill(&"guard"):
		return &"guard"
	return &"power_up"
