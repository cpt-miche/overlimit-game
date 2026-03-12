extends Node

const ENRAGE_STRENGTH_SPEED_MULT := 1.30
const ENRAGE_EXHAUSTED_MULT := 0.90
const ENRAGE_TURNS := 3
const EXHAUSTED_TURNS := 2
const ENRAGE_STAMINA_DRAIN_PCT := 0.10

signal battle_finished(result: String)

@export var player_base: FighterStats
@export var enemy_base: FighterStats

@export var attack_pool: Array[AttackDef] = []
@export var transformation_pool: Array[TransformationDef] = []

@onready var ui = $"../BattleUI"

var state := BattleState.new()
var resolver := CombatResolver.new()
var enemy_ai := EnemyAI.new()
var rng := RandomNumberGenerator.new()
var infusion_ratio: float = 0.0

var attacks: Dictionary = {}
var transformations: Dictionary = {}
var pending_result: String = ""
var player_used_primary_action: bool = false
var player_used_secondary_action: bool = false

func _ready() -> void:
	rng.randomize()
	_initialize_skill_pools()
	ui.action_pressed.connect(_on_action_pressed)
	ui.infusion_changed.connect(func(v: float) -> void: infusion_ratio = v)
	ui.debug_mode_toggled.connect(_on_debug_mode_toggled)
	ui.exit_requested.connect(_on_exit_requested)
	if not ui.is_node_ready():
		await ui.ready
	start_battle(enemy_base)

func start_battle(enemy: FighterStats) -> void:
	enemy_base = enemy
	state.setup(player_base, enemy_base)
	_apply_form_scaling(state.player, true)
	_apply_form_scaling(state.enemy, true)
	pending_result = ""
	player_used_primary_action = false
	player_used_secondary_action = false
	ui.clear_log()
	ui.set_battle_active(true)
	ui.set_exit_message("Exit battle")
	_refresh_view()

func _initialize_skill_pools() -> void:
	attacks.clear()
	for attack in attack_pool:
		if attack and attack.id != &"":
			attacks[attack.id] = attack

	transformations.clear()
	for trans in transformation_pool:
		if trans and trans.id != &"":
			transformations[trans.id] = trans

func get_player_stat_lines() -> PackedStringArray:
	return _fighter_stat_lines(state.player)

func _on_action_pressed(action_id: StringName) -> void:
	if state.is_finished():
		return
	if not _can_use_player_action(action_id):
		_refresh_view()
		return

	var action_consumed := _match_player_action(action_id)
	if not action_consumed:
		_refresh_view()
		return
	_mark_player_action_used(action_id)
	if _check_end():
		return
	if not _has_player_completed_turn_actions():
		_refresh_view()
		return

	_resolve_enemy_turn()
	_apply_end_round()
	player_used_primary_action = false
	player_used_secondary_action = false
	_check_end()
	_refresh_view()

func _can_use_player_action(action_id: StringName) -> bool:
	var action_type := _get_action_type(action_id)
	if action_type == "primary" and player_used_primary_action:
		_log("Primary action already used this turn.")
		return false
	if action_type == "secondary" and player_used_secondary_action:
		_log("Secondary action already used this turn.")
		return false
	return true

func _mark_player_action_used(action_id: StringName) -> void:
	var action_type := _get_action_type(action_id)
	if action_type == "primary":
		player_used_primary_action = true
	else:
		player_used_secondary_action = true

func _has_player_completed_turn_actions() -> bool:
	return player_used_primary_action and player_used_secondary_action

func _get_action_type(action_id: StringName) -> String:
	if action_id == &"power_up" or action_id == &"transform_form" or action_id == &"shuten_gate_1" or action_id == &"shuten_gate_2" or action_id == &"shuten_gate_3" or action_id == &"enrage":
		return "secondary"
	return "primary"

func _match_player_action(action_id: StringName) -> bool:
	return _process_action(state.player, state.enemy, action_id, infusion_ratio)

func _resolve_enemy_turn() -> void:
	var enemy_primary_action := _choose_enemy_action_for_slot("primary", 0.25)
	if enemy_primary_action != &"":
		_process_action(state.enemy, state.player, enemy_primary_action, 0.25)
	else:
		_log("%s cannot find a usable primary action." % state.enemy.fighter_name)

	var enemy_secondary_action := _choose_enemy_action_for_slot("secondary", 0.25)
	if enemy_secondary_action != &"":
		_process_action(state.enemy, state.player, enemy_secondary_action, 0.25)
	else:
		_log("%s cannot find a usable secondary action." % state.enemy.fighter_name)

