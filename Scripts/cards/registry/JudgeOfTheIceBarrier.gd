extends RefCounted

## Judge of the Ice Barrier — WATER / Warrior / Level 4 / 1800 ATK / 900 DEF.
##
## Official text (verified against the Konami card database, cid 15981):
##
##   "While you control another "Ice Barrier" monster, each time your opponent activates a
##    card or effect by paying LP, they lose 500 LP. You can only use each of the following
##    effects of "Judge of the Ice Barrier" once per turn. You can target 1 or 2 "Ice
##    Barrier" monsters in your GY and 1 or 2 cards in your opponent's GY; shuffle them into
##    the Deck. If you control an "Ice Barrier" monster: You can banish this card from your
##    GY, then target 1 Attack Position monster on the field; change it to Defense Position."
##
## Research/CARD_RULINGS.md **R2**, and the LP half is Research/CARD_RULINGS.md **R31**.
##
## THREE effect clauses, plus a restriction sentence that governs two of them. All three are
## implemented in full even though R2 records that all three are essentially never live:
## Judge is the only "Ice Barrier" card in either deck, so nothing can satisfy "another 'Ice
## Barrier' monster" or "an 'Ice Barrier' monster" in a real duel, and clause 2 has no
## legal "Ice Barrier" monster to find in the Graveyard either. They are tested against
## SYNTHETIC "Ice Barrier" monsters, with a real-pool assertion that no printed card can
## satisfy them — the same treatment R21 (`Apprentice Magician`) and R23 (`Fairy Tail -
## Rella`) established, so the fact cannot rot silently.
##
## Details this implementation accounts for:
##
##   1. **Clause 1 is CONTINUOUS, not a Trigger Effect.** "Each time … they lose 500 LP"
##      applies the instant the event happens, puts no link on the Chain, and is never
##      offered as a choice. RULES_SPEC.md 4.3 records that paying a cost is not an
##      activation and cannot be chained to, which is why it could not be a trigger. It is
##      `EffectDef.respond_to_event` + `ContinuousEffects.respond_to()`, added as its own
##      generic unit before this card and gated by `LifePointCostTests`.
##   2. **"by paying LP" is read from the ACTIVATION, never from an LP delta.** Effect
##      damage, battle damage, an arbitrary LP loss and LP GAIN must all be invisible to it.
##      `EffectPrimitives.cost_event_paid_life_points()` is the only supported question, and
##      it reads the cost payload the activation recorded. RULES_SPEC.md 10.4.
##   3. **"another"** excludes Judge itself — `exclude_id` on the archetype query. A lone
##      Judge does not switch its own clause on, and that is asserted.
##   4. **The restriction sentence governs clauses 2 and 3 SEPARATELY.** "You can only use
##      EACH of the following effects … once per turn" is `opt_named_effect()` on each, per
##      player + name + effect id — not `opt_instance()`, and not one shared key, which
##      would wrongly let using one lock the other.
##   5. **Clause 2's target set is heterogeneous**, so membership in `legal_targets` plus a
##      count cannot express it: 1-2 from YOUR Graveyard that are "Ice Barrier" monsters,
##      AND 1-2 from your OPPONENT'S Graveyard that may be any card. Both groups are
##      required ("and"), so the legal totals are 2, 3 or 4. That is `EffectDef.targets_valid`
##      — the batch-5 mechanism, whose only previous consumer was `Kunai with Chain`.
##   6. **Clause 3's banish is a COST**, not part of the effect: it sits before "then
##      target". `pay_banish_cost()` in `pay_cost`, never in `resolve`, and it is not
##      refunded when the effect is negated.
##   7. **R2 fixes one sub-question: Judge sitting in the GY does NOT satisfy "if you
##      control an 'Ice Barrier' monster".** The Graveyard is not "control", so clause 3
##      needs a DIFFERENT "Ice Barrier" monster on the field. Asserted directly as a
##      negative, because it is the trap this clause invites.
##   8. Clause 3 targets "1 Attack Position monster on the field" — **either player's**, and
##      only a FACE-UP ATTACK one, since a face-down monster is in Defense Position and a
##      face-up Defense one is already where the effect would put it.

