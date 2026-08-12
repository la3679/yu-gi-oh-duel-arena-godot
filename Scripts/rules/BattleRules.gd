class_name BattleRules
extends RefCounted

## Battle Phase, attack declaration, attack replay and the Damage Step.
## RULES_SPEC.md 6 and 7, master prompt 32/33/34.
##
## The Damage Step is a five sub-step sequence, not a single comparison [S3]:
##
##   1 START_OF_DAMAGE_STEP     effects that activate "at the start of the Damage Step"
##   2 BEFORE_DAMAGE_CALCULATION an attacked face-down monster is flipped face-up;
##                              ATK/DEF-changing effects may still activate; Flip
##                              effects do NOT activate yet
##   3 DURING_DAMAGE_CALCULATION ATK/DEF comparison and battle damage; destruction is
##                              DETERMINED here but nothing is sent to the GY yet
##   4 AFTER_DAMAGE_CALCULATION  battle triggers, and the Flip effects of monsters
##                              flipped face-up in sub-step 2
##   5 END_OF_DAMAGE_STEP        monsters destroyed by battle are SENT to the GY, and
##                              "destroyed by battle and sent to the GY" triggers fire
##
## Which effects may be activated inside the Damage Step is enforced by
## ActivationRules.damage_step_ok(), from the rule printed at [S1 p.41].
##
## DuelEngine owns the pacing: it opens a real response window between sub-steps, so a
## timing window is never skipped.

enum Stage {
	NONE,
	## The attack has been declared; the response window before the Damage Step is open.
	AFTER_DECLARATION,
	DS_START,
	DS_BEFORE,
	DS_DURING,
	DS_AFTER,
	DS_END,
}

var state: GameState = null

var stage: Stage = Stage.NONE

## Monsters whose destruction was determined during damage calculation. They stay on the
## field until the end of the Damage Step [S3].
var pending_destroyed: Array = []
## Monsters flipped face-up in sub-step 2, whose Flip effects belong to sub-step 4.
var flipped_before_damage: Array = []
## The opponent's monsters when the attack was declared, for replay detection [S1 p.39].
var opponent_monsters_at_declaration: Array = []
## After a replay this monster may declare an attack again without it counting twice.
var replay_attacker_id: int = -1

var last_damage: Dictionary = {}


func _init(p_state: GameState) -> void:
	state = p_state


# ---------------------------------------------------------------------------
# Attack legality. RULES_SPEC.md 6.1 [S1 p.38]
# ---------------------------------------------------------------------------

func can_declare_attack(card: CardInstance, pid: int) -> bool:
	if state.is_duel_over():
		return false
	if card == null or not card.is_monster():
		return false
	if state.phase != Enums.Phase.BATTLE or state.battle_step != Enums.BattleStep.BATTLE:
		return false
	if state.turn_player_id != pid or card.controller_id != pid:
		return false
	if card.zone != Enums.Zone.MONSTER_ZONE:
		return false
	# Only a face-up Attack Position monster may attack.
	if card.position != Enums.Position.FACE_UP_ATTACK:
		return false
	# One attack per turn by default. A monster that got a Replay may re-declare.
	if card.has_attacked_this_turn and card.id != replay_attacker_id:
		return false
	if bool(card.flags.get("cannot_attack", false)):
		return false
	return true


## Legal attack targets: the opponent's monsters, face-up or face-down.
func attack_targets(pid: int) -> Array:
	return state.opponent_of(pid).monsters()


## "If there are no monsters on your opponent's side of the field, you can attack
## directly." [S1 p.38, p.43]
func can_attack_directly(pid: int) -> bool:
	return attack_targets(pid).is_empty()


# ---------------------------------------------------------------------------
# Declaration
# ---------------------------------------------------------------------------

## `target` is null for a direct attack. Returns false when the declaration is illegal.
func declare_attack(attacker: CardInstance, target, pid: int) -> bool:
	if not can_declare_attack(attacker, pid):
		return false
	var direct := target == null
	if direct:
		if not can_attack_directly(pid):
			return false
	elif not attack_targets(pid).has(target):
		return false

	# Declaring with a different monster after a Replay spends the original monster's
	# attack: "the original monster is still treated as having declared an attack and
	# cannot attack again this turn." [S1 p.39]
	if replay_attacker_id != -1 and attacker.id != replay_attacker_id:
		var previous = state.instance(replay_attacker_id)
		if previous != null:
			previous.has_attacked_this_turn = true
	replay_attacker_id = -1

	state.current_attacker = attacker
	state.current_attack_target = target
	state.attack_is_direct = direct
	attacker.has_attacked_this_turn = true
	attacker.attacks_declared_this_turn += 1

	opponent_monsters_at_declaration = attack_targets(pid).map(func(c): return c.id)
	stage = Stage.AFTER_DECLARATION
	pending_destroyed = []
	flipped_before_damage = []
	last_damage = {}

	state.emit(GameEvent.Kind.ATTACK_DECLARED, {
		"attacker_id": attacker.id, "attacker_name": attacker.card_name(),
		"player": pid, "direct": direct,
		"target_id": -1 if direct else target.id,
	})
	if not direct:
		state.emit(GameEvent.Kind.ATTACK_TARGET_SELECTED, {
			"attacker_id": attacker.id, "target_id": target.id, "player": pid,
		})
	return true


