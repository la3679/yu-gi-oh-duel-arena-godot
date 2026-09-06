extends RefCounted

## Damage Condenser — Normal Trap.
##
## Official text (verified against the Konami card database, cid 6582; see
## Data/cards/cards.json):
##
##   "When you take battle damage: Discard 1 card; Special Summon 1 monster from your Deck
##    with ATK less than or equal to the battle damage you took, in Attack Position."
##
## One printed clause, one EffectDef. Research/CARD_RULINGS.md **R42 Part C** is the
## official supplemental information (cid 6582, dated 2017-04-20, fetched with
## `request_locale=ja` per R40's methodology note). It settles both questions PROJECT_STATE
## §8 left open and adds a third that §8 did not know existed.
##
##   1. **The Deck requirement is an ACTIVATION RESTRICTION, not a resolution filter.**
##      cid 6582: 自分のデッキに、『その時に受けたダメージの数値以下の攻撃力を持つ
##      モンスター』が存在しない場合、発動する事はできません — with no qualifying monster
##      in your Deck the card **cannot be activated at all**. This is the fact §8 did not
##      have, and it is the difference between a card that resolves for nothing and one
##      that is never offered. It lives in `condition`, the way R40's general search
##      restriction does. **This is the opposite of `One for One`**, whose activation is
##      legal and whose resolution may legitimately find nothing; the two must not be made
##      to share an implementation.
##   2. **The ATK compared is the ATK in the DECK** — §8's first open question, answered
##      YES by an official source rather than by inference. The restriction is phrased as a
##      property of monsters *in the Deck*, and a card in the Deck has no field, no
##      modifiers and no controller, so printed = original = current there.
##      `EffectPrimitives.monster_filter(max_atk)` already reads `definition.base_atk` for
##      exactly this reason and says so in its own comment.
##   3. **The damage compared is the damage taken AT THAT MOMENT** — その時に受けた: the
##      specific battle damage that triggered this activation, not a running total and not
##      the controller's Life Points. Read through
##      `EffectPrimitives.battle_damage_just_inflicted_on()`, which batch 11 built for
##      `Vampiric Koala`. See detail 11 for why it is read that way in the CONDITION too.
##   4. **It does not target** (対象を取る効果ではありません). It could not: the candidates
##      are in the hidden Deck, so the choice is necessarily made at RESOLUTION.
##   5. **It activates AFTER DAMAGE CALCULATION**
##      (自分が戦闘ダメージを受けたダメージ計算後に発動します) — sub-step 4, which
##      RULES_SPEC §7.1 already names as the window for "when battle damage is inflicted".
##      This needed a new `Enums.DamageStepPermission.AFTER_DAMAGE_CALC`, because
##      `UNTIL_DAMAGE_CALC` is the earlier window and `MANDATORY_TRIGGER` is gated on the
##      effect being trigger-COLLECTED, which a Trap's own `CARD_ACTIVATION` never is. The
##      gate is in `DamageStepTests` and was green before this card existed.
##      **`Kurenai` and `Aoi`, in this same batch, are the opposite** — their supplements
##      forbid the Damage Step outright — and all three are asserted so the contrast cannot
##      quietly collapse.
##   6. **The discard is a COST** (発動する際に、コストとして、手札を1枚捨てます), so
##      `pay_discard_cost()` and `MoveReason.DISCARDED` — the card says "Discard", which is
##      not the same as "send from your hand to the GY" [S1 p.52-53].
##   7. **"you take" is the CONTROLLER's damage.** The mirror of `Vampiric Koala`, which
##      batch 11 keyed on damage taken by the OPPONENT from the same event. Each is a
##      control on the other.
##   8. **In Attack Position**, named by the text, so `special_summon_one()` with a fixed
##      `Enums.Position` rather than `special_summon_one_any_position()`. The player is
##      never asked which position.
##   9. **The Deck is shuffled afterwards.** §8's second open question. cid 6582 is
##      **silent**, so this follows the general rule and the established precedent rather
##      than a card-specific ruling, and R42 Part C records it as such: [S1 p.5] requires a
##      Deck a card effect made you look through to be shuffled and put back, RULES_SPEC
##      §8.4 records that as normative, and `One for One` — the pool's OTHER Deck Special
##      Summon — already implements exactly this tail and cites the same line. It is
##      observable (§12.1: a shuffle clears `revealed_to` for that Deck) and is asserted.
##  10. **A free Monster Zone is required.** Not from cid 6582, which is silent, but from
##      the general rule that an effect which exists to Special Summon cannot be activated
##      when the Summon could not happen — the same check `One for One` makes, and for the
##      same reason. Re-checked at resolution too, by `special_summon_one()` itself.
##
##  11. **The condition may NOT read `ctx.trigger_event`, and this is not the same shape as
##      `Vampiric Koala`.** `Vampiric Koala` is an `EffectType.TRIGGER`: the trigger system
##      collects it and hands its condition the event that made it eligible. This card is a
##      Trap's own `CARD_ACTIVATION`, offered by `DuelEngine._activation_actions()` as a
##      RESPONSE in a window whose events match `trigger_events` — and that path calls
##      `ActivationRules.can_activate(..., null)`, so `ctx.trigger_event` is **null** here.
##      A condition written against the event is therefore silently false and the card is
##      never offered at all. Nor can the condition reach `BattleRules.last_damage`:
##      `ActivationRules.make_context()` attaches **no engine**, so
##      `battle_damage_just_inflicted_on()` also answers 0 there. The condition reads the
##      authoritative **event log** instead, through
##      `EffectPrimitives.battle_damage_taken_in_this_battle()`, bounded backwards to the
##      most recent `ATTACK_DECLARED` so an earlier battle in the same turn cannot leak in
##      — the same reasoning batch 11 recorded for `named_monster_attacked_this_turn()`.
##      Resolution keeps using `battle_damage_just_inflicted_on()`, where the engine IS
##      attached. Both drafts of this card got this wrong in turn, and its own suite caught
##      each: every positive test failed at once because nothing was ever offered.
##
## §8 called this card "the first Special Summon FROM THE DECK in the pool". It is not:
## `One for One` has done that since batch 10. R42 Part E records the correction. **No new
## Summon surface was added for this card** — it is a consumer of `special_summon_one()`,
## `monster_filter(max_atk)` and `pay_discard_cost()`, all of which already existed.
##
## Live in the V1 pool: this card is in `Blue-Eyes Dragon Guard`, whose Deck holds plenty of
## monsters under any realistic battle-damage figure. The suite asserts against the real
## printed deck as well as against fixtures.

