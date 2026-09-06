class_name DamageStepTests
extends RefCounted

## The Damage Step: its five sub-steps, the activation restriction that applies inside
## them, damage calculation, and battle destruction semantics.
##
## Rules under test: RULES_SPEC.md 7 (Official Rulebook v10 p.41-43, 51-52 = S1, and the
## official Damage Step reference = S3). Nothing here is implemented from memory: every
## assertion cites the section it comes from.
##
## The engine runs the whole Damage Step inside one submit_action() when nobody holds a
## legal response, so ordering assertions read the event log and legality assertions
## either walk the pauses (see `_walk_pauses`) or check the rule function directly.


static func run() -> TestCase:
	var t := TestCase.new("DamageStepTests")
	_test_substeps_run_in_order(t)
	_test_attack_position_damage_calculation(t)
	_test_defense_position_damage_calculation(t)
	_test_zero_atk_destroys_nothing(t)
	_test_destruction_is_determined_before_the_card_reaches_the_gy(t)
	_test_battle_destruction_is_semantically_distinct(t)
	_test_face_down_target_flips_before_damage_and_its_effect_after(t)
	_test_activation_restriction_rule(t)
	_test_activation_restriction_in_a_real_damage_step(t)
	_test_optional_battle_destruction_trigger_can_be_declined(t)
	_test_optional_battle_destruction_trigger_can_be_accepted(t)
	_test_no_battle_destruction_trigger_without_battle_destruction(t)
	_test_battle_damage_to_zero_ends_the_duel(t)
	# The AFTER_DAMAGE_CALC gate — batch 12 unit C, written before `Damage Condenser`.
	_test_after_damage_calc_permission_is_substep_4_only(t)
	_test_after_damage_calc_is_not_the_other_two_permissions(t)
	_test_after_damage_calc_in_a_real_damage_step(t)
	return t


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

## Run one complete attack and return the pieces a test needs to assert on.
static func _battle(seed_value: int, atk: int, defender_atk: int, defender_def: int,
		position: Enums.Position = Enums.Position.FACE_UP_ATTACK) -> Dictionary:
	var d := TestFixtures.battle_duel(seed_value)
	var engine: DuelEngine = d["engine"]
	var attacker := TestFixtures.give_monster_on_field(engine, 0,
		TestFixtures.monster("Attacker", 4, atk, 0))
	var defender := TestFixtures.give_monster_on_field(engine, 1,
		TestFixtures.monster("Defender", 4, defender_atk, defender_def), position)
	var mark := engine.state.events.size()
	TestFixtures.attack(engine, attacker, defender)
	TestFixtures.pass_until_open(engine)
	return {
		"engine": engine, "attacker": attacker, "defender": defender, "mark": mark,
		"p0_lp": engine.state.player(0).life_points,
		"p1_lp": engine.state.player(1).life_points,
	}


## Every sub-step the Damage Step reported, in order.
static func _substep_sequence(engine: DuelEngine, from: int = 0) -> Array:
	return TestFixtures.events_of(engine, GameEvent.Kind.DAMAGE_SUBSTEP_CHANGED, from).map(
		func(e): return e.data.get("substep"))


## Pass through every open response window, recording what `pid` was offered and at which
## sub-step. Used to prove the Damage Step activation restriction is enforced live.
static func _walk_pauses(engine: DuelEngine, pid: int, limit: int = 32) -> Array:
	var seen: Array = []
	var n := 0
	while n < limit and not engine.is_duel_over() \
			and engine.timing != DuelEngine.Timing.OPEN:
		n += 1
		var w := engine.waiting_player()
		if w == -1:
			break
		if w == pid:
			seen.append({
				"battle_step": engine.state.battle_step,
				"substep": engine.state.damage_substep,
				"offered": engine.get_legal_responses(pid).map(func(a): return a.card_id),
			})
		engine.submit_action(DuelAction.make(Enums.ActionKind.PASS, w))
	return seen


## A Set Normal Trap that does nothing, tagged with a specific Damage Step permission.
static func _trap_with_permission(name: String,
		perm: Enums.DamageStepPermission) -> CardDef:
	var def := TestFixtures.trap(name, Enums.STKind.NORMAL_TRAP)
	var e := EffectDef.new("effect", "Test trap.")
	e.of_type(Enums.EffectType.CARD_ACTIVATION)
	e.spell_speed = Enums.SpellSpeed.SS2
	e.damage_step_permission = perm
	e.activation_locations = [Enums.ActivationLocation.FIELD_FACE_DOWN,
		Enums.ActivationLocation.FIELD_FACE_UP]
	e.resolve = func(_ctx: EffectContext) -> void:
		pass
	TestFixtures.with_effect(def, e)
	return def


## A monster whose Flip effect appends to `order_log`. Its window is sub-step 4 when it is
## flipped face-up by an attack, so it carries MANDATORY_TRIGGER permission. [S1 p.41]
static func _flip_effect_monster(name: String, atk: int, def_: int,
		order_log: Array) -> CardDef:
	var d := TestFixtures.monster(name, 4, atk, def_)
	var e := EffectDef.new("flip", "FLIP: test clause.")
	e.of_type(Enums.EffectType.FLIP)
	e.trigger_events = [GameEvent.Kind.CARD_FLIPPED_FACE_UP]
	e.damage_step_permission = Enums.DamageStepPermission.MANDATORY_TRIGGER
	e.activation_locations = [Enums.ActivationLocation.FIELD_FACE_UP]
	e.mandatory()
	e.condition = func(ctx: EffectContext) -> bool:
		var ev: GameEvent = ctx.trigger_event
		return ev != null and int(ev.data.get("card_id", -1)) == ctx.source.id
	e.resolve = func(_ctx: EffectContext) -> void:
		order_log.append("flip")
	TestFixtures.with_effect(d, e)
	return d


