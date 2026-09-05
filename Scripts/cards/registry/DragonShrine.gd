extends RefCounted

## Dragon Shrine — Normal Spell.
##
## Official text (verified against the Konami card database, cid 10590; see
## Data/generated/konami_cards.json):
##
##   "Send 1 Dragon monster from your Deck to the GY, then, if that monster in your GY is a
##    Dragon Normal Monster, you can send 1 more Dragon monster from your Deck to the GY.
##    You can only activate 1 'Dragon Shrine' per turn."
##
## The pool's only MILL, and the card the batch-10 `send_from_deck_to_gy()` primitive exists
## for. The generic behaviour is `DeckAccessTests`; this file is the card.
##
## Every detail below is fixed by the official supplement (cid 10590, dated 2024-03-23) and
## its two Q&As, and none of it was guessed:
##
##   1. **The two sends are SEQUENTIAL and explicitly NOT simultaneous.** The supplement
##      says the first send is performed, and only if it SUCCEEDED in sending a Dragon
##      Normal Monster may the second be performed. fid 22194 (2022-12-30) confirms the
##      consequence: a card sent by the SECOND send did not see the first one arrive.
##   2. **The second send is OPTIONAL** — "you CAN send 1 more". `EffectPrimitives.may()`,
##      the optional-step-inside-a-resolution primitive batch 9 added. It is a real question
##      put to the controller, never fired silently (master prompt 24).
##   3. **The Normal-Monster test reads the monster AS IT NOW SITS IN THE GRAVEYARD**, not
##      its printed identity. fid 12831 (2026-06-26) answers "yes, you can" for a card that
##      is merely *treated as* a Normal Monster while in the GY. Nothing in the V1 pool is
##      treated-as, so the two readings coincide here — the implementation reads the GY
##      anyway, because that is what is correct, and `CardInstance.is_normal_monster()` is
##      already the per-copy question rather than the printed one.
##   4. **At most TWO are ever sent.** A Dragon Normal Monster sent by the SECOND send does
##      not start a third — the supplement states the cap outright. There is no loop here,
##      and the suite asserts the cap directly.
##   5. **Both sends are the EFFECT, not a cost.** Nothing precedes a semicolon; the whole
##      sentence is the resolution. So a negated activation sends nothing at all.
##   6. **"You can only activate 1 'Dragon Shrine' per turn" is `opt_named_activation()`** —
##      a limit on ACTIVATING the card, per player and per name. It is a different
##      restriction from `opt_named_effect()` and must not be confused with it.
##      RULES_SPEC.md 11.
##   7. **It cannot be activated with no Dragon monster in the Deck.** [S1 p.53] states the
##      general search-activation restriction for adding to the hand and Special Summoning;
##      applying it to a Deck-to-GY send is an INFERENCE, recorded as such in R40 part B at
##      MEDIUM-HIGH, and not presented as an official ruling. It is applied because this
##      card's first send is mandatory and unconditional, so an activation with no Dragon in
##      the Deck could perform no part of its own resolution.
##   8. **Each send looks through the Deck, so each shuffles** [S1 p.5]. That is inside
##      `send_from_deck_to_gy()` and is not this card's business.
##   9. **This is the card that fills a Graveyard for the rest of deck 1.** The monsters it
##      sends land in the GY as a real `CARD_SENT_TO_GY`, so `The White Stone of Legend`
##      milled by it fires its own trigger, and `Divine Dragon Apocralyph` and
##      `Herald of Creation` can retrieve what it sent. All three interactions are tested.

const CARD_NAME := "Dragon Shrine"

const CLAUSE := "Send 1 Dragon monster from your Deck to the GY, then, if that monster " \
	+ "in your GY is a Dragon Normal Monster, you can send 1 more Dragon monster from " \
	+ "your Deck to the GY. You can only activate 1 \"Dragon Shrine\" per turn."

const REQUIRED_RACE := "Dragon"


func effects() -> Array:
	var e := EffectDef.new("send_dragon_then_maybe_one_more", CLAUSE)
	e.of_type(Enums.EffectType.CARD_ACTIVATION)
	e.activation_locations = [Enums.ActivationLocation.HAND,
		Enums.ActivationLocation.FIELD_FACE_DOWN]
	# "You can only ACTIVATE 1 per turn" — the activation, not the effect.
	e.opt_named_activation()

	var dragon := EffectPrimitives.monster_filter("", -1, -1, REQUIRED_RACE)

	e.condition = func(ctx: EffectContext) -> bool:
		return EffectPrimitives.can_search_deck(ctx, ctx.controller_id, dragon)

	e.resolve = func(ctx: EffectContext) -> void:
		var first := EffectPrimitives.send_from_deck_to_gy(ctx, ctx.controller_id, dragon,
			"Send 1 Dragon monster from your Deck to the GY")
		if first == null:
			# The Deck lost its last Dragon between activation and resolution.
			ctx.log_note("no Dragon monster left in the Deck to send")
			return
		ctx.log_note("sent %s to the Graveyard" % first.card_name())

		# "if THAT MONSTER IN YOUR GY is a Dragon Normal Monster" — asked of the card as it
		# now sits in the Graveyard (fid 12831), not of the printed card, and asked AFTER
		# the first send has actually happened (the two steps are not simultaneous).
		if first.zone != Enums.Zone.GRAVEYARD:
			ctx.log_note("the sent monster is no longer in the Graveyard")
			return
		if not (first.is_monster() and first.current_race() == REQUIRED_RACE
				and first.is_normal_monster()):
			ctx.log_note("%s is not a Dragon Normal Monster, so there is no second send"
				% first.card_name())
			return

		# "you CAN send 1 more" — a real optional step, asked at resolution.
		if not EffectPrimitives.may(ctx, "Send 1 more Dragon monster from your Deck to the GY?"):
			ctx.log_note("declined the second send")
			return
		var second := EffectPrimitives.send_from_deck_to_gy(ctx, ctx.controller_id, dragon,
			"Send 1 more Dragon monster from your Deck to the GY")
		if second == null:
			ctx.log_note("no second Dragon monster left in the Deck")
			return
		# The cap is TWO. A Dragon Normal Monster sent HERE does not start a third send.
		ctx.log_note("sent %s to the Graveyard as well" % second.card_name())

	return [e]
