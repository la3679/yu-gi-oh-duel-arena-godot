extends RefCounted

## Dragonic Tactics — Normal Spell.
##
## Official text (verified against the Konami card database, see
## Data/generated/konami_cards.json):
##
##   "Tribute 2 Dragon monsters; Special Summon 1 Level 8 Dragon monster from your Deck."
##
## Details this implementation accounts for:
##
##   1. The semicolon splits COST from EFFECT: "Tribute 2 Dragon monsters" is a **cost**,
##      paid at activation. Both Tributes happen then, not at resolution, and they stay
##      paid even if the effect is negated. RULES_SPEC.md 10, master prompt 16.
##   2. A Tribute is not a destruction; it IS "sent to the Graveyard" [S1 p.53]. That
##      distinction is what `MoveReason.TRIBUTED` carries.
##   3. The Tributes are monsters **you control** — the only monsters a player may ever
##      Tribute. Face-down monsters count: their controller knows what they are.
##   4. The Summon does **not** target: there is no "target" in the text and the Deck is
##      hidden information, so the monster is chosen at RESOLUTION. RULES_SPEC.md 10.
##   5. "Level 8 Dragon monster" is an exact Level and the Dragon race. In this pool that
##      is "Blue-Eyes White Dragon" and "Rabidragon"; the Level 7 "Metaphys Armed Dragon"
##      is a **Wyrm** and never qualifies.
##   6. No position is named, so the summoning player chooses. RULES_SPEC.md 5.5.
##   7. Looking through the Deck requires shuffling it afterwards. [S1 p.5]
##
## Tributing two monsters always frees two Monster Zones, so a free zone is not a
## separate activation requirement; it is still re-checked at resolution.

const CARD_NAME := "Dragonic Tactics"

const CLAUSE := "Tribute 2 Dragon monsters; Special Summon 1 Level 8 Dragon monster " \
	+ "from your Deck."

const TRIBUTES_REQUIRED := 2


func effects() -> Array:
	var tactics := EffectDef.new("tribute_two_dragons_summon_level_8", CLAUSE)
	tactics.of_type(Enums.EffectType.CARD_ACTIVATION)
	tactics.activation_locations = [Enums.ActivationLocation.HAND,
		Enums.ActivationLocation.FIELD_FACE_DOWN]

	var any_dragon := EffectPrimitives.monster_filter("", -1, -1, "Dragon")
	var level_8_dragon := EffectPrimitives.monster_of_level(8, "Dragon")

	tactics.condition = func(ctx: EffectContext) -> bool:
		return not EffectPrimitives.own_cards_in(ctx, Enums.Zone.DECK,
			level_8_dragon).is_empty()

	tactics.can_pay_cost = func(ctx: EffectContext) -> bool:
		return EffectPrimitives.own_cards_in(ctx, Enums.Zone.MONSTER_ZONE,
			any_dragon).size() >= TRIBUTES_REQUIRED

	tactics.pay_cost = func(ctx: EffectContext) -> bool:
		var candidates := EffectPrimitives.own_cards_in(ctx, Enums.Zone.MONSTER_ZONE,
			any_dragon)
		var paid := EffectPrimitives.pay_tribute_cost(ctx, candidates, TRIBUTES_REQUIRED,
			"Tribute 2 Dragon monsters")
		if paid.size() != TRIBUTES_REQUIRED:
			return false
		EffectPrimitives.record_cost(ctx, "tributed", paid)
		return true

	tactics.resolve = func(ctx: EffectContext) -> void:
		var candidates := EffectPrimitives.own_cards_in(ctx, Enums.Zone.DECK,
			level_8_dragon)
		var summoned := EffectPrimitives.special_summon_one_any_position(ctx, candidates,
			"Special Summon 1 Level 8 Dragon monster from your Deck")
		if summoned != null:
			ctx.log_note("Special Summoned %s" % summoned.card_name())
		# "If a card effect requires you to reveal cards from your Deck, or look through
		# it, shuffle it and put it back." [S1 p.5]
		ctx.state.shuffle_deck(ctx.controller_id)

	return [tactics]