## The `Shining Angel` shape: "When this card is destroyed by battle and sent to the GY:
## You can Special Summon 1 LIGHT monster with 1500 or less ATK from your Deck."
##
## Verified research finding preserved here: this trigger is OPTIONAL. Being activatable
## during the Damage Step does not make it mandatory (RULES_SPEC.md 7.2 clarification).
static func _battle_destruction_trigger(name: String, atk: int, def_: int,
		order_log: Array) -> CardDef:
	var d := TestFixtures.monster(name, 4, atk, def_)
	var e := EffectDef.new("on_destroyed_by_battle",
		"When this card is destroyed by battle and sent to the GY: You can Special "
		+ "Summon 1 LIGHT monster with 1500 or less ATK from your Deck.")
	e.of_type(Enums.EffectType.TRIGGER)
	e.trigger_events = [GameEvent.Kind.CARD_SENT_TO_GY]
	e.damage_step_permission = Enums.DamageStepPermission.MANDATORY_TRIGGER
	e.activation_locations = [Enums.ActivationLocation.GRAVEYARD]
	e.targeting(1, 1)
	e.condition = func(ctx: EffectContext) -> bool:
		var ev: GameEvent = ctx.trigger_event
		if ev == null or int(ev.data.get("card_id", -1)) != ctx.source.id:
			return false
		# The semantic reason is what makes this trigger correct: a Tributed or
		# effect-destroyed copy must not fire it. [S1 p.52-53]
		return ev.data.get("reason") == Enums.MoveReason.DESTROYED_BY_BATTLE
	e.legal_targets = func(ctx: EffectContext) -> Array:
		return ctx.me().deck.filter(func(c: CardInstance) -> bool:
			return c.is_monster() and c.definition.attribute == "LIGHT" \
				and c.definition.base_atk <= 1500)
	e.resolve = func(ctx: EffectContext) -> void:
		order_log.append("special_summon")
	TestFixtures.with_effect(d, e)
	return d


# ---------------------------------------------------------------------------
# 7.1 Sub-steps [S3]
# ---------------------------------------------------------------------------

static func _test_substeps_run_in_order(t: TestCase) -> void:
	t.start("the Damage Step runs its five sub-steps in order")
	var r := _battle(701, 1800, 1000, 1000)
	var engine: DuelEngine = r["engine"]

	t.eq(_substep_sequence(engine, r["mark"]), [
		Enums.DamageSubStep.START_OF_DAMAGE_STEP,
		Enums.DamageSubStep.BEFORE_DAMAGE_CALCULATION,
		Enums.DamageSubStep.DURING_DAMAGE_CALCULATION,
		Enums.DamageSubStep.AFTER_DAMAGE_CALCULATION,
		Enums.DamageSubStep.END_OF_DAMAGE_STEP,
	], "all five sub-steps were entered in the order given by [S3]")

	var steps := TestFixtures.events_of(engine, GameEvent.Kind.BATTLE_STEP_CHANGED,
		r["mark"]).map(func(e): return e.data.get("step"))
	t.eq(steps, [Enums.BattleStep.DAMAGE, Enums.BattleStep.BATTLE],
		"the Battle Step gives way to the Damage Step and takes over again afterwards")
	t.eq(engine.state.damage_substep, Enums.DamageSubStep.NONE,
		"no sub-step is left set once the Damage Step is over")
	t.eq(engine.timing, DuelEngine.Timing.OPEN,
		"and the engine is back in an open game state")


# ---------------------------------------------------------------------------
# 7.4 Damage calculation [S1 p.42-43]
# ---------------------------------------------------------------------------

static func _test_attack_position_damage_calculation(t: TestCase) -> void:
	t.start("Attack Position vs Attack Position damage calculation")

	# attacker ATK > defender ATK
	var higher := _battle(711, 1800, 1000, 2500)
	t.eq(higher["defender"].zone, Enums.Zone.GRAVEYARD,
		"the higher-ATK attacker destroys the defender")
	t.eq(higher["attacker"].zone, Enums.Zone.MONSTER_ZONE, "the attacker survives")
	t.eq(higher["p1_lp"], 8000 - 800,
		"the defending player takes the ATK difference [S1 p.42]")
	t.eq(higher["p0_lp"], 8000, "the attacking player takes nothing")
	t.eq(higher["defender"].current_def(), 2500,
		"DEF played no part in the comparison")

	# attacker ATK = defender ATK
	var tie := _battle(712, 1500, 1500, 0)
	t.eq(tie["attacker"].zone, Enums.Zone.GRAVEYARD, "equal ATK destroys the attacker")
	t.eq(tie["defender"].zone, Enums.Zone.GRAVEYARD, "and the defender [S1 p.42]")
	t.eq(tie["p0_lp"], 8000, "no damage to either player")
	t.eq(tie["p1_lp"], 8000, "no damage to either player")

	# attacker ATK < defender ATK
	var lower := _battle(713, 1000, 1900, 0)
	t.eq(lower["attacker"].zone, Enums.Zone.GRAVEYARD,
		"attacking into a bigger monster destroys the attacker")
	t.eq(lower["defender"].zone, Enums.Zone.MONSTER_ZONE, "the defender survives")
	t.eq(lower["p0_lp"], 8000 - 900,
		"the attacking player takes the difference [S1 p.42]")
	t.eq(lower["p1_lp"], 8000, "the defending player takes nothing")


