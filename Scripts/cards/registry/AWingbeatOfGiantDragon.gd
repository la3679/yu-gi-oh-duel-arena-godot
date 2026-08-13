extends RefCounted

## A Wingbeat of Giant Dragon — Normal Spell.
##
## Official text (verified against the Konami card database, see
## Data/generated/konami_cards.json):
##
##   "Return 1 Level 5 or higher Dragon-Type monster you control to the hand, and if you
##    do, destroy all Spell and Trap Cards on the field."
##
## One clause, and five details that are easy to get wrong:
##
##   1. The return is **not a cost**. PSCT puts a cost before a semicolon, and this text
##      has neither a colon nor a semicolon — everything in it happens at RESOLUTION.
##      RULES_SPEC.md 10. That matters: the Dragon is chosen when the link resolves, so a
##      Dragon removed in response changes what this card can do, and a negated activation
##      returns nothing at all. Contrast `Dragonic Tactics`, whose two Tributes ARE a cost.
##   2. It does **not** target — no "target" appears. The Dragon is therefore chosen at
##      resolution, from whatever is legal then. RULES_SPEC.md 10.
##   3. "**and if you do**" makes the second half strictly conditional on the first. No
##      Dragon returned means no Spell/Trap destroyed — the two are not independent.
##   4. "all Spell and Trap Cards **on the field**" is BOTH players' Spell & Trap Zones
##      **and** both Field Zones — a Field Spell is a Spell Card on the field. It includes
##      this card's own controller's cards, and face-down Set cards. It does **not**
##      include this card itself, which is on the field while it resolves —
##      CARD_RULINGS.md R28.
##   5. Returning a monster to the hand is not a destruction and not a send to the
##      Graveyard [S1 p.52], so the Dragon's own "if this card is destroyed" clauses
##      (`Kaiser Glider` is in the same Deck) must not fire from it.
##
## **Activation requirement (CARD_RULINGS.md R27).** The card is only activatable while its
## controller has a Level 5 or higher Dragon monster to return. The first action of the
## effect is mandatory and definite, and "and if you do" makes every remaining word depend
## on it, so with no Dragon the card can do nothing at all.

const CARD_NAME := "A Wingbeat of Giant Dragon"

const CLAUSE := "Return 1 Level 5 or higher Dragon-Type monster you control to the hand, " \
	+ "and if you do, destroy all Spell and Trap Cards on the field."


## "1 Level 5 or higher Dragon-Type monster you control". Face-down monsters are excluded:
## Level and Type are properties a face-down monster does not present, the same reading
## `Champion's Vigilance` uses for "a Level 7 or higher Normal Monster".
static func _returnable_dragon() -> Callable:
	return func(card: CardInstance) -> bool:
		return card != null and card.definition != null and card.is_monster() \
			and card.is_face_up() \
			and card.definition.level >= 5 \
			and card.definition.race == "Dragon"


func effects() -> Array:
	var wingbeat := EffectDef.new("return_dragon_then_wipe_spell_traps", CLAUSE)
	wingbeat.of_type(Enums.EffectType.CARD_ACTIVATION)
	wingbeat.activation_locations = [Enums.ActivationLocation.HAND,
		Enums.ActivationLocation.FIELD_FACE_DOWN]

	var dragon := _returnable_dragon()

	wingbeat.condition = func(ctx: EffectContext) -> bool:
		return not EffectPrimitives.own_cards_in(ctx, Enums.Zone.MONSTER_ZONE,
			dragon).is_empty()

	wingbeat.resolve = func(ctx: EffectContext) -> void:
		# Re-checked here rather than trusted from activation: the board may have changed
		# while the Chain built. Design decision 16.
		var candidates := EffectPrimitives.own_cards_in(ctx, Enums.Zone.MONSTER_ZONE, dragon)
		var chosen := EffectPrimitives.choose_one(ctx, candidates,
			"Return 1 Level 5 or higher Dragon monster you control to the hand")
		if chosen == null:
			ctx.log_note("no Level 5 or higher Dragon monster to return")
			return
		if not EffectPrimitives.return_to_hand(ctx, chosen):
			ctx.log_note("the Dragon could not be returned")
			return
		ctx.log_note("returned %s to the hand" % chosen.card_name())

		# "and if you do" — reached only because the return happened.
		# Snapshot first: destroying one card can remove another (an Equip Card whose host
		# is a Spell/Trap cannot happen here, but a destruction REPLACEMENT can redirect),
		# and iterating a live zone array while it is being emptied is not safe.
		var doomed: Array = []
		for pid in range(GameState.PLAYER_COUNT):
			for entry in ctx.state.player(pid).controlled_cards():
				var card: CardInstance = entry
				if card == null or card.is_monster():
					continue
				# This card is itself a Spell Card on the field while it resolves, and is
				# nonetheless not destroyed by its own effect. CARD_RULINGS.md R28.
				if card == ctx.source:
					continue
				doomed.append(card)
		var destroyed := 0
		for entry in doomed:
			var card: CardInstance = entry
			if not card.is_on_field():
				continue
			if ctx.state.destroy(card, Enums.MoveReason.DESTROYED_BY_EFFECT, ctx.source.id):
				destroyed += 1
		ctx.log_note("destroyed %d Spell and Trap Card(s)" % destroyed)

	return [wingbeat]
