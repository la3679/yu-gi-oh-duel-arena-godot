extends RefCounted

## Fairy Tail - Rella — LIGHT / Spellcaster / Level 4 / 1850 ATK / 1000 DEF.
##
## Official text (verified against the Konami card database, see
## Data/generated/konami_cards.json):
##
##   "Neither player can target monsters on the field with Spell Cards or effects, except
##    this one. Once per turn: You can discard 1 Spell; equip 1 Equip Spell from your hand,
##    Deck, or GY to this card, but return that Equip Spell to the hand during the End
##    Phase."
##
## Two printed clauses. The earlier planning notes for this batch described the first as
## "targeting protection / redirect"; the verified official text contains **no redirect**.
## It is a flat CONTINUOUS restriction and is implemented as exactly that — the official
## text is the authority. Research/CARD_RULINGS.md R23.
##
## Clause 1 — "Neither player can target monsters on the field …, except this one"
##   * NEITHER player: it restricts its own controller too, not just the opponent.
##   * "monsters ON THE FIELD": a monster in a Graveyard is not on the field, so a clause
##     like `Monster Reborn`'s "target 1 monster in either GY" is untouched.
##   * "except this one": Rella itself stays targetable. The exception is what makes the
##     card answerable rather than an unconditional lock.
##   * "with Spell Cards or effects" is card targeting, which in this engine funnels through
##     `ActivationRules.legal_targets()`. It is deliberately NOT attack targeting: an attack
##     is neither a Spell Card nor an effect, and `BattleRules` builds its own list
##     [S1 p.38].
##   * It is implemented by setting the system-owned `cannot_be_targeted` flag on every
##     other monster on the field, through `ContinuousEffects.restrict()`. That flag is
##     wiped and rebuilt on every recompute, so the protection switches off by itself when
##     Rella leaves, is flipped face-down or is negated — which is the whole point of the
##     continuous system. Nothing here writes a flag directly.
##
## Clause 2 — "Once per turn: You can discard 1 Spell; equip 1 Equip Spell …"
##   * An IGNITION Effect: its controller activates it in an open game state on their own
##     turn. "Once per turn" with no "you can only use this effect of …" is a SOFT once per
##     turn on this copy, which is `once_per_turn_instance`.
##   * "discard 1 Spell" is a COST — the semicolon before "equip" is what marks it. It is a
##     DISCARD, not a "send from your hand to the GY": PSCT distinguishes the two and so
##     does `EffectPrimitives.pay_discard_cost()`.
##   * It does NOT target, so the Equip Spell is chosen at RESOLUTION.
##   * "from your hand, Deck, or GY" is three zones, and an Equip Spell discarded to pay the
##     cost lands in the GY and legitimately becomes a candidate for the effect it paid for.
##   * Following the reading this project already applies to `Shining Angel`, `Kaibaman` and
##     `Dragonic Tactics`: an effect that must fetch a specific kind of card cannot be
##     activated when no such card exists in any of the listed zones.
##   * **There are no Equip Spells at all in the V1 card pool**, so this clause can never be
##     activated in a real duel between these two Decks. That is reported honestly and the
##     clause is exercised against synthetic Equip Spells instead. R23.
##   * "but return that Equip Spell to the hand during the End Phase" is a DELAYED clause
##     with its own timing, so it is its own EffectDef — three EffectDefs for two printed
##     clauses. PROJECT_STATE.md design decision 29.

const CARD_NAME := "Fairy Tail - Rella"

const CLAUSE_PROTECT := "Neither player can target monsters on the field with Spell Cards " \
	+ "or effects, except this one."
const CLAUSE_EQUIP := "Once per turn: You can discard 1 Spell; equip 1 Equip Spell from " \
	+ "your hand, Deck, or GY to this card, but return that Equip Spell to the hand " \
	+ "during the End Phase."
const CLAUSE_RETURN := "…but return that Equip Spell to the hand during the End Phase."


func effects() -> Array:
	return [_targeting_protection(), _equip_from_anywhere(), _return_during_end_phase()]


# ---------------------------------------------------------------------------
# Clause 1 — the targeting restriction
# ---------------------------------------------------------------------------

func _targeting_protection() -> EffectDef:
	var e := EffectDef.new("no_targeting_except_this_one", CLAUSE_PROTECT)
	e.of_type(Enums.EffectType.CONTINUOUS)
	e.ruling("R23")

	e.apply_continuous = func(ctx: EffectContext) -> void:
		# "Neither player" — both sides of the field, including this card's own controller.
		for p in ctx.state.players:
			for entry in (p as PlayerState).monsters():
				var monster: CardInstance = entry
				if monster == null or monster == ctx.source:
					continue  # "except this one"
				ContinuousEffects.restrict(monster, "cannot_be_targeted")

	return e


# ---------------------------------------------------------------------------
# Clause 2 — the Equip Spell
# ---------------------------------------------------------------------------