static func _test_defense_position_damage_calculation(t: TestCase) -> void:
	t.start("Attack Position vs Defense Position damage calculation")

	# attacker ATK > defender DEF
	var over := _battle(721, 2000, 2400, 1000, Enums.Position.FACE_UP_DEFENSE)
	t.eq(over["defender"].zone, Enums.Zone.GRAVEYARD,
		"ATK greater than DEF destroys the defender")
	t.eq(over["p1_lp"], 8000,
		"but inflicts NO battle damage without piercing [S1 p.42]")
	t.eq(over["p0_lp"], 8000, "and none to the attacker")

	# attacker ATK = defender DEF
	var equal := _battle(722, 1500, 2400, 1500, Enums.Position.FACE_UP_DEFENSE)
	t.eq(equal["defender"].zone, Enums.Zone.MONSTER_ZONE,
		"ATK equal to DEF destroys nothing [S1 p.42]")
	t.eq(equal["attacker"].zone, Enums.Zone.MONSTER_ZONE, "the attacker survives too")
	t.eq(equal["p0_lp"], 8000, "no damage either way")
	t.eq(equal["p1_lp"], 8000, "no damage either way")

	# attacker ATK < defender DEF
	var under := _battle(723, 1200, 100, 2000, Enums.Position.FACE_UP_DEFENSE)
	t.eq(under["defender"].zone, Enums.Zone.MONSTER_ZONE, "the wall holds")
	t.eq(under["attacker"].zone, Enums.Zone.MONSTER_ZONE,
		"the attacker is NOT destroyed by a Defense Position monster [S1 p.42]")
	t.eq(under["p0_lp"], 8000 - 800,
		"the attacking player takes DEF minus ATK [S1 p.42]")
	t.eq(under["p1_lp"], 8000, "the defending player takes nothing")


static func _test_zero_atk_destroys_nothing(t: TestCase) -> void:
	t.start("two 0 ATK Attack Position monsters destroy neither")
	var r := _battle(731, 0, 0, 0)
	t.eq(r["attacker"].zone, Enums.Zone.MONSTER_ZONE,
		"a 0 ATK monster cannot destroy anything by battle [S1 p.51]")
	t.eq(r["defender"].zone, Enums.Zone.MONSTER_ZONE, "and neither is destroyed")
	t.eq(r["p0_lp"], 8000, "no damage")
	t.eq(r["p1_lp"], 8000, "no damage")

	# The same monster is still destroyed by a real attacker, so this is not a
	# blanket immunity.
	var beaten := _battle(732, 100, 0, 0)
	t.eq(beaten["defender"].zone, Enums.Zone.GRAVEYARD,
		"a 0 ATK monster is still destroyed by an attacker with ATK")


# ---------------------------------------------------------------------------
# Destruction timing and semantics. RULES_SPEC.md 7.1, 8 [S1 p.52-53]
# ---------------------------------------------------------------------------

static func _test_destruction_is_determined_before_the_card_reaches_the_gy(
		t: TestCase) -> void:
	t.start("destruction is determined during damage calculation but the card is only "
		+ "sent to the Graveyard at the end of the Damage Step")
	var r := _battle(741, 1800, 1000, 1000)
	var engine: DuelEngine = r["engine"]
	var defender: CardInstance = r["defender"]

	var calc := TestFixtures.events_of(engine, GameEvent.Kind.DAMAGE_CALCULATED,
		r["mark"])
	t.eq(calc.size(), 1, "damage calculation happened once")
	t.is_true(calc.size() == 1 and calc[0].data.get("destroyed") == [defender.id],
		"the defender's destruction was determined during damage calculation [S3]")

	var calc_at := TestFixtures.first_event_index(engine,
		GameEvent.Kind.DAMAGE_CALCULATED, r["mark"])
	var end_at := -1
	var gy_at := -1
	for i in range(r["mark"], engine.state.events.size()):
		var e: GameEvent = engine.state.events[i]
		if end_at == -1 and e.kind == GameEvent.Kind.DAMAGE_SUBSTEP_CHANGED \
				and e.data.get("substep") == Enums.DamageSubStep.END_OF_DAMAGE_STEP:
			end_at = i
		if gy_at == -1 and e.kind == GameEvent.Kind.CARD_SENT_TO_GY \
				and int(e.data.get("card_id", -1)) == defender.id:
			gy_at = i
	t.is_true(gy_at != -1, "the destroyed monster reached the Graveyard")
	t.is_true(calc_at != -1 and gy_at != -1 and calc_at < gy_at,
		"it was sent AFTER damage calculation, not during it [S3]")
	t.is_true(end_at != -1 and gy_at > end_at,
		"and specifically in the end-of-Damage-Step sub-step [S3]")