func _choose_enemy_action_for_slot(action_type: String, enemy_infusion: float) -> StringName:
	var ai_choice := enemy_ai.choose_action(state.enemy, attacks, transformations, enemy_infusion)
	if _get_action_type(ai_choice) == action_type and _can_enemy_use_action(ai_choice, enemy_infusion):
		return ai_choice

	if action_type == "primary":
		var primary_candidates: Array[StringName] = [&"strike", &"ki_blast", &"double_sunday", &"ki_volley", &"ki_barrage"]
		for candidate in primary_candidates:
			if _can_enemy_use_action(candidate, enemy_infusion):
				return candidate
		return &""

	var secondary_candidates: Array[StringName] = [&"transform_form", &"shuten_gate_1", &"enrage", &"power_up"]
	for candidate in secondary_candidates:
		if _can_enemy_use_action(candidate, enemy_infusion):
			return candidate
	return &""

func _can_enemy_use_action(action_id: StringName, action_infusion: float) -> bool:
	if _get_action_type(action_id) == "primary":
		if not attacks.has(action_id) or not state.enemy.has_attack_skill(action_id):
			return false
		var selected_attack: AttackDef = attacks[action_id]
		if not _can_use_attack_with_active_buffs(state.enemy, selected_attack):
			return false
		var infusion_cost := int(round(float(state.enemy.max_drawn_ki) * action_infusion * selected_attack.infusion_cap))
		return state.enemy.stamina >= selected_attack.stamina_cost and state.enemy.drawn_ki >= (selected_attack.ki_cost + infusion_cost)

	if action_id == &"power_up":
		if not state.enemy.has_utility_skill(&"power_up"):
			return false
		return mini(45, mini(state.enemy.stored_ki, state.enemy.max_drawn_ki - state.enemy.drawn_ki)) > 0
	if action_id == &"transform_form":
		if not state.enemy.has_utility_skill(&"transform_form"):
			return false
		var next_form := _get_next_form_transformation(state.enemy)
		return next_form != null and next_form.can_activate(state.enemy)
	if action_id == &"enrage":
		if not state.enemy.has_utility_skill(&"enrage"):
			return false
		return state.enemy.enrage_turns_remaining <= 0 and state.enemy.exhausted_turns_remaining <= 0
	if action_id == &"shuten_gate_1":
		if not state.enemy.has_utility_skill(&"shuten") or not state.enemy.has_transformation_skill(&"shuten_gate_1"):
			return false
		if state.enemy.form_level > 0:
			return false
		var shuten: TransformationDef = transformations.get(&"shuten_gate_1", null)
		return shuten != null and shuten.can_activate(state.enemy)
	return false

func _process_action(actor: FighterStats, target: FighterStats, action_id: StringName, action_infusion: float) -> bool:
	match action_id:
		&"power_up":
			_power_up(actor)
			return true
		&"shuten_gate_1", &"shuten_gate_2", &"shuten_gate_3":
			return _activate_shuten_gate(actor, action_id)
		&"transform_form":
			_transform_higher_form(actor)
			return true
		&"enrage":
			_enrage(actor)
			return true
		_:
			if not attacks.has(action_id) or not actor.has_attack_skill(action_id):
				_log("%s cannot use %s." % [actor.fighter_name, String(action_id)])
				return true
			var selected_attack: AttackDef = attacks[action_id]
			if not _can_use_attack_with_active_buffs(actor, selected_attack):
				_log("%s cannot use %s without required transformation." % [actor.fighter_name, selected_attack.label])
				return true
			var active_boost := _get_active_shuten_transformation(actor)
			var attack_result := resolver.resolve_attack(actor, target, selected_attack, action_infusion, active_boost, rng)
			_log_attack_result(actor.fighter_name, selected_attack, attack_result)
			return attack_result.get("ok", false)

func _apply_end_round() -> void:
	state.turn += 1
	state.player.escalation += 3
	state.enemy.escalation += 3
	_apply_form_upkeep(state.player)
	_apply_form_upkeep(state.enemy)
	_apply_shuten_upkeep(state.player)
	_apply_shuten_upkeep(state.enemy)
	_apply_enrage_upkeep(state.player)
	_apply_enrage_upkeep(state.enemy)
	state.player.stamina = clampi(state.player.stamina + 10, 0, state.player.max_stamina)
	state.enemy.stamina = clampi(state.enemy.stamina + 10, 0, state.enemy.max_stamina)
	state.player.clamp_resources()
	state.enemy.clamp_resources()

