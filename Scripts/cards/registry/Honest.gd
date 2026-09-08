extends RefCounted

## Honest — LIGHT / Fairy / Level 4 / 1100 ATK / 1900 DEF, Effect Monster.
##
## Official English text (verified against the Konami card database, cid 7574; see
## `Data/cards/cards.json`):
##
##   "During your Main Phase: You can return this face-up card from the field to the hand.
##    During the Damage Step, when a LIGHT monster you control battles (Quick Effect): You
##    can send this card from your hand to the GY; that monster gains ATK equal to the ATK
##    of the opponent's monster it is battling, until the end of this turn."
##
## Official Japanese text and supplemental information, cid 7574, supplement dated
## **2024-04-01**, fetched with `request_locale=ja` per R40's methodology note. Full record
## in `CARD_RULINGS.md` **R20**, which this file does not restate — what follows is only the
## mapping from each settled fact onto the code below.
##
##   1. **Clause ① is an IGNITION effect activated in the MONSTER ZONE.**
##      「モンスターゾーンで発動できる起動効果です。」 — `EffectType.IGNITION`,
##      `FIELD_FACE_UP`, and Main Phase 1 / 2 only. Not a Quick Effect, so it cannot be used
##      to dodge anything in a chain, which is the whole reason Konami spells it out.
##
##   2. **Clause ② is a QUICK EFFECT activated IN THE HAND.**
##      「手札で発動できる誘発即時効果です。」 — `EffectType.QUICK` (Spell Speed 2) with
##      `ActivationLocation.HAND`. This is the pool's **first monster effect activated from
##      the hand**, and it needed no new engine surface: `ActivationRules.location_ok()`
##      already answers for `HAND`, and `DuelEngine._activation_actions()` already walks
##      every instance regardless of zone and lets that gate decide.
##
##   3. **The window is the Damage Step, up to before damage calculation.**
##      「ダメージステップ開始時からダメージ計算前までに」 — sub-steps 1 and 2, which is
##      exactly `DamageStepPermission.UNTIL_DAMAGE_CALC` (RULES_SPEC.md 7.2). That value
##      already existed and is documented as "an effect that directly changes ATK/DEF";
##      Honest is the printed card it was written for. No new permission value was added.
##
##   4. **CANNOT be activated against a monster with 0 ATK.**
##      「攻撃力０のモンスターと戦闘を行う際には発動できません。」 This is an **activation
##      restriction the printed English text does not carry**, and it is the fact this card's
##      research existed to find. It lives in `condition`, so the effect is never offered —
##      as opposed to being offered and resolving for +0.
##
##   5. **Legal whether your LIGHT monster is ATTACKING or being ATTACKED.**
##      「自分の光属性モンスターが攻撃する戦闘の際でも、自分の光属性モンスターが攻撃される
##      戦闘の際でも発動できます。」 `EffectPrimitives.battle_opponent_of()` already answers
##      from either side of `current_attacker` / `current_attack_target`, so both directions
##      fall out of one reader rather than out of two branches.
##
##   6. **The send is a COST.** 「このカードを手札から墓地へ送って発動できる」, and cid 7574 is
##      one of the cards listed under the official Q&A about effects that "send a card to the
##      GY **as a cost**" (fid 14540). Paid in `pay_cost`, never in `resolve`, and therefore
##      **not refunded** when the activation or the effect is negated. It is a **send**, not a
##      discard — `MoveReason.SENT_AS_COST`, the same distinction `One for One` draws
##      [S1 p.52-53].
##
##   7. **The card is in the GRAVEYARD when its own effect resolves**, because the cost put
##      it there. Nothing in the resolution reads `ctx.source`'s zone, and the effect must
##      still apply — this is the ordinary consequence of a cost, not a special case.
##
##   8. **It does NOT target.** Neither text carries 対象 / "target". "That monster" is
##      fixed by the battle at activation, so `targets` stays false and the monster is
##      recorded in `ctx.cost_payload` at activation — the channel `Kurenai` already uses —
##      rather than re-derived at resolution. Re-deriving would re-ask "is it LIGHT?", and
##      that was an **activation** condition: a monster that stopped being LIGHT after a
##      legal activation is still "that monster".
##
##   9. **The opponent's monster is READ, not affected.** Official Q&A fid 12970: a monster
##      that "is unaffected by the effects of cards other than this card" can still be
##      battled and Honest still applies — 「オネスト」の効果は、相手モンスターが受ける効果では
##      ありません. So the only card Honest affects is your own LIGHT monster. Nothing here
##      consults any protection the opposing monster carries, and that is deliberate.
##
##  10. **The amount is the opponent monster's ATK read at RESOLUTION**, and it is an
##      ADDITIVE modifier rather than a set-to-value. Official Q&A fid 19235 says the
##      boosted monster's ATK 「再計算される」 — recalculated — with Honest's addition going in
##      before a continuous doubler multiplies the result. `add_atk_modifier` is exactly that
##      shape, and `current_atk()` sums the modifiers, so the ordering is the engine's and
##      not this card's.
##
##  11. **"Until the end of this turn"** is `gain_atk_until_end_of_turn()`, whose
##      `"end_of_turn"` modifiers `TurnFlow._end_of_turn_cleanup()` removes at the end of the
##      turn — whoever's turn it was. Deliberately **not** "until the end of the Damage Step":
##      the boost outlives the battle that motivated it, and that is observable.
##
##  12. **No once-per-turn.** Neither text carries any per-turn wording, so no `opt_*` is
##      declared. Two copies in hand may both be sent in the same battle and the gains stack,
##      because each is a separate additive modifier.
##
## **A face-down opposing monster.** Detail 4 is an activation restriction, and it cannot be
## evaluated against a monster whose ATK is not legally knowable — asking would either leak
## hidden information or make the restriction unenforceable (RULES_SPEC.md 12.1, and R39's
## precedent that a typed predicate may not inspect an opposing face-down monster). So the
## condition requires the opposing battling monster to be **face-up**. **No legal play is
## lost by that**, and this is the point that makes it safe rather than convenient: the rules
## flip an attacked face-down monster face-up in **sub-step 2**, which is inside Honest's own
## printed window, so the activation is simply offered one sub-step later. Recorded in R20
## with its confidence and asserted in both directions.
##
## **What this card deliberately does NOT add.** No card-specific damage calculation. The
## boost is an ordinary ATK modifier on the battling monster, and
## `BattleRules.step_damage_calculation()` reads `current_atk()` as it already did — so the
## battle outcome changes because the monster's ATK changed, which is the only mechanism
## there is. No new Damage Step permission, no new activation location, no new stat channel.