static func _test_battle_destruction_is_semantically_distinct(t: TestCase) -> void:
	t.start("a monster destroyed by battle produces the destroyed-by-battle reason")
	var r := _battle(751, 1800, 1000, 1000)
	var engine: DuelEngine = r["engine"]
	var defender: CardInstance = r["defender"]

	var moved := TestFixtures.events_of(engine, GameEvent.Kind.CARD_MOVED, r["mark"]) \
		.filter(func(e): return int(e.data.get("card_id", -1)) == defender.id)
	t.eq(moved.size(), 1, "the destroyed monster moved exactly once")
	t.is_true(moved.size() == 1
		and moved[0].data.get("reason") == Enums.MoveReason.DESTROYED_BY_BATTLE,
		"the move carries DESTROYED_BY_BATTLE, not a generic reason (RULES_SPEC.md 8)")

	t.eq(TestFixtures.events_of(engine, GameEvent.Kind.CARD_DESTROYED, r["mark"]).size(),
		1, "CARD_DESTROYED was emitted [S1 p.52]")
	t.eq(TestFixtures.events_of(engine, GameEvent.Kind.CARD_SENT_TO_GY, r["mark"]).size(),
		1, "and CARD_SENT_TO_GY, because destruction is also a send [S1 p.53]")
	t.eq(TestFixtures.events_of(engine, GameEvent.Kind.CARD_TRIBUTED, r["mark"]).size(),
		0, "and it is emphatically not a Tribute")
	t.eq(defender.owner_id, 1,
		"the card went to its OWNER's Graveyard, not its destroyer's [S1 p.52]")
	t.is_true(engine.state.player(1).graveyard.has(defender),
		"it is in player 1's Graveyard")


# ---------------------------------------------------------------------------
# 7.3 Flip during battle [S1 p.41]
# ---------------------------------------------------------------------------

static func _test_face_down_target_flips_before_damage_and_its_effect_after(
		t: TestCase) -> void:
	t.start("an attacked face-down monster is flipped in sub-step 2 but its Flip effect "
		+ "activates in sub-step 4")
	var d := TestFixtures.battle_duel(761)
	var engine: DuelEngine = d["engine"]
	var order: Array = []
	var attacker := TestFixtures.give_monster_on_field(engine, 0,
		TestFixtures.monster("Prober", 4, 1000, 1000))
	var hidden := TestFixtures.give_monster_on_field(engine, 1,
		_flip_effect_monster("Trap Hole Monster", 500, 2000, order),
		Enums.Position.FACE_DOWN_DEFENSE)

	var mark := engine.state.events.size()
	TestFixtures.attack(engine, attacker, hidden)
	TestFixtures.pass_until_open(engine)

	t.eq(hidden.position, Enums.Position.FACE_UP_DEFENSE,
		"the attacked face-down monster was flipped face-up [S1 p.41]")
	t.eq(order, ["flip"], "its Flip effect resolved")

	var flip_at := -1
	var before_at := -1
	var after_at := -1
	var link_at := -1
	for i in range(mark, engine.state.events.size()):
		var e: GameEvent = engine.state.events[i]
		if e.kind == GameEvent.Kind.CARD_FLIPPED_FACE_UP and flip_at == -1:
			flip_at = i
		if e.kind == GameEvent.Kind.DAMAGE_SUBSTEP_CHANGED:
			if before_at == -1 and e.data.get("substep") \
					== Enums.DamageSubStep.BEFORE_DAMAGE_CALCULATION:
				before_at = i
			if after_at == -1 and e.data.get("substep") \
					== Enums.DamageSubStep.AFTER_DAMAGE_CALCULATION:
				after_at = i
		if e.kind == GameEvent.Kind.CHAIN_LINK_ADDED and link_at == -1 \
				and int(e.data.get("card_id", -1)) == hidden.id:
			link_at = i
	t.is_true(before_at != -1 and flip_at > before_at,
		"the flip happened in the before-damage-calculation sub-step [S3]")
	t.is_true(after_at != -1 and flip_at < after_at,
		"and before damage calculation finished")
	t.is_true(link_at != -1 and after_at != -1 and link_at > after_at,
		"but the Flip effect only became a Chain Link in sub-step 4 [S1 p.41]")

	t.eq(hidden.zone, Enums.Zone.MONSTER_ZONE,
		"1000 ATK does not beat 2000 DEF, so the monster survived")
	t.eq(engine.state.player(0).life_points, 8000 - 1000,
		"and the attacking player took the DEF difference [S1 p.42]")


# ---------------------------------------------------------------------------
# 7.2 Activation restriction [S1 p.41] — CRITICAL
# ---------------------------------------------------------------------------