func _power_up(fighter: FighterStats) -> void:
	if not fighter.has_utility_skill(&"power_up"):
		_log("%s cannot power up." % fighter.fighter_name)
		return
	var amount := mini(45, mini(fighter.stored_ki, fighter.max_drawn_ki - fighter.drawn_ki))
	if amount <= 0:
		_log("%s cannot draw more ki." % fighter.fighter_name)
		return
	fighter.stored_ki -= amount
	fighter.drawn_ki += amount
	fighter.escalation += 5
	_log("%s powers up (+%d drawn ki)." % [fighter.fighter_name, amount])


func _enrage(fighter: FighterStats) -> void:
	if not fighter.has_utility_skill(&"enrage"):
		_log("%s cannot use Enrage." % fighter.fighter_name)
		return
	if fighter.enrage_turns_remaining > 0:
		_log("%s is already enraged." % fighter.fighter_name)
		return
	if fighter.exhausted_turns_remaining > 0:
		_log("%s is too exhausted to enrage." % fighter.fighter_name)
		return
	fighter.enrage_turns_remaining = ENRAGE_TURNS
	_apply_form_scaling(fighter, false)
	_log("%s uses Enrage! +30%% strength/speed, -10%% accuracy for %d turns." % [fighter.fighter_name, ENRAGE_TURNS])

func _apply_enrage_upkeep(fighter: FighterStats) -> void:
	if fighter.enrage_turns_remaining > 0:
		var stamina_upkeep := int(round(float(fighter.max_stamina) * ENRAGE_STAMINA_DRAIN_PCT))
		fighter.stamina -= stamina_upkeep
		fighter.enrage_turns_remaining -= 1
		if stamina_upkeep > 0:
			_log("%s Enrage upkeep: -%d stamina." % [fighter.fighter_name, stamina_upkeep])
		if fighter.enrage_turns_remaining <= 0:
			fighter.exhausted_turns_remaining = EXHAUSTED_TURNS
			_log("%s's Enrage fades. Exhausted for %d turns." % [fighter.fighter_name, EXHAUSTED_TURNS])
			_apply_form_scaling(fighter, false)
	elif fighter.exhausted_turns_remaining > 0:
		fighter.exhausted_turns_remaining -= 1
		if fighter.exhausted_turns_remaining <= 0:
			_log("%s is no longer exhausted." % fighter.fighter_name)
			_apply_form_scaling(fighter, false)

func _transform_higher_form(fighter: FighterStats) -> void:
	if not fighter.has_utility_skill(&"transform_form"):
		_log("%s cannot transform." % fighter.fighter_name)
		return

	var transform := _get_next_form_transformation(fighter)
	if transform == null:
		_log("%s has no available transformations." % fighter.fighter_name)
		return
	if not transform.can_activate(fighter):
		_log("%s lacks activation requirements for %s." % [fighter.fighter_name, transform.label])
		return

	var previous_stamina := fighter.stamina
	var previous_max_stamina := fighter.max_stamina
	_deactivate_incompatible_transformations(fighter, transform)
	fighter.form_level = transform.form_level
	fighter.active_form_transformation_id = transform.id
	_apply_form_scaling(fighter, false)
	var stamina_multiplier := float(fighter.max_stamina) / maxf(1.0, float(previous_max_stamina))
	fighter.stamina = clampi(int(round(float(previous_stamina) * stamina_multiplier)), 0, fighter.max_stamina)
	fighter.highest_form_rewarded_this_rest = maxi(fighter.highest_form_rewarded_this_rest, fighter.form_level)
	_log("%s uses %s. Stamina %d/%d -> %d/%d." % [
		fighter.fighter_name,
		transform.label,
		previous_stamina,
		previous_max_stamina,
		fighter.stamina,
		fighter.max_stamina,
	])

func _deactivate_incompatible_transformations(fighter: FighterStats, transform: TransformationDef) -> void:
	if transform == null:
		return
	if fighter.active_shuten_transformation_id != &"" and transform.incompatible_transformation_ids.has(fighter.active_shuten_transformation_id):
		var cancelled := _get_active_shuten_transformation(fighter)
		fighter.active_shuten_transformation_id = &""
		_apply_form_scaling(fighter, false)
		_log("%s's %s is cancelled by %s." % [fighter.fighter_name, cancelled.label if cancelled else "Shuten", transform.label])

