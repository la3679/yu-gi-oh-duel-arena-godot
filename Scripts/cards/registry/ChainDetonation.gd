extends RefCounted

## Chain Detonation — Normal Trap.
##
## Official text (verified against the Konami card database, cid 6915; see
## Data/generated/konami_cards.json):
##
##   "Inflict 500 damage to your opponent. If this card was activated as Chain Link 2 or 3,
##    add this card to the Deck and shuffle it. If this card was activated as Chain Link 4
##    or higher, return this card to the hand."
##
## Research/CARD_RULINGS.md **R4**: the card's behaviour depends on the Chain Link number it
## was ACTIVATED at.
##
## Three printed sentences, but ONE EffectDef: the second and third sentences are not
## separately activatable effects — they are two branches of the same resolution, selected by
## a fact fixed at activation. Splitting them into their own EffectDefs would make them
## look like independently activatable clauses, which they are not.
##
## Details this implementation accounts for:
##
##   1. **The Chain Link number is read from `ChainLink.link_number`**, which is 1-based
##      authoritative state written when the link was created. Counting the chain array at
##      resolution would be wrong: the links above have already resolved by then. The read
##      goes through `EffectPrimitives.activated_chain_link_number()`.
##   2. **The damage is unconditional.** It happens at Chain Link 1 as well; only the
##      self-return is conditional. Chain Link 1 gets neither of the two conditional halves
##      and the Trap then goes to the Graveyard the ordinary way.
##   3. **It is effect damage, not battle damage.** `GameState.change_life_points()` followed
##      by an explicit `check_life_point_loss()` by the caller — the same shape
##      `Five Brothers Explosion` uses, because `change_life_points()` deliberately does not
##      decide the end of the Duel for itself.
##   4. **"add this card to the Deck and shuffle it" really shuffles**, and the shuffle is
##      what clears `revealed_to` — a card activated on the Chain is public, and once it is
##      shuffled back in nobody may know where it is any more. This card and `Chain Healing`
##      are the only two in the V1 pool that shuffle into the Deck, so they are what
##      exercises that branch of design decision 11 with a printed card.
##   5. **Moving itself off the field means the resolution cleanup must not also send it to
##      the Graveyard.** `DuelEngine._cleanup_resolved_spell_traps()` skips a card that is no
##      longer on the field, so the two do not fight; the tests assert it directly.
##   6. **A higher Chain Link resolves FIRST** and can destroy this card before its own link
##      resolves. The damage still happens; the self-return cannot, because a card in the
##      Graveyard is no longer "this card" on the field.
##
## The self-return half is shared with `Chain Healing` through
## `EffectPrimitives.return_self_by_chain_link()` because the two official texts are word for
## word identical for that sentence pair. The FIRST sentence differs — 500 damage here, 500
## LP there — and each card writes its own; see design decision 22.

const CARD_NAME := "Chain Detonation"

const CLAUSE := "Inflict 500 damage to your opponent. If this card was activated as Chain " \
	+ "Link 2 or 3, add this card to the Deck and shuffle it. If this card was activated " \
	+ "as Chain Link 4 or higher, return this card to the hand."

const DAMAGE := 500


func effects() -> Array:
	var e := EffectDef.new("burn_500_then_return_by_chain_link", CLAUSE)
	e.of_type(Enums.EffectType.CARD_ACTIVATION)
	# A Normal Trap is Spell Speed 2 [S1 p.44-45]; `of_type()` cannot derive it.
	e.with_spell_speed(Enums.SpellSpeed.SS2)
	e.activation_locations = [Enums.ActivationLocation.FIELD_FACE_DOWN]
	e.ruling("R4")

	e.resolve = func(ctx: EffectContext) -> void:
		# Sentence 1 — unconditional, and it happens at every Chain Link position.
		ctx.state.change_life_points(ctx.opponent_id(), -DAMAGE, CARD_NAME, ctx.source.id)
		# Effect damage can end the Duel, and the caller is what decides that.
		ctx.state.check_life_point_loss()
		# Sentences 2 and 3 — the shared Chain-Link-position branch.
		var note := EffectPrimitives.return_self_by_chain_link(ctx)
		ctx.log_note("inflicted %d damage; %s" % [DAMAGE, note])

	return [e]