static func _test_activation_restriction_rule(t: TestCase) -> void:
	t.start("the Damage Step activation restriction is enforced per sub-step")
	var d := TestFixtures.battle_duel(771)
	var engine: DuelEngine = d["engine"]
	var state := engine.state

	# Explicitly typed: an element of an untyped Array is a Variant, and := cannot infer
	# through a Variant in GDScript.
	var none_effect: EffectDef = _trap_with_permission("No Entry",
		Enums.DamageStepPermission.NONE).effects[0]
	var until_effect: EffectDef = _trap_with_permission("Stat Changer",
		Enums.DamageStepPermission.UNTIL_DAMAGE_CALC).effects[0]

	# Outside the Damage Step the restriction does not apply at all.
	state.battle_step = Enums.BattleStep.BATTLE
	state.damage_substep = Enums.DamageSubStep.NONE
	t.is_true(ActivationRules.damage_step_ok(state, none_effect),
		"outside the Damage Step even a NONE effect is unaffected by this rule")

	state.battle_step = Enums.BattleStep.DAMAGE
	var early := [Enums.DamageSubStep.START_OF_DAMAGE_STEP,
		Enums.DamageSubStep.BEFORE_DAMAGE_CALCULATION]
	var late := [Enums.DamageSubStep.DURING_DAMAGE_CALCULATION,
		Enums.DamageSubStep.AFTER_DAMAGE_CALCULATION,
		Enums.DamageSubStep.END_OF_DAMAGE_STEP]

	var none_allowed := 0
	for sub in early + late:
		state.damage_substep = sub
		if ActivationRules.damage_step_ok(state, none_effect):
			none_allowed += 1
	t.eq(none_allowed, 0,
		"an effect with permission NONE is never legal in any Damage Step sub-step")

	var until_early := 0
	for sub in early:
		state.damage_substep = sub
		if ActivationRules.damage_step_ok(state, until_effect):
			until_early += 1
	t.eq(until_early, 2,
		"UNTIL_DAMAGE_CALC is legal at the start of the Damage Step and before damage "
		+ "calculation [S1 p.41]")

	var until_late := 0
	for sub in late:
		state.damage_substep = sub
		if ActivationRules.damage_step_ok(state, until_effect):
			until_late += 1
	t.eq(until_late, 0,
		"and is illegal from the start of damage calculation onward [S1 p.41]")

	# MANDATORY_TRIGGER describes the TIMING, not the optionality: an optional
	# destroyed-by-battle trigger still uses it (RULES_SPEC.md 7.2 clarification).
	var optional_trigger: EffectDef = _battle_destruction_trigger("Angel", 1400, 800,
		[]).effects[0]
	state.damage_substep = Enums.DamageSubStep.END_OF_DAMAGE_STEP
	t.is_true(ActivationRules.damage_step_ok(state, optional_trigger),
		"a trigger-collected effect keeps its rules-mandated Damage Step window")
	t.eq(optional_trigger.optionality, Enums.Optionality.OPTIONAL,
		"even though the effect itself is optional")


static func _test_activation_restriction_in_a_real_damage_step(t: TestCase) -> void:
	t.start("inside a real Damage Step only the permitted card is ever offered")
	var d := TestFixtures.battle_duel(772)
	var engine: DuelEngine = d["engine"]
	var attacker := TestFixtures.give_monster_on_field(engine, 0,
		TestFixtures.monster("Aggressor", 4, 1800, 1000))
	var target := TestFixtures.give_monster_on_field(engine, 1,
		TestFixtures.monster("Bystander", 4, 1000, 1000))
	var forbidden := TestFixtures.give_set_spell_trap(engine, 1,
		_trap_with_permission("Forbidden Here", Enums.DamageStepPermission.NONE), 0)
	var allowed := TestFixtures.give_set_spell_trap(engine, 1,
		_trap_with_permission("Stat Changer", Enums.DamageStepPermission.UNTIL_DAMAGE_CALC),
		0)

	TestFixtures.attack(engine, attacker, target)
	# Before the Damage Step both are legal: the restriction is Damage-Step-only.
	var declaration := engine.get_legal_responses(1).map(func(a): return a.card_id)
	t.is_true(declaration.has(forbidden.id) and declaration.has(allowed.id),
		"both traps are available in the attack-declaration window")

	var pauses := _walk_pauses(engine, 1)
	var in_damage_step := pauses.filter(
		func(p): return p["battle_step"] == Enums.BattleStep.DAMAGE)
	t.is_true(in_damage_step.size() >= 2,
		"the Damage Step really opened response windows")

	var forbidden_offers := 0
	var allowed_offers := 0
	var late_allowed_offers := 0
	for p in in_damage_step:
		if p["offered"].has(forbidden.id):
			forbidden_offers += 1
		if p["offered"].has(allowed.id):
			allowed_offers += 1
			if p["substep"] != Enums.DamageSubStep.START_OF_DAMAGE_STEP \
					and p["substep"] != Enums.DamageSubStep.BEFORE_DAMAGE_CALCULATION:
				late_allowed_offers += 1
	t.eq(forbidden_offers, 0,
		"the NONE trap is never offered anywhere in the Damage Step [S1 p.41]")
	t.is_true(allowed_offers >= 1,
		"the UNTIL_DAMAGE_CALC trap is offered inside the Damage Step")
	t.eq(late_allowed_offers, 0,
		"and only up until the start of damage calculation [S1 p.41]")


# ---------------------------------------------------------------------------
# Optional destroyed-by-battle trigger — the `Shining Angel` regression.
# RULES_SPEC.md 7.2 clarification; verified research finding.
# ---------------------------------------------------------------------------