## A Replay occurs when, after an attack is declared but before the Damage Step, the set
## of monsters the opponent controls changes. [S1 p.39]
func replay_required() -> bool:
	if state.current_attacker == null:
		return false
	var now := attack_targets(state.turn_player_id).map(func(c): return c.id)
	if now.size() != opponent_monsters_at_declaration.size():
		return true
	for cid in now:
		if not opponent_monsters_at_declaration.has(cid):
			return true
	return false


## Cancel the attack and hand the choice back to the attacking player. The attacker is
## NOT yet considered to have used its attack — it may re-declare, attack with a
## different monster, or not attack at all.
func begin_replay() -> void:
	var attacker = state.current_attacker
	if attacker != null:
		attacker.has_attacked_this_turn = false
		replay_attacker_id = attacker.id
	state.emit(GameEvent.Kind.ATTACK_REPLAY, {
		"attacker_id": attacker.id if attacker != null else -1,
		"player": state.turn_player_id,
	})
	clear_battle()


## The ATTACKER left the field or stopped being face-up before damage calculation: the
## attack simply does not happen.
##
## This is deliberately about the attacker only. If the TARGET leaves the field the
## attack is not cancelled — the set of monsters the opponent controls changed, which is
## a Replay [S1 p.39], and the attacking player gets to choose again. Checking the target
## here would silently swallow that Replay, which is exactly the defect BattleTests
## "removing the attack target causes a Replay" caught.
func attacker_still_valid() -> bool:
	var a = state.current_attacker
	return a != null and a.zone == Enums.Zone.MONSTER_ZONE and a.is_face_up()


## The declared target is still a monster on the field. A false result always coincides
## with `replay_required()`, since the opponent's monsters must have changed for the
## target to have gone.
func target_still_valid() -> bool:
	if state.attack_is_direct:
		return true
	var d = state.current_attack_target
	return d != null and d.zone == Enums.Zone.MONSTER_ZONE


func clear_battle() -> void:
	state.current_attacker = null
	state.current_attack_target = null
	state.attack_is_direct = false
	state.battle_step = Enums.BattleStep.BATTLE
	state.damage_substep = Enums.DamageSubStep.NONE
	stage = Stage.NONE
	pending_destroyed = []
	flipped_before_damage = []


# ---------------------------------------------------------------------------
# Damage Step sub-steps. RULES_SPEC.md 7.1 [S3]
# ---------------------------------------------------------------------------

func _enter_substep(sub: Enums.DamageSubStep) -> void:
	state.damage_substep = sub
	state.emit(GameEvent.Kind.DAMAGE_SUBSTEP_CHANGED, {
		"substep": sub,
		"attacker_id": state.current_attacker.id if state.current_attacker != null else -1,
	})


func begin_damage_step() -> void:
	state.battle_step = Enums.BattleStep.DAMAGE
	state.emit(GameEvent.Kind.BATTLE_STEP_CHANGED, {"step": Enums.BattleStep.DAMAGE})
	stage = Stage.DS_START
	_enter_substep(Enums.DamageSubStep.START_OF_DAMAGE_STEP)


## Sub-step 2: an attacked face-down monster is flipped face-up. Its Flip effect does
## NOT activate here — that is sub-step 4. [S1 p.41]
func step_before_damage_calculation() -> void:
	stage = Stage.DS_BEFORE
	_enter_substep(Enums.DamageSubStep.BEFORE_DAMAGE_CALCULATION)
	var target = state.current_attack_target
	if target != null and target.is_face_down():
		state.set_battle_position(target, Enums.Position.FACE_UP_DEFENSE, true)
		flipped_before_damage.append(target)