const CARD_NAME := "Honest"

const CLAUSE_RETURN := "During your Main Phase: You can return this face-up card from the " \
	+ "field to the hand."

const CLAUSE_BOOST := "During the Damage Step, when a LIGHT monster you control battles " \
	+ "(Quick Effect): You can send this card from your hand to the GY; that monster " \
	+ "gains ATK equal to the ATK of the opponent's monster it is battling, until the " \
	+ "end of this turn."

const ATTRIBUTE := "LIGHT"

## Which monster "that monster" is. Written at activation, read at resolution — see
## detail 8. Lives in `ctx.cost_payload`, the channel that is already copied into the
## `ChainLink`, so a Chain carrying two Honests cannot confuse one link's monster for the
## other's.
const BOOSTED_MONSTER_KEY := "honest_boosted_monster"


func effects() -> Array:
	return [_return_to_hand(), _boost_battling_light_monster()]


# ---------------------------------------------------------------------------
# ① "During your Main Phase: You can return this face-up card from the field to the hand."
# ---------------------------------------------------------------------------

func _return_to_hand() -> EffectDef:
	var e := EffectDef.new("return_this_card_to_hand", CLAUSE_RETURN)
	# Detail 1: an IGNITION effect activated in the Monster Zone, not a Quick Effect.
	e.of_type(Enums.EffectType.IGNITION)
	e.from_locations([Enums.ActivationLocation.FIELD_FACE_UP])
	e.in_phases([Enums.Phase.MAIN_1, Enums.Phase.MAIN_2])
	e.ruling("R20")

	e.condition = func(ctx: EffectContext) -> bool:
		# "this face-up card ON THE FIELD" — the Monster Zone, face-up. `from_locations`
		# already says so; this re-states it for the resolution-time re-check below to
		# have a single meaning.
		return ctx.source.is_on_field() and ctx.source.is_face_up()

	e.resolve = func(ctx: EffectContext) -> void:
		# Re-checked at resolution for the reason R29 gives: every word that made the
		# activation legal has to still be true. A copy flipped face-down or removed in
		# response is no longer "this face-up card on the field".
		if not (ctx.source.is_on_field() and ctx.source.is_face_up()):
			ctx.log_note("%s is no longer face-up on the field" % CARD_NAME)
			return
		if ctx.state.move_card(ctx.source, Enums.Zone.HAND,
				Enums.MoveReason.RETURNED_TO_HAND, {"source_id": ctx.source.id}):
			ctx.log_note("%s returned itself to the hand" % CARD_NAME)

	return e


# ---------------------------------------------------------------------------
# ② The Damage Step Quick Effect, activated from the hand.
# ---------------------------------------------------------------------------