static func _test_optional_battle_destruction_trigger_can_be_declined(
		t: TestCase) -> void:
	t.start("an optional destroyed-by-battle trigger is offered to its controller and "
		+ "may be declined")
	var d := TestFixtures.battle_duel(781)
	var engine: DuelEngine = d["engine"]
	var controller: ScriptedController = d["p1"]
	controller.default_yes = false
	var order: Array = []

	var attacker := TestFixtures.give_monster_on_field(engine, 0,
		TestFixtures.monster("Executioner", 4, 2000, 1000))
	var angel := TestFixtures.give_monster_on_field(engine, 1,
		_battle_destruction_trigger("Shining Angel Shape", 1400, 800, order))

	var seen_before := controller.request_count(Enums.DecisionKind.YES_NO)
	TestFixtures.attack(engine, attacker, angel)
	TestFixtures.pass_until_open(engine)

	t.eq(angel.zone, Enums.Zone.GRAVEYARD, "it was destroyed by battle")
	t.eq(controller.request_count(Enums.DecisionKind.YES_NO), seen_before + 1,
		"its controller was asked exactly once whether to activate it")
	t.eq(order, [],
		"answering no does not activate the effect — being legal in the Damage Step "
		+ "does not make an optional trigger mandatory")
	t.eq(TestFixtures.count_events(engine, GameEvent.Kind.CHAIN_LINK_ADDED), 0,
		"and nothing was put onto a Chain")


static func _test_optional_battle_destruction_trigger_can_be_accepted(
		t: TestCase) -> void:
	t.start("accepting the destroyed-by-battle trigger builds a Chain Link at the end "
		+ "of the Damage Step, over legally filtered candidates")
	var d := TestFixtures.battle_duel(782)
	var engine: DuelEngine = d["engine"]
	var controller: ScriptedController = d["p1"]
	controller.default_yes = true
	var order: Array = []

	var attacker := TestFixtures.give_monster_on_field(engine, 0,
		TestFixtures.monster("Executioner", 4, 2000, 1000))
	var angel := TestFixtures.give_monster_on_field(engine, 1,
		_battle_destruction_trigger("Shining Angel Shape", 1400, 800, order))
	# A monster the effect must NOT be allowed to pick: too much ATK, wrong Attribute.
	var illegal := TestFixtures.give(engine, 1,
		TestFixtures.monster("Too Big", 8, 3000, 2500, "DARK"), Enums.Zone.DECK)

	var mark := engine.state.events.size()
	TestFixtures.attack(engine, attacker, angel)
	TestFixtures.pass_until_open(engine)

	t.eq(order, ["special_summon"], "the effect resolved after being accepted")

	var link_at := -1
	var end_at := -1
	for i in range(mark, engine.state.events.size()):
		var e: GameEvent = engine.state.events[i]
		if end_at == -1 and e.kind == GameEvent.Kind.DAMAGE_SUBSTEP_CHANGED \
				and e.data.get("substep") == Enums.DamageSubStep.END_OF_DAMAGE_STEP:
			end_at = i
		if link_at == -1 and e.kind == GameEvent.Kind.CHAIN_LINK_ADDED \
				and int(e.data.get("card_id", -1)) == angel.id:
			link_at = i
	t.is_true(link_at != -1, "it became a Chain Link")
	t.is_true(end_at != -1 and link_at > end_at,
		"in the end-of-Damage-Step sub-step, after it was sent to the GY [S3]")

	var target_requests := controller.seen_requests.filter(
		func(r): return r.kind == Enums.DecisionKind.CHOOSE_TARGETS)
	t.eq(target_requests.size(), 1, "its controller chose the Special Summon candidate")
	t.is_false(target_requests.size() == 1
		and target_requests[0].options.has(illegal.id),
		"a monster that does not satisfy the card's own restriction is never offered")
	t.is_true(target_requests.size() == 1 and not target_requests[0].options.is_empty(),
		"the legal candidates were offered")


## A Set Normal Trap belonging to the activating player that sends `victim_holder[0]` to
## the Graveyard WITHOUT destroying it.
static func _send_to_gy_trap(name: String, victim_holder: Array) -> CardDef:
	var def := TestFixtures.trap(name, Enums.STKind.NORMAL_TRAP)
	var e := EffectDef.new("send", "Send 1 monster your opponent controls to the GY.")
	e.of_type(Enums.EffectType.CARD_ACTIVATION)
	e.spell_speed = Enums.SpellSpeed.SS2
	e.activation_locations = [Enums.ActivationLocation.FIELD_FACE_DOWN,
		Enums.ActivationLocation.FIELD_FACE_UP]
	e.resolve = func(ctx: EffectContext) -> void:
		var victim = victim_holder[0]
		if victim != null and victim.is_on_field():
			ctx.state.move_card(victim, Enums.Zone.GRAVEYARD,
				Enums.MoveReason.SENT_TO_GY_BY_EFFECT, {"source_id": ctx.source.id})
	TestFixtures.with_effect(def, e)
	return def


