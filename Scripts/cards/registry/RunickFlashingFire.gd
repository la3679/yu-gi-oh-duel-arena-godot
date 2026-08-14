extends RefCounted

## Runick Flashing Fire — Quick-Play Spell, Spell Speed 2.
##
## Official text (verified against the Konami card database, cid 17374):
##
##   "Activate 1 of these effects, but skip your next Battle Phase after activation;
##    ●Target 1 Special Summoned monster your opponent controls; destroy it, then banish the
##    top 2 cards of your opponent's Deck.
##    ●Special Summon 1 "Runick" monster from your Extra Deck to the Extra Monster Zone.
##    You can only activate 1 "Runick Flashing Fire" per turn."
##
## Research/CARD_RULINGS.md **R1**, and the Battle Phase half is **R32**.
##
## **TWO bullets and a consequence that applies to whichever one is chosen.** Both bullets are
## implemented in full even though the second can never have a legal target in a real duel:
## both decks have an EMPTY Extra Deck, so no "Runick" monster can ever be there. It reports
## "no legal choice" rather than being omitted, and is tested against a SYNTHETIC Extra Deck
## monster with a real-pool assertion — the R21/R23/R2 treatment now used five times.
##
## Details this implementation accounts for:
##
##   1. **"but skip your next Battle Phase after activation" is applied at ACTIVATION**, in
##      `pay_cost`, never in `resolve`. **R1 fixes this**: it applies even if the chosen
##      effect is later negated, so it cannot be part of what the effect does. It is not a
##      cost in the PSCT sense — nothing is paid — but it happens at exactly the moment a
##      cost does and is never refunded, so it belongs on the same hook.
##   2. **The restriction is authoritative turn state, not a card-local flag.** It goes to
##      `GameState.impose_battle_phase_skip()` and is enforced by
##      `TurnFlow.can_enter_battle_phase()`. This card polls nothing and remembers nothing.
##      RULES_SPEC.md 2.4, gated by `BattlePhaseRestrictionTests`.
##   3. **Bullet 1 targets a SPECIAL SUMMONED monster specifically**, which is narrower than
##      "1 monster your opponent controls". A Normal Summoned or Set monster is not a legal
##      target, and that is re-checked at resolution along with control and zone (R29).
##   4. **"destroy it, THEN banish"** — "then" is sequential and conditional in PSCT: no
##      destruction, no banishment. A target that survived (prevention, replacement, or
##      already gone) means the top of the Deck is not touched at all.
##   5. **The banish is from the top of the OPPONENT'S Deck**, and is a banish rather than an
##      excavation, a mill, or a reveal — nothing is looked at and nothing is chosen.
##      `banish_top_of_deck()` already handles a Deck shorter than 2.
##   6. **"You can only activate 1 'Runick Flashing Fire' per turn"** is
##      `opt_named_activation()` — a limit on ACTIVATING THE CARD, per player and name, and a
##      different restriction from `opt_named_effect()`. It is declared on BOTH bullets,
##      because one activation of either spends the turn's single allowance.

const CARD_NAME := "Runick Flashing Fire"

const ARCHETYPE := "Runick"
const BANISH_COUNT := 2

const CLAUSE_PREFIX := "Activate 1 of these effects, but skip your next Battle Phase " \
	+ "after activation;"
const CLAUSE_DESTROY := CLAUSE_PREFIX + "Target 1 Special Summoned monster your opponent " \
	+ "controls; destroy it, then banish the top 2 cards of your opponent's Deck."
const CLAUSE_SUMMON := CLAUSE_PREFIX + "Special Summon 1 \"Runick\" monster from your " \
	+ "Extra Deck to the Extra Monster Zone."


func effects() -> Array:
	return [_destroy_and_banish(), _summon_from_extra_deck()]


# ---------------------------------------------------------------------------
# Shared — the two things every activation of this card does.
# ---------------------------------------------------------------------------