func _boost_battling_light_monster() -> EffectDef:
	var e := EffectDef.new("send_from_hand_boost_battling_light_monster", CLAUSE_BOOST)
	# Detail 2: a Quick Effect (Spell Speed 2) activated IN THE HAND.
	e.of_type(Enums.EffectType.QUICK)
	e.from_locations([Enums.ActivationLocation.HAND])
	# Detail 3: sub-steps 1-2 of the Damage Step and nowhere else. The `condition` below
	# additionally requires a live battle, so this is not a licence to activate outside one.
	e.damage_step(Enums.DamageStepPermission.UNTIL_DAMAGE_CALC)
	e.ruling("R20")

	e.condition = func(ctx: EffectContext) -> bool:
		return _battle_pair(ctx) != null

	e.can_pay_cost = func(ctx: EffectContext) -> bool:
		# Detail 6: the cost is this card leaving the HAND. Nothing else can pay it.
		return ctx.source.zone == Enums.Zone.HAND

	e.pay_cost = func(ctx: EffectContext) -> bool:
		var pair = _battle_pair(ctx)
		if pair == null:
			return false
		if ctx.source.zone != Enums.Zone.HAND:
			return false
		# A send, not a discard. Detail 6, [S1 p.52-53].
		if not ctx.state.move_card(ctx.source, Enums.Zone.GRAVEYARD,
				Enums.MoveReason.SENT_AS_COST, {"source_id": ctx.source.id}):
			push_error("Honest: could not send itself from the hand as a cost")
			return false
		EffectPrimitives.record_cost(ctx, EffectPrimitives.COST_CARDS_KEY, [ctx.source])
		# Detail 8: "that monster" is fixed here, at activation.
		ctx.cost_payload[BOOSTED_MONSTER_KEY] = (pair["mine"] as CardInstance).id
		return true

	e.resolve = func(ctx: EffectContext) -> void:
		var mine = ctx.state.instance(int(ctx.cost_payload.get(BOOSTED_MONSTER_KEY, -1)))
		if mine == null or not mine.is_on_field():
			# "That monster" left the field between activation and resolution. There is
			# nothing left to boost, and nothing else may be boosted in its place —
			# detail 8 fixed the monster at activation.
			ctx.log_note("the monster %s was activated for is no longer on the field"
				% CARD_NAME)
			return
		# Detail 10: the opponent monster's ATK is read HERE, at resolution.
		var theirs = EffectPrimitives.battle_opponent_of(ctx.state, mine)
		if theirs == null:
			ctx.log_note("the battle %s was activated in is over" % CARD_NAME)
			return
		var amount := theirs.current_atk()
		# Detail 4 makes 0 unreachable through a legal activation, and detail 10 means the
		# value is re-read, so a chained effect could still have zeroed it. Then the card
		# does exactly what it says: it adds nothing.
		if not EffectPrimitives.gain_atk_until_end_of_turn(ctx, mine, amount):
			ctx.log_note("%s gains no ATK: %s has %d ATK"
				% [mine.card_name(), theirs.card_name(), amount])
			return
		ctx.log_note("%s gains %d ATK (the ATK of %s) until the end of this turn"
			% [mine.card_name(), amount, theirs.card_name()])

	return e


# ---------------------------------------------------------------------------
# The one question clause ② asks, asked once
# ---------------------------------------------------------------------------

## The live battle this effect could be activated in, as {"mine": …, "theirs": …}, or null.
##
## Every condition detail 3-5 and the face-down rule above impose is decided here, so the
## `condition`, `pay_cost` and the resolution's re-check cannot drift apart:
##
##   * there is a battle, and it is not a direct attack — `battle_opponent_of()` answers
##     null for both, so "battles" really means monster against monster;
##   * a monster **I control** is in it, face-up on the field, and its Attribute is LIGHT,
##     read with `current_attribute()` (the field reader, R33) rather than the printed one;
##   * the opposing monster is **face-up**, so its ATK is legally knowable;
##   * and its ATK is **not 0** — detail 4, the restriction the English text omits.
##
## Detail 5 needs no branch: `battle_opponent_of()` is symmetric, so the attacker and the
## attacked monster are found by the same two lookups.
static func _battle_pair(ctx: EffectContext):
	# "During the Damage Step" is part of the TEXT, not only of the Damage Step permission.
	# `ActivationRules.damage_step_ok()` answers `true` outside the Damage Step by design —
	# it exists to restrict what may happen INSIDE one — so without this the effect would be
	# offered in the attack-declaration window, which is the Battle Step. RULES_SPEC.md 7.2.
	if ctx.state.battle_step != Enums.BattleStep.DAMAGE:
		return null
	for candidate in [ctx.state.current_attacker, ctx.state.current_attack_target]:
		var mine: CardInstance = candidate
		if mine == null or mine.controller_id != ctx.controller_id:
			continue
		if not (mine.is_on_field() and mine.is_face_up() and mine.is_monster()):
			continue
		if mine.current_attribute() != ATTRIBUTE:
			continue
		var theirs = EffectPrimitives.battle_opponent_of(ctx.state, mine)
		if theirs == null or not theirs.is_face_up():
			continue
		if theirs.current_atk() == 0:
			continue
		return {"mine": mine, "theirs": theirs}
	return null
