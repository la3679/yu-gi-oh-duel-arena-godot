extends RefCounted

## Crystal Seer — Level 1 WATER Spellcaster Flip Effect Monster, 100 / 100.
##
## Official text (verified against the Konami card database, cid 7208; see
## Data/generated/konami_cards.json):
##
##   "FLIP: Excavate the top 2 cards of your Deck, then add 1 of them to your hand, then
##    place the other on the bottom of your Deck."
##
## The first card in the V1 pool to use the excavation layer at all. The generic behaviour
## is `GameState.excavate()` and was built and tested by batch 7 unit A (`MovementTests`)
## before this card existed; this file is the card, not the mechanic.
##
## Details this implementation accounts for:
##
##   1. **It is a FLIP effect, not a Flip-Summon effect.** It fires whenever the card is
##      turned face-up — Flip Summoned, flipped by an attacking monster, or flipped by a card
##      effect. Keying it on `FLIP_SUMMON_SUCCEEDED` would silently lose two of the three.
##      `CARD_FLIPPED_FACE_UP`, the shape the three Charmers use. RULES_SPEC.md §5.4.
##   2. **It is MANDATORY.** There is no "You can" anywhere in the text.
##   3. **An EXCAVATE is not a DRAW.** The cards come off the Deck into `Zone.EXCAVATED`,
##      no `CARD_DRAWN` event is emitted, nothing keyed on a draw may fire, and a Deck that
##      runs out does NOT lose the Duel [S1 p.35 is about drawing]. RULES_SPEC.md §8.2.
##   4. **An EXCAVATE is not a SEARCH either.** A search looks THROUGH the Deck, is private,
##      and ends in a shuffle [S1 p.5]. This takes the top 2 in order, shows them to BOTH
##      players, and shuffles nothing.
##   5. **Fewer than 2 cards left excavates fewer.** With 1 card the player excavates 1, adds
##      it to the hand and has nothing left to place; with 0 the effect resolves and does
##      nothing. `EffectPrimitives.excavate()` returns the short array rather than failing.
##   6. **The player chooses WHICH one goes to the hand.** The text says "add 1 of them",
##      not "add the first", so it is a real resolution-time choice and is logged like every
##      other duel input (design decision 17). With exactly one candidate `choose_one()`
##      correctly asks nothing.
##   7. **"place the other on the bottom of your Deck" — no shuffle.** The text says
##      "place", so the remaining card KEEPS `revealed_to` and both players are still
##      entitled to know it is the bottom card. This is the printed-card exercise of design
##      decision 11's "keeps it" branch and is asserted directly. RULES_SPEC.md §12.1.
##   8. **"your Deck" is this card's controller's Deck**, and `GameState.move_card()` sends a
##      card to its OWNER's Deck — which for a card excavated from that same Deck is the
##      same player. Nothing here may pass a `to_player`.
##   9. **Every excavated card must be placed.** An excavate leaves nothing in limbo:
##      whatever is not added to the hand goes to the bottom.

const CARD_NAME := "Crystal Seer"

const CLAUSE := "FLIP: Excavate the top 2 cards of your Deck, then add 1 of them to your " \
	+ "hand, then place the other on the bottom of your Deck."

const EXCAVATE_COUNT := 2


func effects() -> Array:
	var e := EffectDef.new("flip_excavate_two_add_one", CLAUSE)
	e.of_type(Enums.EffectType.FLIP)
	# No "You can": MANDATORY. It is never offered as a consent question.
	e.mandatory()
	e.trigger_events = [GameEvent.Kind.CARD_FLIPPED_FACE_UP]
	e.activation_locations = [Enums.ActivationLocation.FIELD_FACE_UP]
	# Flipped face-up by an attacker, a Flip effect becomes a Chain Link in Damage Step
	# sub-step 4, so the Damage Step permission is the rules-mandated TIMING, not a statement
	# about optionality. RULES_SPEC.md §7.2, design decision 5.
	e.damage_step_permission = Enums.DamageStepPermission.MANDATORY_TRIGGER

	e.condition = func(ctx: EffectContext) -> bool:
		# THIS card being flipped face-up, not any card.
		var ev: GameEvent = ctx.trigger_event
		return ev != null and int(ev.data.get("card_id", -1)) == ctx.source.id

	e.resolve = func(ctx: EffectContext) -> void:
		var taken := EffectPrimitives.excavate(ctx, EXCAVATE_COUNT)
		if taken.is_empty():
			# An empty Deck is a legitimate resolution of nothing. It is NOT a deck-out:
			# excavating is not drawing. RULES_SPEC.md §8.2.
			ctx.log_note("no cards left in the Deck to excavate")
			return

		var chosen := EffectPrimitives.choose_one(ctx, taken,
			"Add 1 of the excavated cards to your hand")
		if chosen == null:
			# Unreachable with a non-empty array, but an excavate must never leave a card in
			# limbo, so the remainder is still placed.
			EffectPrimitives.return_excavated(ctx, taken, true)
			ctx.log_note("no card could be chosen; the excavated cards went to the bottom")
			return

		EffectPrimitives.add_to_hand(ctx, chosen)

		# "the other" — everything excavated that was not added to the hand, in the order it
		# came off the Deck. No shuffle: the text says "place".
		var rest: Array = []
		for entry in taken:
			var card: CardInstance = entry
			if card != chosen:
				rest.append(card)
		var placed := EffectPrimitives.return_excavated(ctx, rest, true)

		ctx.log_note("excavated %d, added %s to the hand, placed %d on the bottom of the Deck"
			% [taken.size(), chosen.card_name(), placed])

	return [e]