## Both bullets are Quick-Play Spell activations of the same card, so they share the card's
## Spell Speed, its activation locations and its once-per-turn allowance.
static func _configure(e: EffectDef) -> void:
	e.of_type(Enums.EffectType.CARD_ACTIVATION)
	e.with_spell_speed(Enums.SpellSpeed.SS2)
	# A Quick-Play Spell may be activated from the hand on your own turn, or from the field
	# once it has been Set. [S1 p.28]
	e.from_locations([Enums.ActivationLocation.HAND,
		Enums.ActivationLocation.FIELD_FACE_DOWN])
	# "You can only activate 1 'Runick Flashing Fire' per turn" — on the NAME, and about
	# ACTIVATING, so it is shared by both bullets: using either spends the turn's allowance.
	e.opt_named_activation()
	e.ruling("R1")

	# "…but skip your next Battle Phase after activation." R1: this applies ON ACTIVATION,
	# even if the chosen effect is later negated, so it is applied here and not in resolve().
	e.pay_cost = func(ctx: EffectContext) -> bool:
		EffectPrimitives.skip_your_next_battle_phase(ctx)
		return true


# ---------------------------------------------------------------------------
# Bullet 1 — destroy a Special Summoned monster, then banish 2 from their Deck.
# ---------------------------------------------------------------------------

func _destroy_and_banish() -> EffectDef:
	var e := EffectDef.new("destroy_special_summoned_and_banish_top", CLAUSE_DESTROY)
	_configure(e)
	e.targeting(1, 1)

	e.condition = func(ctx: EffectContext) -> bool:
		return not _special_summoned_opponent_monsters(ctx).is_empty()

	e.legal_targets = func(ctx: EffectContext) -> Array:
		return _special_summoned_opponent_monsters(ctx)

	e.resolve = func(ctx: EffectContext) -> void:
		# Every word that made it a legal target is re-checked: still in a Monster Zone,
		# still the opponent's, still a Special Summoned one. CARD_RULINGS.md R29.
		var target := EffectPrimitives.surviving_opponent_field_target(ctx)
		if target == null or not _was_special_summoned(target):
			ctx.log_note("the target is no longer a Special Summoned monster your opponent "
				+ "controls")
			return
		if not ctx.state.destroy(target, Enums.MoveReason.DESTROYED_BY_EFFECT,
				ctx.source.id):
			# "destroy it, THEN banish" — "then" is conditional. A target that was not
			# destroyed stops the sentence, and the Deck is not touched.
			ctx.log_note("the target was not destroyed, so nothing is banished")
			return
		var banished := EffectPrimitives.banish_top_of_deck(ctx, ctx.opponent_id(),
			BANISH_COUNT)
		ctx.log_note("destroyed %s and banished %d card(s) from the top of their Deck"
			% [target.card_name(), banished.size()])

	return e


# ---------------------------------------------------------------------------
# Bullet 2 — Special Summon a "Runick" monster from the Extra Deck.
# ---------------------------------------------------------------------------

func _summon_from_extra_deck() -> EffectDef:
	var e := EffectDef.new("special_summon_runick_from_extra_deck", CLAUSE_SUMMON)
	_configure(e)

	e.condition = func(ctx: EffectContext) -> bool:
		# R1: in the V1 pool this is always false, because both Extra Decks are empty. The
		# branch reports "no legal choice" rather than being absent — which is the difference
		# between a card that cannot do something today and a card that could never do it.
		if ctx.me().extra_monster_zone != null:
			return false
		return not EffectPrimitives.extra_deck_monsters(ctx, ARCHETYPE).is_empty()

	e.resolve = func(ctx: EffectContext) -> void:
		var candidates := EffectPrimitives.extra_deck_monsters(ctx, ARCHETYPE)
		var summoned := EffectPrimitives.special_summon_from_extra_deck(ctx, candidates,
			"Special Summon which \"Runick\" monster to the Extra Monster Zone?")
		if summoned == null:
			ctx.log_note("no \"Runick\" monster could be Special Summoned")
			return
		ctx.log_note("Special Summoned %s to the Extra Monster Zone"
			% summoned.card_name())

	return e


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

## "1 SPECIAL SUMMONED monster your opponent controls" — narrower than "1 monster your
## opponent controls". Face-down is not excluded: the text does not say "face-up", and how a
## monster arrived on the field is public information either way.
static func _special_summoned_opponent_monsters(ctx: EffectContext) -> Array:
	var out: Array = []
	for entry in ctx.state.player(ctx.opponent_id()).monsters():
		var card: CardInstance = entry
		if card != null and _was_special_summoned(card):
			out.append(card)
	return out


static func _was_special_summoned(card: CardInstance) -> bool:
	return card != null and card.summoned_by == Enums.SummonKind.SPECIAL