static func _test_no_battle_destruction_trigger_without_battle_destruction(
		t: TestCase) -> void:
	t.start("the destroyed-by-battle trigger does not fire when the card was sent to "
		+ "the Graveyard some other way")
	var d := TestFixtures.battle_duel(783)
	var engine: DuelEngine = d["engine"]
	var controller: ScriptedController = d["p1"]
	controller.default_yes = true
	var order: Array = []

	var angel := TestFixtures.give_monster_on_field(engine, 1,
		_battle_destruction_trigger("Shining Angel Shape", 1400, 800, order))
	var holder: Array = [angel]
	# The removal goes through a real activation and resolution, so the engine performs a
	# genuine trigger check over the resulting CARD_SENT_TO_GY event. Without that the
	# test would prove nothing: it would only show that a trigger nobody looked for did
	# not fire.
	var trap := TestFixtures.give_set_spell_trap(engine, 0,
		_send_to_gy_trap("Quiet Removal", holder), 0)

	var mark := engine.state.events.size()
	engine.submit_action(TestFixtures.find_action(
		engine.get_legal_actions(0), Enums.ActionKind.ACTIVATE_CARD, trap.id))
	TestFixtures.pass_until_open(engine)

	t.eq(angel.zone, Enums.Zone.GRAVEYARD, "the card did reach the Graveyard")
	var sends := TestFixtures.events_of(engine, GameEvent.Kind.CARD_SENT_TO_GY, mark) \
		.filter(func(e): return int(e.data.get("card_id", -1)) == angel.id)
	t.eq(sends.size(), 1, "a CARD_SENT_TO_GY event really was raised for it [S1 p.53]")
	t.is_true(sends.size() == 1
		and sends[0].data.get("reason") == Enums.MoveReason.SENT_TO_GY_BY_EFFECT,
		"carrying the send-by-effect reason, not a destruction")
	t.eq(TestFixtures.events_of(engine, GameEvent.Kind.CARD_DESTROYED, mark).size(), 0,
		"nothing was destroyed [S1 p.52]")
	t.eq(order, [], "so the destroyed-by-battle trigger did not activate")
	t.eq(controller.request_count(Enums.DecisionKind.YES_NO), 0,
		"and its controller was never asked about it")


# ---------------------------------------------------------------------------
# Victory by battle damage. RULES_SPEC.md 13 [S1 p.33]
# ---------------------------------------------------------------------------

static func _test_battle_damage_to_zero_ends_the_duel(t: TestCase) -> void:
	t.start("battle damage that reduces a player to 0 Life Points ends the Duel")
	var d := TestFixtures.battle_duel(791)
	var engine: DuelEngine = d["engine"]
	engine.state.change_life_points(1, -7000, "test setup")
	t.eq(engine.state.player(1).life_points, 1000, "the opponent is at 1000 LP")

	var attacker := TestFixtures.give_monster_on_field(engine, 0,
		TestFixtures.monster("Finisher", 4, 1800, 1000))
	TestFixtures.attack(engine, attacker, null)
	TestFixtures.pass_until_open(engine)

	t.eq(engine.state.player(1).life_points, 0, "Life Points do not go below zero")
	t.is_true(engine.is_duel_over(), "the Duel is over [S1 p.33]")
	t.eq(engine.state.result, Enums.DuelResult.PLAYER_0_WINS, "the attacker won")
	t.eq(engine.state.end_reason, Enums.EndReason.LP_ZERO, "by Life Point depletion")
	t.eq(engine.timing, DuelEngine.Timing.DUEL_OVER,
		"and the timing machine reports the Duel as over")
	t.eq(engine.get_legal_actions(0).size(), 0, "no further action is legal")


# ---------------------------------------------------------------------------
# AFTER_DAMAGE_CALC — the sub-step 4 permission. RULES_SPEC.md 7.2.
#
# The gate for batch 12 unit C, written and passing BEFORE `Damage Condenser` existed.
#
# It exists because the engine could NOT express the card, not because a fourth value is
# tidier. §7.1 sub-step 4 is explicitly the window for "when battle damage is inflicted",
# and `Damage Condenser` (cid 6582) is activated there from a Set position — but:
#
#   * `UNTIL_DAMAGE_CALC` is sub-steps 1-2 only, which is earlier than the card's window
#     and is the wrong answer rather than a near-enough one;
#   * `MANDATORY_TRIGGER` is gated on `TriggerCollector._is_collectable()`, which answers
#     true only for `EffectType.TRIGGER` and `FLIP`. A Normal Trap's own activation is
#     `EffectType.CARD_ACTIVATION` — that is what flips it face-up and sends it to the
#     Graveyard afterwards — so the permission can never apply to it.
#
# Both of those are asserted below, so the reason the value exists cannot quietly stop
# being true.
# ---------------------------------------------------------------------------


static func _test_after_damage_calc_permission_is_substep_4_only(t: TestCase) -> void:
	t.start("AFTER_DAMAGE_CALC is legal in sub-step 4 and in NO other sub-step")
	var d := TestFixtures.battle_duel(781)
	var engine: DuelEngine = d["engine"]
	var state := engine.state
	var after_effect: EffectDef = _trap_with_permission("Late Responder",
		Enums.DamageStepPermission.AFTER_DAMAGE_CALC).effects[0]

	# Outside the Damage Step the restriction does not apply at all.
	state.battle_step = Enums.BattleStep.BATTLE
	state.damage_substep = Enums.DamageSubStep.NONE
	t.is_true(ActivationRules.damage_step_ok(state, after_effect),
		"outside the Damage Step the rule does not speak")

	state.battle_step = Enums.BattleStep.DAMAGE
	var allowed: Array = []
	for sub in [Enums.DamageSubStep.START_OF_DAMAGE_STEP,
			Enums.DamageSubStep.BEFORE_DAMAGE_CALCULATION,
			Enums.DamageSubStep.DURING_DAMAGE_CALCULATION,
			Enums.DamageSubStep.AFTER_DAMAGE_CALCULATION,
			Enums.DamageSubStep.END_OF_DAMAGE_STEP]:
		state.damage_substep = sub
		if ActivationRules.damage_step_ok(state, after_effect):
			allowed.append(sub)
	t.eq(allowed.size(), 1, "exactly one sub-step admits it")
	t.eq(allowed, [Enums.DamageSubStep.AFTER_DAMAGE_CALCULATION],
		"and it is sub-step 4, after damage calculation [S1 p.41, RULES_SPEC 7.1]")