func _equip_from_anywhere() -> EffectDef:
	var e := EffectDef.new("equip_an_equip_spell_to_this_card", CLAUSE_EQUIP)
	e.of_type(Enums.EffectType.IGNITION)
	e.opt_instance()
	e.activation_locations = [Enums.ActivationLocation.FIELD_FACE_UP]
	e.in_phases([Enums.Phase.MAIN_1, Enums.Phase.MAIN_2])
	e.ruling("R23")

	var is_spell := EffectPrimitives.spell_card()
	var is_equip_spell := EffectPrimitives.equip_spell_card()

	# "from your hand, Deck, or GY" — three zones, in the printed order, so the option list
	# a player sees is stable.
	var equip_candidates := func(ctx: EffectContext) -> Array:
		var out: Array = []
		out.append_array(EffectPrimitives.own_cards_in(ctx, Enums.Zone.HAND, is_equip_spell))
		out.append_array(EffectPrimitives.own_cards_in(ctx, Enums.Zone.DECK, is_equip_spell))
		out.append_array(
			EffectPrimitives.own_cards_in(ctx, Enums.Zone.GRAVEYARD, is_equip_spell))
		return out

	e.condition = func(ctx: EffectContext) -> bool:
		# An Equip Card needs a Spell & Trap Zone of its own [S1 p.29], unless it is already
		# in one, which none of the three source zones is.
		if not ctx.me().has_free_spell_trap_zone():
			return false
		return not (equip_candidates.call(ctx) as Array).is_empty()

	e.can_pay_cost = func(ctx: EffectContext) -> bool:
		return not EffectPrimitives.own_cards_in(ctx, Enums.Zone.HAND, is_spell).is_empty()

	e.pay_cost = func(ctx: EffectContext) -> bool:
		var candidates := EffectPrimitives.own_cards_in(ctx, Enums.Zone.HAND, is_spell)
		var paid := EffectPrimitives.pay_discard_cost(ctx, candidates, 1,
			"Discard 1 Spell to use the effect of %s" % ctx.source.card_name())
		if paid.is_empty():
			return false
		EffectPrimitives.record_cost(ctx, EffectPrimitives.COST_CARDS_KEY, paid)
		return true

	e.resolve = func(ctx: EffectContext) -> void:
		# The clause names no target, so the choice happens here — after the cost, which is
		# why an Equip Spell discarded to pay it is a legal candidate from the Graveyard.
		var candidates: Array = equip_candidates.call(ctx)
		var chosen := EffectPrimitives.choose_one(ctx, candidates,
			"Equip 1 Equip Spell from your hand, Deck, or GY to %s"
			% ctx.source.card_name())
		# The Deck is one of the zones this clause looks through. [S1 p.5]
		ctx.state.shuffle_deck(ctx.controller_id)
		if chosen == null:
			ctx.log_note("no Equip Spell to equip")
			return
		var equipped := EffectPrimitives.equip_card_to_source(ctx, chosen)
		if equipped == null:
			return
		# "but return that Equip Spell to the hand during the End Phase" — remember WHICH
		# card and WHEN, so the delayed clause below returns that one and only this turn.
		EffectPrimitives.link_equipped_by_effect(ctx, equipped)
		ctx.log_note("equipped %s" % equipped.card_name())

	return e


# ---------------------------------------------------------------------------
# The delayed half of clause 2
# ---------------------------------------------------------------------------

func _return_during_end_phase() -> EffectDef:
	var e := EffectDef.new("return_the_equip_spell_in_the_end_phase", CLAUSE_RETURN)
	e.of_type(Enums.EffectType.TRIGGER)
	e.mandatory()
	e.activation_locations = [Enums.ActivationLocation.FIELD_FACE_UP]
	e.trigger_events = [GameEvent.Kind.PHASE_CHANGED]
	e.ruling("R23")

	e.condition = func(ctx: EffectContext) -> bool:
		if not EffectPrimitives.event_is_phase_change_to(ctx.trigger_event,
				Enums.Phase.END, ctx.controller_id):
			return false
		# "during the End Phase" means the End Phase of the turn it was equipped, which is
		# always this card's controller's own turn — the clause that equipped it is an
		# Ignition Effect and only the turn player may use one.
		var equipped := EffectPrimitives.equipped_by_effect(ctx)
		if equipped == null:
			return false
		return EffectPrimitives.equipped_by_effect_turn(ctx) == ctx.state.turn_number

	e.resolve = func(ctx: EffectContext) -> void:
		var equipped := EffectPrimitives.equipped_by_effect(ctx)
		EffectPrimitives.clear_equipped_by_effect_link(ctx)
		if equipped == null or not equipped.is_on_field():
			ctx.log_note("that Equip Spell is no longer on the field")
			return
		# "to THE hand" — a card always returns to its OWNER's hand [S1 p.52].
		if ctx.state.move_card(equipped, Enums.Zone.HAND,
				Enums.MoveReason.RETURNED_TO_HAND,
				{"to_player": equipped.owner_id, "source_id": ctx.source.id}):
			ctx.log_note("returned %s to the hand" % equipped.card_name())

	return e
