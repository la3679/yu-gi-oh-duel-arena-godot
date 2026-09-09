extends RefCounted

## A Hero Emerges — Normal Trap.
##
## Official text (verified against the Konami card database, cid 5915, and re-fetched and
## diffed character-for-character on 2026-09-09; see Data/cards/cards.json):
##
##   "When an opponent's monster declares an attack: Your opponent chooses 1 random card
##    from your hand, then if it is a monster that can be Special Summoned, Special Summon
##    it. Otherwise, send it to the GY."
##
## One printed clause, one EffectDef. Research/CARD_RULINGS.md **R15** is the official
## supplemental information (cid 5915, dated 2015-03-26) **plus both of the card's Q&A
## entries** (fid 12566 「御前試合」 and fid 8193 「虚無空間」, both 2017-03-24), all fetched
## with `request_locale=ja` per R40's methodology note. Between them they settle every
## question PROJECT_STATE §8 left open and add three the English text does not hint at.
##
##   1. **The HAND gates the ACTIVATION** — R15 Part A, the fact §8 warned would be there
##      and was right about for the fifth batch running.
##      自分の手札が0枚の場合や、自分の手札にモンスターカードがない場合、
##      「ヒーロー見参」を発動する事自体ができません — with an empty hand, or with no
##      monster in hand, it **cannot be activated at all**. 「発動する事自体ができません」 is
##      the same construction cid 6582 uses for `Damage Condenser`, and it means the same
##      thing: an activation restriction, in `condition`, never a resolution filter.
##   2. **The requirement is narrower than "a monster card"** — R15 Part B. Q&A fid 12566
##      (Gozen Match) requires a monster **this effect could actually Special Summon right
##      now**: with only LIGHT monsters on your field under Gozen Match, a hand of DARK
##      monsters makes the activation illegal. So the question is
##      `EffectPrimitives.can_be_special_summoned_now()`, which mirrors exactly what
##      `SummonRules.begin_special_summon()` itself refuses — a free Monster Zone and the
##      "You can only control 1 …" limit both count, and both are live in this pool.
##   3. **The whole effect is re-gated at RESOLUTION, and the random choice is suppressed
##      with it** — R15 Part C, and the most valuable thing the research bought. Q&A fid
##      8193: chained `Vanity's Emptiness` makes Special Summoning impossible, and
##      「ヒーロー見参」の効果処理は適用されません —
##      **（『自分の手札１枚を相手がランダムに選ぶ』事も行いません。）** The pick is *not
##      even made*. The naive "pick first, then branch" implementation is observably wrong:
##      it would send a Spell out of the hand in a situation whose official answer is that
##      nothing happens. `resolve()` therefore re-asks detail 2's question **before** it
##      chooses, and returns having done nothing when it fails.
##
##      This is **not** in tension with RULES_SPEC §10.6 (*a dead target does not kill the
##      whole effect*): §10.6 is about a **target** that has left, and this card has no
##      target at all (detail 4). What has failed here is the card's own **activation
##      requirement**, which is not a sentence of the resolution. The two are asserted
##      against each other so neither is generalised over the other.
##   4. **It does not TARGET** (対象を取る効果ではありません). The hand is hidden, so there is
##      nothing to target there; the choice happens at resolution, which is what the
##      absence of the word "target" already means (RULES_SPEC §10).
##   5. **The pick is RANDOM, through the seeded `Rng`, and is NOT a decision** — R15
##      Part D. `EffectPrimitives.random_hand_card_chosen_by()` draws from
##      `GameState.rng`, so the duel stays reproducible from (Decks, seed, decisions);
##      routing "your opponent chooses" through `ctx.ask()` would instead hand the chooser
##      the contents of a hidden hand, which is the leak RULES_SPEC §12 exists to prevent.
##      The chooser is asked nothing at all.
##   6. **"Otherwise" is TWO cases, not one** — R15 Part E. The chosen card goes to the
##      Graveyard both when it is not a monster and when it is a monster this effect cannot
##      Special Summon (a Spirit such as 「月読命」, a Special Summon Monster, or a monster a
##      lingering restriction forbids). One `can_be_special_summoned_now()` call decides
##      the branch, which is why the two cases cannot drift apart.
##   7. **It is a SEND, never a discard** — 墓地へ送る, and [S1 p.52-53] keeps the two apart.
##      `send_from_hand_to_gy()` and `MoveReason.SENT_TO_GY_BY_EFFECT`, the same separation
##      R40 and `Spiritual Water Art - Aoi` (R42 Part B) already made load-bearing.
##   8. **You Special Summon, to YOUR field, in the position YOU choose** — R15 Part F.
##      自分フィールドに特殊召喚 names the field the English leaves implicit; the opponent
##      chooses *which card*, never where it goes or who controls it. Neither text names a
##      position, so RULES_SPEC §5.5 [S1 p.24] applies and
##      `special_summon_one_any_position()` is correct — the deliberate opposite of
##      `Damage Condenser`, whose text *does* say "in Attack Position".
##   9. **The chosen card is revealed to both players; nothing else about the hand is** —
##      R15 Part H. Every branch that follows a real choice puts the card into a public
##      zone anyway, so the reveal gives nothing away; doing it at the moment of the choice
##      is what makes the branch verifiable. The reveal lives inside the primitive so a
##      caller cannot forget it. When detail 3's gate fires, nothing is revealed at all.
##  10. **The Damage Step is closed, and the reason is the default** — R15 Part G. The
##      supplement is silent; the window is 相手モンスターの攻撃宣言時, which is the Battle
##      Step. `DamageStepPermission.NONE` is therefore right, and it is the DEFAULT — which
##      is exactly why it has to be asserted rather than assumed. RULES_SPEC §10.7 warns
##      that "never offered in the Damage Step" proves nothing here, because
##      `ATTACK_DECLARED` cannot occur inside the Damage Step at all; the suite asserts
##      `ActivationRules.damage_step_ok()` **directly** instead, and R15 Part G says so, so
##      that assertion is not later mistaken for a redundant one.
##  11. **The condition may NOT read `ctx.trigger_event`.** This is a Trap's own
##      `CARD_ACTIVATION`, offered as a RESPONSE in a window whose events match
##      `trigger_events`, and `DuelEngine._activation_actions()` reaches it through
##      `ActivationRules.can_activate(..., null)` — so `ctx.trigger_event` is **null**
##      here and a condition written against it would be silently false forever. The
##      attacker is read from `GameState.current_attacker`, which `BattleRules` sets at the
##      declaration and which `Kunai with Chain`, `Honest` and `Vampiric Koala` already
##      read the same way. `Damage Condenser` records this trap in full.
##
## **No new engine surface.** Three additions to `EffectPrimitives`, all of them operations
## over subsystems that already existed — the seeded `Rng` and `CardInstance.revealed_to` —
## plus the ordinary Special Summon route and the ordinary hand-to-Graveyard send. No new
## event kind, no new activation location, no new Damage Step permission, no new zone, no
## new Summon route, no new decision kind.
##
## Live in the V1 pool: this card is in `Fairy-Tail Tribute Guard`, whose 39 entries hold
## 21 monsters and 18 Spells/Traps, so both resolution branches are reached constantly with
## printed cards. An empty hand, a hand of Spells and Traps only, and a full Monster Zone
## are all ordinary board states. R15 Part I records what is NOT live — the Nomi / Spirit
## exclusion and the "You can only control 1" narrowing — and both are still implemented
## exactly and driven against synthetic cards.