func _activate_shuten_gate(fighter: FighterStats, gate_id: StringName) -> bool:
	if not fighter.has_utility_skill(&"shuten") or not fighter.has_transformation_skill(gate_id):
		_log("%s cannot use %s." % [fighter.fighter_name, String(gate_id)])
		return true
	if fighter.form_level > 0:
		_log("%s can only use Shuten in base form." % fighter.fighter_name)
		return true
	if fighter.active_shuten_transformation_id == gate_id:
		var active := _get_active_shuten_transformation(fighter)
		fighter.active_shuten_transformation_id = &""
		_apply_form_scaling(fighter, false)
		_log("%s deactivates %s." % [fighter.fighter_name, active.label if active else String(gate_id)])
		return true
	var shuten: TransformationDef = transformations.get(gate_id, null)
	if shuten == null:
		_log("%s transformation is not configured." % String(gate_id))
		return true
	if not shuten.can_activate(fighter):
		_log("%s lacks activation requirements for %s." % [fighter.fighter_name, shuten.label])
		return true
	fighter.active_shuten_transformation_id = gate_id
	_apply_form_scaling(fighter, false)
	fighter.escalation += 12
	_log("%s activates %s!" % [fighter.fighter_name, shuten.label])
	return true

func _apply_shuten_upkeep(fighter: FighterStats) -> void:
	var shuten := _get_active_shuten_transformation(fighter)
	if shuten == null:
		return
	var hp_upkeep := int(round(float(fighter.max_hp) * shuten.hp_upkeep_pct))
	var stamina_upkeep := int(round(float(fighter.max_stamina) * shuten.stamina_upkeep_pct))
	var drawn_ki_upkeep := int(round(float(fighter.max_drawn_ki) * shuten.drawn_ki_upkeep_pct))
	fighter.hp -= hp_upkeep
	fighter.stamina -= stamina_upkeep
	fighter.drawn_ki -= drawn_ki_upkeep
	if hp_upkeep > 0 or stamina_upkeep > 0 or drawn_ki_upkeep > 0:
		_log("%s %s upkeep: -%d HP, -%d stamina, -%d drawn ki." % [fighter.fighter_name, shuten.label, hp_upkeep, stamina_upkeep, drawn_ki_upkeep])

func _apply_form_upkeep(fighter: FighterStats) -> void:
	var active_form := _get_active_form_transformation(fighter)
	if active_form == null:
		return
	if active_form.stored_ki_upkeep_pct <= 0.0 and active_form.stored_to_drawn_pct <= 0.0:
		return

	var upkeep_amount := active_form.get_upkeep_amount(fighter.max_stored_ki, active_form.stored_ki_upkeep_pct, fighter.form_mastery_level)
	var conversion_amount := active_form.get_upkeep_amount(fighter.max_stored_ki, active_form.stored_to_drawn_pct, fighter.form_mastery_level)
	upkeep_amount = mini(upkeep_amount, fighter.stored_ki)
	fighter.stored_ki -= upkeep_amount

	var convert_spend := mini(conversion_amount, fighter.stored_ki)
	fighter.stored_ki -= convert_spend
	var draw_gain := mini(convert_spend, fighter.max_drawn_ki - fighter.drawn_ki)
	fighter.drawn_ki += draw_gain

	if upkeep_amount > 0 or convert_spend > 0 or draw_gain > 0:
		_log("%s form upkeep drains %d stored ki and converts %d to drawn ki." % [fighter.fighter_name, upkeep_amount + convert_spend, draw_gain])

