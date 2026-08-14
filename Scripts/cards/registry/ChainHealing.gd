extends RefCounted

## Chain Healing — Normal Trap.
##
## Official text (verified against the Konami card database, cid 6914; see
## Data/generated/konami_cards.json):
##
##   "Gain 500 Life Points. If this card was activated as Chain Link 2 or 3, add this card
##    to the Deck and shuffle it. If this card was activated as Chain Link 4 or higher,
##    return this card to the hand."
##
## Research/CARD_RULINGS.md **R4**, the same ruling `Chain Detonation` rests on.
##
## The two cards' second and third sentences are identical word for word and are therefore
## ONE primitive (`EffectPrimitives.return_self_by_chain_link()`). Their FIRST sentences are
## not: this one gains its CONTROLLER 500 LP, the other inflicts 500 damage on the OPPONENT,
## and each card writes its own — design decision 22, the same reason `Birthright` and
## `Call of the Haunted` are two implementations.
##
## Details this implementation accounts for, beyond the ones documented on
## `ChainDetonation.gd`:
##
##   1. **The LP go to this card's CONTROLLER**, which is the player who activated it — "you"
##      in PSCT. Getting this backwards is the single easiest mistake on the card and is
##      asserted from both sides of the table.
##   2. **The LP gain is unconditional** and happens at Chain Link 1 as well. Only the
##      self-return depends on the Chain Link position.
##   3. **Gaining LP cannot end the Duel**, so unlike `Chain Detonation` there is no
##      `check_life_point_loss()` here: nothing this card does can take a player to 0.
##   4. **A negated effect gains nothing at all** — neither half runs. The card was still
##      activated, so it still leaves the field as a resolved Normal Trap.

const CARD_NAME := "Chain Healing"

const CLAUSE := "Gain 500 Life Points. If this card was activated as Chain Link 2 or 3, " \
	+ "add this card to the Deck and shuffle it. If this card was activated as Chain Link " \
	+ "4 or higher, return this card to the hand."

const LIFE_POINTS := 500


func effects() -> Array:
	var e := EffectDef.new("gain_500_lp_then_return_by_chain_link", CLAUSE)
	e.of_type(Enums.EffectType.CARD_ACTIVATION)
	# A Normal Trap is Spell Speed 2 [S1 p.44-45]; `of_type()` cannot derive it.
	e.with_spell_speed(Enums.SpellSpeed.SS2)
	e.activation_locations = [Enums.ActivationLocation.FIELD_FACE_DOWN]
	e.ruling("R4")

	e.resolve = func(ctx: EffectContext) -> void:
		# Sentence 1 — "Gain" is "you gain", so it is this card's own controller.
		ctx.state.change_life_points(ctx.controller_id, LIFE_POINTS, CARD_NAME, ctx.source.id)
		# Sentences 2 and 3 — the shared Chain-Link-position branch.
		var note := EffectPrimitives.return_self_by_chain_link(ctx)
		ctx.log_note("gained %d LP; %s" % [LIFE_POINTS, note])

	return [e]