const CARD_NAME := "A Hero Emerges"

const CLAUSE := "When an opponent's monster declares an attack: Your opponent chooses 1 " \
	+ "random card from your hand, then if it is a monster that can be Special Summoned, " \
	+ "Special Summon it. Otherwise, send it to the GY."

const EFFECT_ID := "random_hand_card_summoned_or_sent"


func effects() -> Array:
	var e := EffectDef.new(EFFECT_ID, CLAUSE)
	e.of_type(Enums.EffectType.CARD_ACTIVATION)
	# A Normal Trap is Spell Speed 2 [S1 p.44-45]; `of_type()` cannot derive it.
	e.with_spell_speed(Enums.SpellSpeed.SS2)
	e.activation_locations = [Enums.ActivationLocation.FIELD_FACE_DOWN]
	e.trigger_events = [GameEvent.Kind.ATTACK_DECLARED]
	# Detail 10. Stated rather than left implicit: `DamageStepPermission.NONE` is the
	# default, and a later change that granted this clause a permission in order to reach
	# some other window would otherwise break R15 Part G silently.
	e.damage_step(Enums.DamageStepPermission.NONE)
	e.ruling("R15")

	e.condition = func(ctx: EffectContext) -> bool:
		# Detail 11: the attacker comes from the battle state, never from the event.
		var attacker = ctx.state.current_attacker
		if attacker == null:
			return false
		var card: CardInstance = attacker
		# "When an OPPONENT'S monster declares an attack". Your own attack does not open
		# this window, and nothing else in the clause narrows the attacker — it is not
		# targeted, not read at resolution, and a direct attack qualifies exactly as an
		# attack on a monster does.
		if card.controller_id == ctx.controller_id:
			return false
		# Details 1 and 2 — the official ACTIVATION restriction, in one line. An empty
		# hand, a hand with no monster in it, and a hand whose monsters could not be placed
		# right now are all the same answer: the card cannot be activated.
		return not EffectPrimitives.hand_monsters_that_could_be_special_summoned(ctx,
			ctx.controller_id).is_empty()

	e.resolve = func(ctx: EffectContext) -> void:
		# Detail 3 — the gate that suppresses the random choice itself. This is the first
		# thing the resolution does, and deliberately so: fid 8193 says the pick is not
		# performed when the Summon has become impossible, so anything that happened before
		# this check would be observable and wrong.
		if EffectPrimitives.hand_monsters_that_could_be_special_summoned(ctx,
				ctx.controller_id).is_empty():
			ctx.log_note("nothing in the hand could be Special Summoned, so the effect "
				+ "does not apply and no card is chosen")
			return

		# Detail 5 and detail 9: the seeded generator picks, and the chosen card — and only
		# the chosen card — becomes known to both players.
		var chosen := EffectPrimitives.random_hand_card_chosen_by(ctx, ctx.opponent_id(),
			ctx.controller_id)
		if chosen == null:
			# Unreachable while the gate above holds: a non-empty candidate list means a
			# non-empty hand. Kept because it is the honest answer if that ever changes.
			ctx.log_note("there was no card to choose")
			return

		# Detail 6: ONE question decides the branch, so "not a monster" and "a monster this
		# effect cannot Special Summon" can never be answered differently.
		if EffectPrimitives.can_be_special_summoned_now(ctx, chosen):
			# Detail 8: your field, and your choice of face-up position.
			var summoned := EffectPrimitives.special_summon_one_any_position(ctx, [chosen],
				"Special Summon %s (chosen at random from your hand)" % chosen.card_name())
			if summoned != null:
				ctx.log_note("your opponent chose %s at random; it was Special Summoned"
					% summoned.card_name())
				return
			# The Summon was judged legal one line ago and then did not happen, which is an
			# engine-level contradiction rather than a rules outcome — master prompt 67
			# forbids papering over it. The card stays in the hand: the effect took the
			# Summon branch, and "Otherwise" is not reached.
			push_error("A Hero Emerges: a Special Summon judged legal did not happen")
			ctx.log_note("the Special Summon did not happen")
			return

		# Detail 7: a SEND out of your own hand, never a discard.
		if EffectPrimitives.send_from_hand_to_gy(ctx, chosen):
			ctx.log_note("your opponent chose %s at random; it was sent to the Graveyard"
				% chosen.card_name())
		else:
			ctx.log_note("the chosen card could not be sent to the Graveyard")

	return [e]