## Sub-step 3: compare, inflict battle damage, and DETERMINE destruction.
## Nothing is sent to the Graveyard until sub-step 5.
func step_damage_calculation() -> void:
	stage = Stage.DS_DURING
	_enter_substep(Enums.DamageSubStep.DURING_DAMAGE_CALCULATION)

	var attacker: CardInstance = state.current_attacker
	var defender = state.current_attack_target
	var attacker_pid := attacker.controller_id
	var defender_pid := state.opponent_id(attacker_pid)
	var atk := attacker.current_atk()

	var result := {
		"attacker_id": attacker.id, "attacker_atk": atk,
		"direct": state.attack_is_direct,
		"damage_to": -1, "damage": 0,
		"destroyed": [],
	}

	if state.attack_is_direct:
		# "The full amount of your attacking monster's ATK is subtracted from the
		# opponent's LP as battle damage." [S1 p.43]
		result["damage_to"] = defender_pid
		result["damage"] = atk
	elif defender.is_in_defense_position():
		var def_value: int = defender.current_def()
		result["defender_id"] = defender.id
		result["defender_def"] = def_value
		if atk > def_value:
			if atk > 0 and _can_be_destroyed_by_battle(defender):
				result["destroyed"].append(defender.id)
			# Piercing damage only when a card grants it. [S1 p.42]
			if bool(attacker.flags.get("piercing", false)):
				result["damage_to"] = defender_pid
				result["damage"] = atk - def_value
		elif atk < def_value:
			result["damage_to"] = attacker_pid
			result["damage"] = def_value - atk
		# atk == def_value: neither destroyed, no damage.
	else:
		var def_atk: int = defender.current_atk()
		result["defender_id"] = defender.id
		result["defender_atk"] = def_atk
		if atk > def_atk:
			if _can_be_destroyed_by_battle(defender):
				result["destroyed"].append(defender.id)
			result["damage_to"] = defender_pid
			result["damage"] = atk - def_atk
		elif atk < def_atk:
			if _can_be_destroyed_by_battle(attacker):
				result["destroyed"].append(attacker.id)
			result["damage_to"] = attacker_pid
			result["damage"] = def_atk - atk
		else:
			# A tie destroys both — but a 0 ATK monster cannot destroy anything by
			# battle, so two 0 ATK monsters destroy neither. [S1 p.51]
			if atk > 0:
				if _can_be_destroyed_by_battle(defender):
					result["destroyed"].append(defender.id)
				if _can_be_destroyed_by_battle(attacker):
					result["destroyed"].append(attacker.id)

	attacker.battled_this_turn = true
	if defender != null:
		defender.battled_this_turn = true

	for cid in result["destroyed"]:
		var c = state.instance(cid)
		if c != null:
			pending_destroyed.append(c)

	state.emit(GameEvent.Kind.DAMAGE_CALCULATED, result)

	if int(result["damage"]) > 0 and int(result["damage_to"]) != -1:
		state.change_life_points(int(result["damage_to"]), -int(result["damage"]),
			"battle damage", attacker.id)
		state.emit(GameEvent.Kind.BATTLE_DAMAGE_INFLICTED, {
			"player": int(result["damage_to"]), "amount": int(result["damage"]),
			"attacker_id": attacker.id, "direct": state.attack_is_direct,
		})
	last_damage = result


func _can_be_destroyed_by_battle(card: CardInstance) -> bool:
	if card == null:
		return false
	return not bool(card.flags.get("cannot_be_destroyed_by_battle", false))


## Sub-step 4: battle triggers, and the Flip effects of monsters flipped in sub-step 2.
## The engine runs a trigger check over the events of sub-steps 2 and 3 here, which is
## exactly why the flip event was withheld until now. [S1 p.41]
func step_after_damage_calculation() -> void:
	stage = Stage.DS_AFTER
	_enter_substep(Enums.DamageSubStep.AFTER_DAMAGE_CALCULATION)


## Sub-step 5: monsters destroyed by battle are sent to the Graveyard now.
func step_end_of_damage_step() -> void:
	stage = Stage.DS_END
	_enter_substep(Enums.DamageSubStep.END_OF_DAMAGE_STEP)
	for card in pending_destroyed:
		if card != null and card.zone == Enums.Zone.MONSTER_ZONE:
			state.move_card(card, Enums.Zone.GRAVEYARD,
				Enums.MoveReason.DESTROYED_BY_BATTLE,
				{"source_id": state.current_attacker.id
					if state.current_attacker != null else -1})
	pending_destroyed = []
	# "Until the end of the Damage Step" modifiers expire here.
	for card in state.all_instances():
		card.remove_modifiers_with_duration("end_of_damage_step")


## Leave the Damage Step and return to the Battle Step.
func finish_damage_step() -> void:
	clear_battle()
	state.emit(GameEvent.Kind.BATTLE_STEP_CHANGED, {"step": Enums.BattleStep.BATTLE})


## Called when the Battle Phase ends, so a Replay allowance does not leak into later
## turns.
func end_battle_phase() -> void:
	if replay_attacker_id != -1:
		var previous = state.instance(replay_attacker_id)
		if previous != null:
			previous.has_attacked_this_turn = true
		replay_attacker_id = -1
	clear_battle()
	state.battle_step = Enums.BattleStep.END
	state.emit(GameEvent.Kind.BATTLE_STEP_CHANGED, {"step": Enums.BattleStep.END})