const CARD_NAME := "Judge of the Ice Barrier"

const ARCHETYPE := "Ice Barrier"
const LP_LOSS := 500

const CLAUSE_LP_TAX := "While you control another \"Ice Barrier\" monster, each time your " \
	+ "opponent activates a card or effect by paying LP, they lose 500 LP."
const CLAUSE_SHUFFLE := "You can target 1 or 2 \"Ice Barrier\" monsters in your GY and 1 " \
	+ "or 2 cards in your opponent's GY; shuffle them into the Deck."
const CLAUSE_POSITION := "If you control an \"Ice Barrier\" monster: You can banish this " \
	+ "card from your GY, then target 1 Attack Position monster on the field; change it " \
	+ "to Defense Position."


func effects() -> Array:
	return [_life_point_tax(), _shuffle_graveyards(), _change_to_defense()]


# ---------------------------------------------------------------------------
# Clause 1 — the continuous LP tax.
# ---------------------------------------------------------------------------

func _life_point_tax() -> EffectDef:
	var e := EffectDef.new("lp_tax_on_opponent_payment", CLAUSE_LP_TAX)
	e.of_type(Enums.EffectType.CONTINUOUS)
	e.on_events([GameEvent.Kind.COST_PAID])
	e.ruling("R2")

	e.condition = func(ctx: EffectContext) -> bool:
		# "While you control ANOTHER 'Ice Barrier' monster" — Judge does not count itself.
		if not EffectPrimitives.controls_archetype_monster(ctx, ARCHETYPE,
				ctx.controller_id, ctx.source.id):
			return false
		# "your OPPONENT activates a card or effect BY PAYING LP". Read from the activation's
		# own cost payload; an LP delta of any other kind is not a payment.
		return EffectPrimitives.cost_event_paid_life_points(ctx.trigger_event,
			ctx.opponent_id())

	e.respond_to_event = func(ctx: EffectContext) -> void:
		# "they lose 500 LP" — the opponent, and it is a LOSS, not effect damage. Nothing
		# here starts a Chain; this is the continuous effect applying.
		ctx.state.change_life_points(ctx.opponent_id(), -LP_LOSS, CARD_NAME, ctx.source.id)
		# An LP loss can end the Duel, and `change_life_points()` deliberately does not
		# decide that for itself — the caller does, exactly as the battle path does.
		ctx.state.check_life_point_loss()

	return e


# ---------------------------------------------------------------------------
# Clause 2 — shuffle from both Graveyards.
# ---------------------------------------------------------------------------

func _shuffle_graveyards() -> EffectDef:
	var e := EffectDef.new("shuffle_from_graveyards", CLAUSE_SHUFFLE)
	e.of_type(Enums.EffectType.IGNITION)
	e.from_locations([Enums.ActivationLocation.FIELD_FACE_UP])
	# 1-2 from each of two required groups, so 2, 3 or 4 targets in total.
	e.targeting(2, 4)
	e.opt_named_effect()
	e.ruling("R2")

	e.condition = func(ctx: EffectContext) -> bool:
		return not _own_ice_barrier_gy(ctx).is_empty() \
			and not _opponent_gy(ctx).is_empty()

	e.legal_targets = func(ctx: EffectContext) -> Array:
		var out := _own_ice_barrier_gy(ctx)
		out.append_array(_opponent_gy(ctx))
		return out

	# Membership plus a count cannot express "1 or 2 from HERE and 1 or 2 from THERE".
	e.targets_valid = func(ctx: EffectContext, chosen: Array) -> bool:
		var mine := 0
		var theirs := 0
		for entry in chosen:
			var card: CardInstance = entry
			if card == null or card.zone != Enums.Zone.GRAVEYARD:
				return false
			if card.owner_id == ctx.controller_id:
				if not EffectPrimitives.name_matches_archetype(card, ARCHETYPE):
					return false
				if not card.is_monster():
					return false
				mine += 1
			else:
				theirs += 1
		# "and" — both groups are required, 1 or 2 from each.
		return mine >= 1 and mine <= 2 and theirs >= 1 and theirs <= 2

	e.resolve = func(ctx: EffectContext) -> void:
		# Re-check at resolution: anything that left the Graveyard in the meantime is
		# simply not shuffled. RULES_SPEC.md 10.
		var moved := 0
		for entry in ctx.targets():
			var card: CardInstance = entry
			if card == null or card.zone != Enums.Zone.GRAVEYARD:
				continue
			if EffectPrimitives.shuffle_into_deck(ctx, card):
				moved += 1
		if moved == 0:
			ctx.log_note("no targeted card was still in a Graveyard")
			return
		ctx.log_note("shuffled %d card(s) into the Deck" % moved)

	return e