func _apply_form_scaling(fighter: FighterStats, preserve_stamina_ratio: bool) -> void:
	var stamina_ratio := float(fighter.stamina) / maxf(1.0, float(fighter.max_stamina))
	var active_form := _get_active_form_transformation(fighter)
	var shuten := _get_active_shuten_transformation(fighter)
	var physical_mult := 1.0
	var ki_mult := 1.0
	var speed_mult := 1.0
	var stamina_mult := 1.0
	if active_form:
		physical_mult = active_form.strength_multiplier
		ki_mult = active_form.strength_multiplier
		speed_mult = active_form.speed_multiplier
		stamina_mult = active_form.max_stamina_multiplier
	if shuten:
		physical_mult *= shuten.strength_multiplier
		ki_mult *= shuten.strength_multiplier
		speed_mult *= shuten.speed_multiplier
		stamina_mult *= shuten.max_stamina_multiplier
	if fighter.enrage_turns_remaining > 0:
		physical_mult *= ENRAGE_STRENGTH_SPEED_MULT
		ki_mult *= ENRAGE_STRENGTH_SPEED_MULT
		speed_mult *= ENRAGE_STRENGTH_SPEED_MULT
	elif fighter.exhausted_turns_remaining > 0:
		physical_mult *= ENRAGE_EXHAUSTED_MULT
		ki_mult *= ENRAGE_EXHAUSTED_MULT
		speed_mult *= ENRAGE_EXHAUSTED_MULT

	fighter.physical_strength = int(round(float(fighter.base_physical_strength) * physical_mult))
	fighter.ki_strength = int(round(float(fighter.base_ki_strength) * ki_mult))
	fighter.speed = int(round(float(fighter.base_speed) * speed_mult))
	fighter.max_stamina = int(round(float(fighter.base_max_stamina) * stamina_mult))
	if preserve_stamina_ratio:
		fighter.stamina = int(round(float(fighter.max_stamina) * clampf(stamina_ratio, 0.0, 1.0)))
	fighter.clamp_resources()

func _get_next_form_transformation(fighter: FighterStats) -> TransformationDef:
	var candidate: TransformationDef = null
	for id in fighter.transformation_skill_ids:
		var transform: TransformationDef = transformations.get(id, null)
		if transform == null or not transform.is_form_transformation:
			continue
		if transform.required_form_level != fighter.form_level:
			continue
		if transform.form_level <= fighter.form_level:
			continue
		if candidate == null or transform.form_level < candidate.form_level:
			candidate = transform
	return candidate

func _get_active_form_transformation(fighter: FighterStats) -> TransformationDef:
	if fighter.active_form_transformation_id == &"":
		return null
	return transformations.get(fighter.active_form_transformation_id, null)

func _get_active_shuten_transformation(fighter: FighterStats) -> TransformationDef:
	if fighter.active_shuten_transformation_id == &"":
		return null
	return transformations.get(fighter.active_shuten_transformation_id, null)

func _can_use_attack_with_active_buffs(fighter: FighterStats, attack: AttackDef) -> bool:
	if attack.required_transformation_id == &"":
		return true
	if attack.required_transformation_id.begins_with("shuten_gate_"):
		return fighter.active_shuten_transformation_id == attack.required_transformation_id
	return fighter.active_form_transformation_id == attack.required_transformation_id

func _log_attack_result(attacker_name: String, attack: AttackDef, result: Dictionary) -> void:
	if not result.get("ok", false):
		_log("%s failed %s (no resources)." % [attacker_name, attack.label])
		return
	match result.get("result", ""):
		"miss":
			_log("%s used %s but missed." % [attacker_name, attack.label])
		"vanished":
			_log("%s used %s but target vanished." % [attacker_name, attack.label])
		"hit":
			var damage := int(result.get("damage", 0))
			_log("%s used %s for %d dmg." % [attacker_name, attack.label, damage])
			var extra_strikes := int(result.get("extra_strikes", 0))
			if extra_strikes > 0:
				var strike_text := "strike" if extra_strikes == 1 else "two strikes"
				var extra_damage := int(result.get("extra_damage", 0))
				_log("%s is faster and gains an extra %s for %d damage" % [attacker_name, strike_text, extra_damage])

func _check_end() -> bool:
	if not state.is_finished():
		return false
	var result := state.winner()
	pending_result = result
	if result == "player":
		_log("%s defeated" % state.enemy.fighter_name)
		ui.set_exit_message("%s defeated - Exit battle" % state.enemy.fighter_name)
	elif result == "enemy":
		_log("%s defeated" % state.player.fighter_name)
		ui.set_exit_message("%s defeated - Exit battle" % state.player.fighter_name)
	else:
		_log("Battle result: %s" % result)
		ui.set_exit_message("Draw - Exit battle")
	ui.set_battle_active(false)
	_refresh_view()
	return true

func _on_exit_requested() -> void:
	if pending_result == "":
		return
	battle_finished.emit(pending_result)

func _log(line: String) -> void:
	ui.append_log(line)