static func _test_after_damage_calc_is_not_the_other_two_permissions(t: TestCase) -> void:
	t.start("AFTER_DAMAGE_CALC is a genuinely new answer: neither existing value gives a "
		+ "Trap CARD activation a sub-step 4 window")
	var d := TestFixtures.battle_duel(782)
	var engine: DuelEngine = d["engine"]
	var state := engine.state
	state.battle_step = Enums.BattleStep.DAMAGE
	state.damage_substep = Enums.DamageSubStep.AFTER_DAMAGE_CALCULATION

	var until_effect: EffectDef = _trap_with_permission("Early Responder",
		Enums.DamageStepPermission.UNTIL_DAMAGE_CALC).effects[0]
	t.is_false(ActivationRules.damage_step_ok(state, until_effect),
		"UNTIL_DAMAGE_CALC is refused in sub-step 4 — it is the earlier window")

	# MANDATORY_TRIGGER cannot describe a card activation, because it is gated on the
	# effect being trigger-COLLECTED and a Trap's own activation never is.
	var mandatory_card: EffectDef = _trap_with_permission("Wrongly Labelled",
		Enums.DamageStepPermission.MANDATORY_TRIGGER).effects[0]
	t.eq(mandatory_card.effect_type, Enums.EffectType.CARD_ACTIVATION,
		"the fixture really is a CARD activation")
	t.is_false(TriggerCollector._is_collectable(mandatory_card),
		"which the trigger system does not collect")
	t.is_false(ActivationRules.damage_step_ok(state, mandatory_card),
		"so MANDATORY_TRIGGER gives it no window at all — this is the gap the new value "
		+ "fills")

	# And the control: the same permission on a genuinely collected effect still works, so
	# the new value took nothing away.
	var real_trigger: EffectDef = _battle_destruction_trigger("Angel", 1400, 800,
		[]).effects[0]
	state.damage_substep = Enums.DamageSubStep.END_OF_DAMAGE_STEP
	t.is_true(ActivationRules.damage_step_ok(state, real_trigger),
		"MANDATORY_TRIGGER still works for what it was written for")


static func _test_after_damage_calc_in_a_real_damage_step(t: TestCase) -> void:
	t.start("in a REAL Damage Step: a Set Trap with AFTER_DAMAGE_CALC is offered in the "
		+ "window that follows battle damage, and one with NONE is not")
	var d := TestFixtures.battle_duel(783)
	var engine: DuelEngine = d["engine"]
	var attacker := TestFixtures.give_monster_on_field(engine, 0,
		TestFixtures.monster("Attacker", 4, 1800, 1000))
	var late := TestFixtures.give_set_spell_trap(engine, 1,
		_trap_with_permission("Late Responder",
			Enums.DamageStepPermission.AFTER_DAMAGE_CALC))
	var never := TestFixtures.give_set_spell_trap(engine, 1,
		_trap_with_permission("Never Responder", Enums.DamageStepPermission.NONE))

	t.is_true(TestFixtures.attack(engine, attacker, null), "a direct attack is declared")

	# Walk to the first pause at which the defending player holds a response, and record
	# what the Damage Step offered them at each one.
	var offered_late := false
	var offered_never := false
	var saw_substep_4 := false
	for i in range(24):
		if engine.state.battle_step == Enums.BattleStep.DAMAGE \
				and engine.state.damage_substep \
					== Enums.DamageSubStep.AFTER_DAMAGE_CALCULATION:
			saw_substep_4 = true
			var responses := engine.get_legal_responses(1)
			if TestFixtures.find_action(responses, Enums.ActionKind.ACTIVATE_CARD,
					late.id) != null:
				offered_late = true
			if TestFixtures.find_action(responses, Enums.ActionKind.ACTIVATE_CARD,
					never.id) != null:
				offered_never = true
		if engine.timing == DuelEngine.Timing.OPEN or engine.is_duel_over():
			break
		if not engine.submit_action(DuelAction.make(Enums.ActionKind.PASS, 1)) \
				and not engine.submit_action(DuelAction.make(Enums.ActionKind.PASS, 0)):
			break

	t.is_true(saw_substep_4, "the Damage Step really reached sub-step 4")
	t.is_true(offered_late,
		"the AFTER_DAMAGE_CALC Trap was offered there — the permission is not merely a "
		+ "rules-function answer, it reaches the legal-action list")
	t.is_false(offered_never,
		"while the NONE Trap was never offered, so the window is not simply open to all")