# ---------------------------------------------------------------------------
# Clause 3 — banish this card from the GY to force Defense Position.
# ---------------------------------------------------------------------------

func _change_to_defense() -> EffectDef:
	var e := EffectDef.new("banish_self_change_to_defense", CLAUSE_POSITION)
	e.of_type(Enums.EffectType.IGNITION)
	e.from_locations([Enums.ActivationLocation.GRAVEYARD])
	e.targeting(1, 1)
	e.opt_named_effect()
	e.ruling("R2")

	e.condition = func(ctx: EffectContext) -> bool:
		# "If you control an 'Ice Barrier' monster" — R2: Judge itself is in the GRAVEYARD
		# and the GY is not "control", so this needs a different one on the field.
		return EffectPrimitives.controls_archetype_monster(ctx, ARCHETYPE, ctx.controller_id)

	e.legal_targets = func(ctx: EffectContext) -> Array:
		return _attack_position_monsters(ctx)

	e.can_pay_cost = func(ctx: EffectContext) -> bool:
		return ctx.source.zone == Enums.Zone.GRAVEYARD

	e.pay_cost = func(ctx: EffectContext) -> bool:
		# "banish this card from your GY" sits before "then target", so it is a COST: paid at
		# activation and never refunded if the effect is later negated.
		var paid := EffectPrimitives.pay_banish_cost(ctx, [ctx.source], 1,
			"Banish Judge of the Ice Barrier from your Graveyard")
		if paid.is_empty():
			return false
		EffectPrimitives.record_cost(ctx, EffectPrimitives.COST_CARDS_KEY, paid)
		return true

	e.resolve = func(ctx: EffectContext) -> void:
		var target := EffectPrimitives.surviving_field_target(ctx)
		if target == null:
			ctx.log_note("the target is no longer on the field")
			return
		# "change it to Defense Position" — only meaningful while it is still in Attack
		# Position. A monster that has since been flipped face-down or is already in Defense
		# is left exactly as it is.
		if target.position != Enums.Position.FACE_UP_ATTACK:
			ctx.log_note("the target is no longer in Attack Position")
			return
		ctx.state.set_battle_position(target, Enums.Position.FACE_UP_DEFENSE, true,
			ctx.source.id)
		ctx.log_note("changed %s to Defense Position" % target.card_name())

	return e


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

static func _own_ice_barrier_gy(ctx: EffectContext) -> Array:
	return EffectPrimitives.cards_in(ctx, ctx.controller_id, Enums.Zone.GRAVEYARD,
		EffectPrimitives.archetype_monster(ARCHETYPE))


## "1 or 2 CARDS in your opponent's GY" — any card, not only a monster.
static func _opponent_gy(ctx: EffectContext) -> Array:
	return EffectPrimitives.cards_in(ctx, ctx.opponent_id(), Enums.Zone.GRAVEYARD,
		func(_card: CardInstance) -> bool: return true)


## "1 Attack Position monster on the field" — either player's, face-up Attack only.
static func _attack_position_monsters(ctx: EffectContext) -> Array:
	var out: Array = []
	for entry in EffectPrimitives.cards_on_field(ctx, true):
		var card: CardInstance = entry
		if card.position == Enums.Position.FACE_UP_ATTACK:
			out.append(card)
	return out