const CARD_NAME := "Damage Condenser"

const CLAUSE := "When you take battle damage: Discard 1 card; Special Summon 1 monster " \
	+ "from your Deck with ATK less than or equal to the battle damage you took, in " \
	+ "Attack Position."


func effects() -> Array:
	var e := EffectDef.new("discard_to_summon_from_deck_by_battle_damage", CLAUSE)
	e.of_type(Enums.EffectType.CARD_ACTIVATION)
	# A Normal Trap is Spell Speed 2 [S1 p.44-45]; `of_type()` cannot derive it.
	e.with_spell_speed(Enums.SpellSpeed.SS2)
	e.activation_locations = [Enums.ActivationLocation.FIELD_FACE_DOWN]
	e.trigger_events = [GameEvent.Kind.BATTLE_DAMAGE_INFLICTED]
	# Detail 5: sub-step 4, and only sub-step 4.
	e.damage_step(Enums.DamageStepPermission.AFTER_DAMAGE_CALC)
	e.ruling("R42")

	e.condition = func(ctx: EffectContext) -> bool:
		# Detail 11: the damage is read from the BATTLE RESULT, not from the event, in the
		# condition as well as at resolution. Details 3 and 7 both ride on this one call:
		# it answers only for the CONTROLLER, and only for the battle that just happened.
		var damage := EffectPrimitives.battle_damage_taken_in_this_battle(ctx,
			ctx.controller_id)
		if damage <= 0:
			return false
		# Detail 10: nowhere to put it means the effect could not be carried out.
		if not ctx.me().has_free_monster_zone():
			return false
		# Detail 1 — the official ACTIVATION restriction. Details 2 and 3 are both encoded
		# in this one line: the ATK read is the printed one `monster_filter` uses, and the
		# figure it is compared against is this event's damage.
		return not EffectPrimitives.own_cards_in(ctx, Enums.Zone.DECK,
			EffectPrimitives.monster_filter("", damage)).is_empty()

	e.can_pay_cost = func(ctx: EffectContext) -> bool:
		return not ctx.me().hand.is_empty()

	e.pay_cost = func(ctx: EffectContext) -> bool:
		# Detail 6: a DISCARD, not a send. Any card in the hand qualifies.
		var paid := EffectPrimitives.pay_discard_cost(ctx, ctx.me().hand.duplicate(), 1,
			"Discard 1 card (cost)")
		if paid.is_empty():
			return false
		EffectPrimitives.record_cost(ctx, EffectPrimitives.COST_CARDS_KEY, paid)
		return true

	e.resolve = func(ctx: EffectContext) -> void:
		# Detail 3: `ctx.trigger_event` is null by the time a link resolves, so the amount
		# is read from the authoritative battle result instead.
		var damage := EffectPrimitives.battle_damage_just_inflicted_on(ctx,
			ctx.controller_id)
		if damage <= 0:
			ctx.log_note("no battle damage was taken")
			return
		var candidates := EffectPrimitives.own_cards_in(ctx, Enums.Zone.DECK,
			EffectPrimitives.monster_filter("", damage))
		# Detail 8: the position is named by the text, so it is not the player's to choose.
		var summoned := EffectPrimitives.special_summon_one(ctx, candidates,
			Enums.Position.FACE_UP_ATTACK,
			"Special Summon 1 monster from your Deck with %d ATK or less" % damage)
		# Detail 9: the Deck was looked through, so it is shuffled — and it is shuffled
		# whether or not the Summon happened, because the looking is what requires it.
		# "If a card effect requires you to reveal cards from your Deck, or look through
		# it, shuffle it and put it back." [S1 p.5]
		ctx.state.shuffle_deck(ctx.controller_id)
		if summoned != null:
			ctx.log_note("Special Summoned %s in Attack Position (%d battle damage taken)"
				% [summoned.card_name(), damage])
		else:
			ctx.log_note("no monster was Special Summoned")

	return [e]
