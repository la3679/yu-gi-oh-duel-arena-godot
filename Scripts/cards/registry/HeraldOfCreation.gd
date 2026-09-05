extends RefCounted

## Herald of Creation — LIGHT / Spellcaster / Level 4 / 1800 ATK / 600 DEF.
##
## Official text (verified against the Konami card database, cid 7246; see
## Data/generated/konami_cards.json):
##
##   "Once per turn: You can discard 1 card, then target 1 Level 7 or higher monster in
##    your Graveyard; add that target to your hand."
##
## Details this implementation accounts for, all four confirmed by the official supplement
## (cid 7246, 2015-03-21):
##
##   1. **It is an IGNITION effect activatable in the Monster Zone** — the supplement says
##      so in as many words. Not a Trigger, not a Quick Effect: Spell Speed 1, the turn
##      player's own Main Phase, from `FIELD_FACE_UP`.
##   2. **The discard is a COST.** It stands before "then target", and the supplement
##      confirms it. `pay_cost`, never `resolve`, and never refunded when the activation is
##      negated [S1 p.53, "Pay a Cost"]. It is `MoveReason.DISCARDED`, not a send.
##   3. **The cost is UNQUALIFIED** — "discard 1 card", any card, including a Spell or a
##      Trap. `Divine Dragon Apocralyph` has the same unqualified cost; the two cards differ
##      only in their target predicate, and they share no code beyond the primitives.
##   4. **It cannot be activated unless a legal target already exists in the GY** — the
##      supplement states this too. That is ordinary targeting and needs no special code:
##      an empty `legal_targets` already makes the activation illegal. It is asserted
##      anyway, because it is the only thing standing between this card and a cost paid for
##      nothing.
##   5. **"Level 7 or higher" is a FLOOR.** `monster_of_level_at_least(7)`, added by the
##      batch-10 unit — deliberately not `monster_of_level` (an exact match) and not
##      `monster_filter`'s `max_level` (a ceiling). Reading it with either of the two
##      existing helpers would have been silently wrong rather than loud.
##   6. **"Once per turn" with NO card name printed is `opt_instance()`** — a limit on this
##      copy, not on the name. RULES_SPEC.md 11.
##   7. **"your Graveyard"** — the controller's own GY only. The opponent's Level 7+
##      monsters are never targets, and that negative is asserted.
##   8. The supplement also notes that a Level 7+ **Fusion or Synchro** monster in the GY
##      may be targeted, and would go to the **Extra Deck** rather than the hand. Both Extra
##      Decks are empty in V1 and the pool has no Extra Deck monsters at all, so that branch
##      is **never live**. It is asserted as impossible rather than implemented as a branch
##      that can never run — the R21 / R23 treatment.
##   9. In deck 1 the live targets are `Blue-Eyes White Dragon` and `Rabidragon`, the only
##      Level 7-or-higher monsters in that deck.

const CARD_NAME := "Herald of Creation"

const CLAUSE := "Once per turn: You can discard 1 card, then target 1 Level 7 or higher " \
	+ "monster in your Graveyard; add that target to your hand."

const MINIMUM_LEVEL := 7


func effects() -> Array:
	var e := EffectDef.new("discard_to_retrieve_level_7", CLAUSE)
	e.of_type(Enums.EffectType.IGNITION)
	e.activation_locations = [Enums.ActivationLocation.FIELD_FACE_UP]
	e.targeting(1)
	# "Once per turn", with no card name printed: this copy, not the name.
	e.opt_instance()

	var big := EffectPrimitives.monster_of_level_at_least(MINIMUM_LEVEL)

	e.legal_targets = func(ctx: EffectContext) -> Array:
		return EffectPrimitives.own_cards_in(ctx, Enums.Zone.GRAVEYARD, big)

	e.can_pay_cost = func(ctx: EffectContext) -> bool:
		# "Discard 1 card" is unqualified, but the discard comes from the HAND and this
		# card is on the FIELD, so it can never pay for itself.
		return not EffectPrimitives.own_cards_in(ctx, Enums.Zone.HAND,
			Callable()).is_empty()

	e.pay_cost = func(ctx: EffectContext) -> bool:
		var candidates := EffectPrimitives.own_cards_in(ctx, Enums.Zone.HAND, Callable())
		var paid := EffectPrimitives.pay_discard_cost(ctx, candidates, 1, "Discard 1 card")
		if paid.is_empty():
			return false
		EffectPrimitives.record_cost(ctx, "discarded", paid)
		return true

	e.resolve = func(ctx: EffectContext) -> void:
		var target := EffectPrimitives.surviving_target(ctx, Enums.Zone.GRAVEYARD)
		if target == null:
			# The target left the Graveyard between activation and resolution. The cost is
			# still spent - that is what a cost is.
			ctx.log_note("the target is no longer in the Graveyard")
			return
		if EffectPrimitives.add_to_hand(ctx, target):
			ctx.log_note("added %s to the hand" % target.card_name())

	return [e]
