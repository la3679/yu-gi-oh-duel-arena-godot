extends RefCounted

## Enemy Controller — Quick-Play Spell.
##
## Official text (verified against the Konami card database, cid 5505; see
## Data/generated/konami_cards.json):
##
##   "Activate 1 of these effects;
##    ● Target 1 face-up monster your opponent controls; change that target's battle
##      position.
##    ● Tribute 1 monster, then target 1 face-up monster your opponent controls; take
##      control of that target until the End Phase."
##
## **Two bullets, two EffectDefs, and they must not be approximated as one generic
## control-change Spell.** They differ in cost, in what they do and in duration, and the
## player chooses BETWEEN them at activation — "Activate 1 of these effects". Each bullet is
## offered as its own `ACTIVATE_CARD` action with its own `effect_id`, so choosing the
## action IS choosing the effect, and the engine's existing candidate publication and
## re-validation apply to each separately.
##
## Details that are easy to get wrong:
##
##   1. **"Tribute 1 monster" is a COST, not an effect.** It is paid at activation, before
##      the Chain Link exists, and is never refunded — negate the activation afterwards and
##      the Tribute stays paid (RULES_SPEC.md §10). With no monster to Tribute the second
##      bullet cannot be activated at all.
##   2. **"then target"** puts the Tribute before the targeting in the printed order. It
##      changes nothing here: the cost consumes a monster YOU control and the targets are
##      monsters your OPPONENT controls, so paying it cannot alter the candidate set. The
##      ordering is recorded rather than relied upon.
##   3. **Both bullets require a FACE-UP monster your opponent controls.** A face-down
##      monster is neither a legal target of the position change nor of the control grab.
##   4. **"until the End Phase"** is a duration owned by the rules layer, not by this card:
##      `Enums.ControlDuration.UNTIL_END_PHASE`, expired by `TurnFlow.enter_phase()` as the
##      End Phase is entered. There is no timer, no polling and no per-card bookkeeping, and
##      the control returns even if this card left the field long before — a resolved
##      Normal/Quick-Play Spell goes to the Graveyard immediately, so anything that depended
##      on the card still being on the field would be wrong. RULES_SPEC.md §5.6.
##   5. **The first bullet's position change is BY EFFECT.** It therefore does not spend the
##      monster's once-per-turn manual battle position change and is not subject to the three
##      manual-change restrictions [S1 p.36] — those govern what a PLAYER may do in their
##      Main Phase, not what a card effect does.
##   6. **Neither bullet is legal in the Damage Step.** [S1 p.41] permits only Counter Traps,
##      effects that negate, and effects that directly change ATK/DEF. A battle position
##      change is none of those, however tempting the timing looks. RULES_SPEC.md §7.2.
##   7. **Quick-Play**, so Spell Speed 2, activatable from the hand on your own turn and from
##      a Set copy on either turn — the standard Quick-Play shape
##      `ActivationRules.set_turn_ok()` already enforces.

const CARD_NAME := "Enemy Controller"

const CLAUSE_POSITION := "Activate 1 of these effects; ● Target 1 face-up monster your " \
	+ "opponent controls; change that target's battle position."
const CLAUSE_CONTROL := "Activate 1 of these effects; ● Tribute 1 monster, then target 1 " \
	+ "face-up monster your opponent controls; take control of that target until the End " \
	+ "Phase."


func effects() -> Array:
	return [_change_position(), _take_control()]


## The shape both bullets share: a Quick-Play Spell targeting exactly 1 face-up monster the
## opponent controls, illegal in the Damage Step.
func _as_quick_play(e: EffectDef) -> EffectDef:
	e.of_type(Enums.EffectType.CARD_ACTIVATION)
	e.with_spell_speed(Enums.SpellSpeed.SS2)
	e.activation_locations = [Enums.ActivationLocation.HAND,
		Enums.ActivationLocation.FIELD_FACE_DOWN]
	e.damage_step(Enums.DamageStepPermission.NONE)
	e.targeting(1)
	e.legal_targets = func(ctx: EffectContext) -> Array:
		return EffectPrimitives.opponent_monsters(ctx, "", true)
	e.ruling("R25")
	return e


# ---------------------------------------------------------------------------
# Bullet 1 — "change that target's battle position"
# ---------------------------------------------------------------------------

func _change_position() -> EffectDef:
	var e := _as_quick_play(EffectDef.new("change_battle_position", CLAUSE_POSITION))

	e.resolve = func(ctx: EffectContext) -> void:
		var target := EffectPrimitives.surviving_target(ctx, Enums.Zone.MONSTER_ZONE)
		if target == null:
			ctx.log_note("the target is no longer on the field")
			return
		if not target.is_face_up():
			# Flipped face-down between activation and resolution. It is no longer the
			# thing the card named, so nothing happens — this effect does not Flip Summon
			# and does not turn a face-down monster face-up.
			ctx.log_note("the target is no longer face-up")
			return
		# A face-up monster is in exactly one of two positions, so "change" is the toggle.
		# BY EFFECT: the manual once-per-turn change is untouched. [S1 p.36]
		var to := SummonRules.opposite_face_up_position_of(target)
		ctx.state.set_battle_position(target, to, true, ctx.source.id)
		ctx.log_note("changed %s to %s" % [target.card_name(),
			"Defense Position" if to == Enums.Position.FACE_UP_DEFENSE else "Attack Position"])

	return e


# ---------------------------------------------------------------------------
# Bullet 2 — "Tribute 1 monster, then … take control of that target until the End Phase"
# ---------------------------------------------------------------------------

func _take_control() -> EffectDef:
	var e := _as_quick_play(EffectDef.new("tribute_and_take_control", CLAUSE_CONTROL))
	e.legal_targets = func(ctx: EffectContext) -> Array:
		return EffectPrimitives.exclude_required_tributes(ctx, EffectPrimitives.opponent_monsters(ctx, "", true))

	# "Tribute 1 monster" — a monster YOU control. Without one the bullet is not offered:
	# a cost that cannot be paid makes the activation illegal, not merely ineffective.
	e.condition = func(ctx: EffectContext) -> bool:
		return EffectPrimitives.can_pay_tribute_cost(ctx, _tribute_candidates(ctx), 1)

	e.pay_cost = func(ctx: EffectContext) -> bool:
		var paid := EffectPrimitives.pay_tribute_cost(ctx, _tribute_candidates(ctx), 1,
			"Tribute 1 monster for Enemy Controller")
		if paid.is_empty():
			return false
		EffectPrimitives.record_cost(ctx, "tributed", paid)
		return true

	e.resolve = func(ctx: EffectContext) -> void:
		# "until the End Phase" — a lease the rules layer expires, never a timer.
		EffectPrimitives.take_control_of_target(ctx,
			Enums.ControlDuration.UNTIL_END_PHASE, true)

	return e


## "Tribute 1 monster" is unrestricted beyond being a monster you control on the field.
## Enemy Controller itself is a Spell and can never be one of them.
func _tribute_candidates(ctx: EffectContext) -> Array:
	return EffectPrimitives.tribute_cost_candidates(ctx)
