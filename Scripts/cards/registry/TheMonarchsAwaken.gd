extends RefCounted

## The Monarchs Awaken — Normal Trap. CARD_RULINGS.md R12, RULES_SPEC.md 18.
##
## Official English text (verified character for character against the live Konami database
## on 2026-09-09, cid 10963; see Data/cards/cards.json):
##
##   "If you have no cards in your Extra Deck: Target 1 face-up Tribute Summoned monster you
##    control; its effects are negated, also it is unaffected by the effects of cards other
##    than this card."
##
## Official Japanese text (cid 10963):
##
##   ①：自分のエクストラデッキにカードが存在しない場合、自分フィールドのアドバンス召喚した
##   表側表示モンスター１体を対象として発動できる。そのモンスターは効果が無効になり、
##   このカード以外の効果を受けない。
##
## One clause, and almost everything that matters about it is in the supplement rather than
## in the printed text. The details that are easy to get wrong:
##
##   1. **It cannot be activated during the Damage Step** — 「ダメージステップには発動でき
##      ません」. This is an activation restriction the printed English text does not carry,
##      the sixth card in a row to have one (R12 Part A). It is satisfied by leaving
##      `damage_step_permission` at its default `NONE`, so there is deliberately no line
##      below that sets it — and `MonarchsAwakenTests` asserts the behaviour rather than the
##      absence of a line, because a later batch reaching for `UNTIL_DAMAGE_CALC` on the
##      grounds that this card "changes a monster's state" would break it in silence.
##   2. **"Tribute Summoned" is not `summoned_by == TRIBUTE`.** A monster Tribute **Set** is
##      already Tribute Summoned before it is ever face-up (Q&A fid 20548, fid 20533), a
##      Flip Summon overwrites `summoned_by` with `FLIP` without ending the property, and a
##      temporarily banished monster keeps it across the round trip (fid 11352, which names
##      this card in its own answer). The engine's previous answer to all three was wrong;
##      `CardInstance.was_tribute_summoned()` is the corrected reader. R12 Part F.
##   3. **A Normal Monster is a legal target** — 「アドバンス召喚された通常モンスターを対象に
##      発動することもできます」 — even though the first clause then has nothing to negate.
##      Refusing such a target would look like a sensible optimisation and would be wrong,
##      and the V1 pool has Level 5+ vanillas that make it live. R12 Part G.
##   4. **If the target is face-down at RESOLUTION, NEITHER clause applies** —
##      「処理時に、対象のモンスターが裏側守備表示の場合、効果は無効にならず、『このカード
##      以外の効果を受けない』効果は適用されません」. The Trap is spent for nothing. This is
##      not the target ceasing to exist and it is not R10.8's whole-effect failure; it is the
##      narrower per-clause statement R10.6 established. RULES_SPEC.md 10.9, R12 Part E.
##   5. **The immunity exempts THIS CARD, and this card is in the Graveyard by then.** The
##      exemption is what lets the first clause's negation coexist with the second clause's
##      immunity (Q&A fid 11871), and the official duration — "as long as the monster is
##      face-up in the Monster Zone" — names the monster only, never the Trap. So the state
##      outlives its source, which is why neither half of it is a `ContinuousEffects` flag.
##      R12 Part D/E.
##   6. **"If you have no cards in your Extra Deck"** is an activation condition. Both V1
##      decks have empty Extra Decks so it is never false in the pool — the never-false shape
##      R1 records for `Runick Flashing Fire` — and it is implemented exactly anyway and
##      tested against a synthetic Extra Deck. Whether it is re-checked at resolution is
##      **not** settled by any official source found, so it is checked at activation only
##      and that limit is recorded rather than papered over (R12 Part G, MEDIUM confidence).
##
## What this card does NOT need, despite how the English reads: no targeting protection, no
## change to how effects activate or resolve, and no new duration machinery. The immunity is
## a gate on effect APPLICATION and nothing else (R12 Part B), it lives in
## `Scripts/rules/EffectImmunity.gd`, and `ImmunityTests` proved it green before this file
## existed.

const CARD_NAME := "The Monarchs Awaken"

const CLAUSE := ("If you have no cards in your Extra Deck: Target 1 face-up Tribute "
	+ "Summoned monster you control; its effects are negated, also it is unaffected by "
	+ "the effects of cards other than this card.")


func effects() -> Array:
	var awaken := EffectDef.new("monarchs_awaken_negate_and_ward", CLAUSE)
	awaken.of_type(Enums.EffectType.CARD_ACTIVATION)
	# A Normal Trap is Spell Speed 2 [S1 p.44-45]. `of_type()` derives Spell Speed from the
	# EFFECT category, which is Spell Speed 1 for everything but a Quick Effect, so the
	# CARD's Spell Speed has to be stated.
	awaken.with_spell_speed(Enums.SpellSpeed.SS2)
	# A Normal Trap is activated from a Set position on the field, never from the hand.
	awaken.activation_locations = [Enums.ActivationLocation.FIELD_FACE_DOWN]
	awaken.targeting(1)
	awaken.ruling_ref = "R12"

	# "If you have no cards in your Extra Deck" — checked at ACTIVATION. See note 6.
	awaken.condition = func(ctx: EffectContext) -> bool:
		return ctx.me().extra_deck.is_empty()

	# "1 face-up Tribute Summoned monster you control".
	awaken.legal_targets = func(ctx: EffectContext) -> Array:
		var out: Array = []
		for entry in EffectPrimitives.own_monsters(ctx, true):
			var card: CardInstance = entry
			if card.was_tribute_summoned():
				out.append(card)
		return out

	awaken.resolve = func(ctx: EffectContext) -> void:
		# Re-checked at resolution: "face-up", "monster", "you control" — R29, and here the
		# supplement states the face-up half outright. A target that has been flipped
		# face-down in response makes BOTH clauses do nothing; the card is still spent.
		var target := EffectPrimitives.surviving_own_monster_target(ctx, true)
		if target == null:
			ctx.log_note("the target was no longer a face-up monster you control")
			return
		# "its effects are negated" — the per-instance one-shot negation, which is cleared
		# when the monster leaves the field or is flipped face-down and by nothing else.
		# NOT `ContinuousEffects.negate_effects()`: that flag is rebuilt from the board on
		# every recompute and would switch off the moment this Normal Trap hit the Graveyard.
		target.effects_negated = true
		# "also it is unaffected by the effects of cards other than this card" — this card
		# is the exempt source, which is what keeps the negation above alive.
		EffectImmunity.grant(target, ctx.source)
		ctx.log_note("%s has its effects negated and is unaffected by other cards"
			% target.card_name())

	return [awaken]