func _refresh_view() -> void:
	var primary_status := "used" if player_used_primary_action else "ready"
	var secondary_status := "used" if player_used_secondary_action else "ready"
	$"../BattleUI/Margin/VBox/Status".text = "Turn %d | P:%s S:%s | Escalation P:%d E:%d" % [state.turn, primary_status, secondary_status, int(state.player.escalation), int(state.enemy.escalation)]
	$"../BattleUI/Margin/VBox/PlayerStats".text = _fighter_line(state.player)
	$"../BattleUI/Margin/VBox/EnemyStats".text = _fighter_line(state.enemy)
	_refresh_debug_overlay()

func _fighter_line(f: FighterStats) -> String:
	return "%s HP %d/%d | Stam %d/%d | StoredKi %d/%d | DrawnKi %d/%d | Form %d%s" % [
		f.fighter_name, f.hp, f.max_hp, f.stamina, f.max_stamina, f.stored_ki, f.max_stored_ki, f.drawn_ki, f.max_drawn_ki, f.form_level,
		" +%s" % String(f.active_shuten_transformation_id) if f.active_shuten_transformation_id != &"" else ""
	]

func _fighter_stat_lines(f: FighterStats) -> PackedStringArray:
	return PackedStringArray([
		"Name: %s" % f.fighter_name,
		"HP: %d / %d" % [f.hp, f.max_hp],
		"Stamina: %d / %d" % [f.stamina, f.max_stamina],
		"Stored Ki: %d / %d" % [f.stored_ki, f.max_stored_ki],
		"Drawn Ki: %d / %d" % [f.drawn_ki, f.max_drawn_ki],
		"Physical Strength: %d" % f.physical_strength,
		"Ki Strength: %d" % f.ki_strength,
		"Speed: %d" % f.speed,
		"Escalation: %d" % int(f.escalation),
		"Form Level: %d" % f.form_level,
		"Active Form Transform: %s" % String(f.active_form_transformation_id),
		"Base Form Override: %d" % f.base_form_override_level,
		"Form Mastery: %d" % f.form_mastery_level,
		"Shuten Active: %s" % ("Yes" if f.active_shuten_transformation_id != &"" else "No"),
		"Active Shuten Gate: %s" % String(f.active_shuten_transformation_id),
		"Enrage Turns: %d" % f.enrage_turns_remaining,
		"Exhausted Turns: %d" % f.exhausted_turns_remaining,
	])


func _on_debug_mode_toggled(enabled: bool) -> void:
	if enabled:
		_refresh_debug_overlay()

func _refresh_debug_overlay() -> void:
	if not ui.debug_mode_enabled:
		return
	var lines := PackedStringArray()
	lines.append("[b]Player Stats[/b]")
	for line in _fighter_debug_lines(state.player):
		lines.append(line)
	lines.append("")
	lines.append("[b]Enemy Stats[/b]")
	for line in _fighter_debug_lines(state.enemy):
		lines.append(line)
	ui.set_debug_stats(lines)

func _fighter_debug_lines(f: FighterStats) -> PackedStringArray:
	return PackedStringArray([
		"Name: %s" % f.fighter_name,
		"HP: %d / %d" % [f.hp, f.max_hp],
		"Stamina: %d / %d" % [f.stamina, f.max_stamina],
		"Stored Ki: %d / %d" % [f.stored_ki, f.max_stored_ki],
		"Drawn Ki: %d / %d" % [f.drawn_ki, f.max_drawn_ki],
		"Physical: %d (base %d)" % [f.physical_strength, f.base_physical_strength],
		"Ki: %d (base %d)" % [f.ki_strength, f.base_ki_strength],
		"Speed: %d (base %d)" % [f.speed, f.base_speed],
		"Form: %d | Active: %s | Shuten: %s" % [f.form_level, String(f.active_form_transformation_id), String(f.active_shuten_transformation_id)],
		"Enrage: %d turns | Exhausted: %d turns" % [f.enrage_turns_remaining, f.exhausted_turns_remaining],
		"Attack Skills: %s" % _join_skill_ids(f.attack_skill_ids),
		"Utility Skills: %s" % _join_skill_ids(f.utility_skill_ids),
		"Transformation Skills: %s" % _join_skill_ids(f.transformation_skill_ids),
	])


func _join_skill_ids(ids: PackedStringArray) -> String:
	var out: PackedStringArray = PackedStringArray()
	for id in ids:
		out.append(String(id))
	return ", ".join(out)
