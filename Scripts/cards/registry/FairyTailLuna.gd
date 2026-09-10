extends RefCounted

## Fairy Tail - Luna — LIGHT / Spellcaster / Level 4 / 1850 ATK / 1000 DEF.
##
## Official text (re-fetched live from the Konami card database for this batch, cid 12952,
## and diffed CHARACTER FOR CHARACTER against `Data/cards/cards.json` — identical, 378
## characters):
##
##   "When this card is Normal Summoned: You can add 1 Spellcaster monster with 1850 ATK
##    from your Deck to your hand. Once per turn (Quick Effect): You can target 1 face-up
##    monster your opponent controls; your opponent can send 1 card with that monster's name
##    from their Deck or Extra Deck to the GY to negate this effect, otherwise return both
##    this card and that monster to the hand."
##
## Research/CARD_RULINGS.md **R11**. Everything below that the English text does not say
## comes from cid 12952's 補足情報 (2022-03-26) and its three Q&A entries, read under
## `request_locale=ja`; nothing here is remembered.
##
## ---------------------------------------------------------------------------
## What clause ② needed that the engine did not have
## ---------------------------------------------------------------------------
##
## **An opponent-side decision made DURING resolution.** Every other card in this library
## asks only its own controller, through the single `EffectContext.decider` the engine
## attaches to the resolving link. The official wording puts the choice to 「相手」 — the
## player who does NOT control the resolving Chain Link — and the options come out of that
## player's own Deck and Extra Deck.
##
## The gate for that is generic and was written and green BEFORE this file existed:
## `EffectContext.ask_player()` plus `EffectPrimitives.player_may()` /
## `player_chooses_one()` / `player_chooses_up_to_one()`, proved by the opponent-decision
## section of `HiddenInfoTests`. **Nothing in the mechanism knows this card exists**: it
## takes a player id, and the card's own text is what decides which id goes in.
##
## ---------------------------------------------------------------------------
## The eight facts from the supplement, in the order the card uses them
## ---------------------------------------------------------------------------
##
##  1. **① is a Trigger Effect in the Monster Zone**, ② a Quick Effect in the Monster Zone.
##     「モンスターゾーンで発動できる誘発効果です。」/「…誘発即時効果です。」 Both are therefore
##     `FIELD_FACE_UP`, and ② is Spell Speed 2.
##
##  2. **② CANNOT BE ACTIVATED DURING THE DAMAGE STEP** — 「ダメージステップ中には発動でき
##     ません。」 The printed English text says nothing about the Damage Step. That is now
##     **seven batches running** in which the official supplement carried an activation
##     restriction the English print does not. Like `The Monarchs Awaken` the restriction is
##     satisfied by the engine's DEFAULT permission (`NONE`), so it costs no machinery — and
##     exactly like that card it is asserted directly against `ActivationRules.damage_step_ok()`
##     at every Damage Step sub-step, because a default that happens to be right is
##     indistinguishable from a default nobody checked.
##
##  3. **The resolution-time re-check is BOTH-OR-NOTHING, and it names the MONSTER ZONE.**
##     「処理時に、このモンスターと対象のモンスターがモンスターゾーンに存在する場合、『このカードと
##     対象のモンスターを持ち主の手札に戻す』処理を行います。」 and
##     「処理時に、このカードと対象のモンスターのうち少なくとも片方がモンスターゾーンに存在しなく
##     なった場合、処理は行われません（相手は対象の同名カードを墓地へ送ることもできません）。」
##
##     So if EITHER Luna or the target has left the Monster Zone, **nothing happens at all** —
##     not a partial return of the survivor, and the opponent is **not even offered** the
##     negation. This is the case `RULES_SPEC.md` §10.6 (a dead target costs only the
##     sentences that name it) does NOT cover, and the card's own supplement is what settles
##     it: "both … and …" is one process over two cards, and it is all or none. R11 Part E.
##
##  4. **The negation is offered only while the target is FACE-UP in the Monster Zone.**
##     「ただし、対象のモンスターがモンスターゾーンに表側表示で存在する場合、相手はその同名カード
##     １枚を…墓地へ送ることでこの効果を無効にできます。」 and, from the other side,
##     「処理時に、対象のモンスターが裏側守備表示になった場合、相手は対象の同名カードを墓地へ送る
##     ことができず、『このカードと対象のモンスターを持ち主の手札に戻す』処理を行います。」
##
##     A target that went face-down between activation and resolution is **still returned** —
##     it is still in the Monster Zone — but its controller loses the chance to stop it.
##     Face-down is therefore NOT the ordinary "the target is no longer legal" case, and
##     using `surviving_target()` plus a face-up check would have been wrong twice over.
##     R11 Part D.
##
##  5. **An UNAFFECTED target costs only itself.** 「『このカードと対象のモンスターを持ち主の
##     手札に戻す』処理を行う際に、対象のカードがこの効果を受けない場合、このカードだけが手札に
##     戻ります。」 Luna still goes back. This is batch 16's `EffectImmunity` gate seen from a
##     second card, and it needs **no code here at all**: the gate lives inside
##     `GameState.move_card()`, so the return of the target simply fails and the return of
##     Luna does not. Asserted directly all the same. R11 Part G.
##
##  6. **It is 持ち主の手札 — the OWNER's hand.** The printed English says only "to the hand".
##     `EffectPrimitives.return_to_hand()` passes no destination player and `move_card()`
##     forces the owner for every non-field zone, so a monster whose control was taken goes
##     back to the player who owns it, not to the player who was holding it.
##
##  7. **The send is a RESOLUTION PROCESS, not a cost, and it can be legally impossible.**
##     Q&A fid 20472 (2024-06-23) — under 「マクロコスモス」 the opponent cannot perform it at
##     all, 「自身のデッキやエクストラデッキに同名カードが存在していたとしても、その同名カードを
##     デッキから選ぶこと自体ができません」 — and the return then happens. So the negation is a
##     step *inside* this effect's resolution whose legality is checked when it is reached;
##     it is not paid up front and nothing about it is refunded. It is an ordinary send to
##     the Graveyard, so a "when this card is sent to the GY" trigger sees it. R11 Part F.
##
##  8. **A Monster Token is a legal target.** Q&A fid 262 (2017-03-24): the Token is chosen
##     normally, ceases to exist on leaving the field, and Luna 「自身は通常通り持ち主の手札に
##     戻る」. The V1 pool has no Tokens, so this is never live here and is recorded rather
##     than implemented as a branch that can never run.
##
## ---------------------------------------------------------------------------
## Two readings this card does NOT inherit, and why
## ---------------------------------------------------------------------------
##
## **It does not re-check CONTROL, and so it does not follow R29.** R29 decided that "1 card
## your opponent controls" is re-checked for control at resolution, at MEDIUM confidence and
## resting mostly on `Miyabi`'s own resolution sentence ("place that OPPONENT'S card…").
## Luna's resolution sentence names no controller — 「このカードと対象のモンスターを…」 — and
## its supplement enumerates the resolution-time cases in full and names **only** presence in
## the Monster Zone. Card-specific official guidance outranks a general inference, which is
## the precedent R40 Part C already made load-bearing. R11 Part E records the divergence and
## its confidence; it is asserted in both directions.
##
## **The "same name" test reads the CURRENT name.** Nothing in the V1 pool is ever treated as
## having another card's name, so current and printed coincide here; the coincidence is
## asserted against the real pool so it cannot rot. R11 Part C, the R40 Part F treatment.
##
## ---------------------------------------------------------------------------
## What this card deliberately does NOT add
## ---------------------------------------------------------------------------
##
## No new event kind, no new activation location, no new zone, no new Damage Step permission,
## no new Summon route, no new targeting machinery, and no card-specific decision code. One
## new `EffectContext` capability (ask a named player), four new `EffectPrimitives` siblings,
## and one previously declared-but-dead `Enums.DecisionKind` finally consumed
## (`SELECT_UP_TO` had zero users before this batch — the same dead-vocabulary shape batch 5
## found in `cannot_be_targeted`, batch 6 in `CONTROL_CHANGED` and batch 14 in
## `ATTACK_TARGET_SELECTED`).

const CARD_NAME := "Fairy Tail - Luna"

const SEARCH_ATK := 1850
const SPELLCASTER := "Spellcaster"

const CLAUSE_SEARCH := "When this card is Normal Summoned: You can add 1 Spellcaster " \
	+ "monster with 1850 ATK from your Deck to your hand."
const CLAUSE_BOUNCE := "Once per turn (Quick Effect): You can target 1 face-up monster " \
	+ "your opponent controls; your opponent can send 1 card with that monster's name " \
	+ "from their Deck or Extra Deck to the GY to negate this effect, otherwise return " \
	+ "both this card and that monster to the hand."


func effects() -> Array:
	return [_search_on_normal_summon(), _bounce_unless_negated()]


# ---------------------------------------------------------------------------
# Clause ① — "When this card is Normal Summoned: You can add 1 Spellcaster monster with
#             1850 ATK from your Deck to your hand."
# ---------------------------------------------------------------------------

func _search_on_normal_summon() -> EffectDef:
	var e := EffectDef.new("luna_search_1850_spellcaster", CLAUSE_SEARCH)
	e.of_type(Enums.EffectType.TRIGGER)
	# "You can add" — OPTIONAL, which is `EffectDef`'s default and is stated rather than
	# assumed because clause ② prints its own separate "You can".
	e.optionality = Enums.Optionality.OPTIONAL
	e.activation_locations = [Enums.ActivationLocation.FIELD_FACE_UP]
	# ONLY the Normal Summon event. `NORMAL_SUMMON_SUCCEEDED` is emitted for a Tribute
	# Summon as well as a Summon without Tributes — `SummonRules._complete_summon()` splits
	# only FLIP and SPECIAL off — which is exactly right: an Advance Summon IS a Normal
	# Summon [S1 p.22-23]. A Flip Summon and a Special Summon are not, and neither is a
	# Normal SET, so none of them appears here.
	e.trigger_events = [GameEvent.Kind.NORMAL_SUMMON_SUCCEEDED]
	e.ruling("R11")

	var search_target := EffectPrimitives.monster_with_exact_atk(SEARCH_ATK, SPELLCASTER)

	e.condition = func(ctx: EffectContext) -> bool:
		var ev: GameEvent = ctx.trigger_event
		if ev == null:
			return false
		# The event has to be about THIS copy: a second monster reaching the field must
		# not fire this one's clause.
		if int(ev.data.get("card_id", -1)) != ctx.source.id:
			return false
		# [S1 p.53]: an effect activated IN ORDER TO search cannot be activated when no
		# card in the Deck meets the requirement. This clause exists to search and does
		# nothing else, so the general restriction applies — R40 Part B. (Contrast
		# `The White Stone of Legend`, whose own supplement overrides it: R40 Part C.)
		return EffectPrimitives.can_search_deck(ctx, ctx.controller_id, search_target)

	e.resolve = func(ctx: EffectContext) -> void:
		var found := EffectPrimitives.search_deck_to_hand(ctx, ctx.controller_id,
			search_target,
			"Add 1 Spellcaster monster with %d ATK from your Deck to your hand"
				% SEARCH_ATK)
		if found == null:
			ctx.log_note("no Spellcaster monster with %d ATK was added" % SEARCH_ATK)
		else:
			ctx.log_note("added %s to the hand" % found.card_name())

	return e


# ---------------------------------------------------------------------------
# Clause ② — "Once per turn (Quick Effect): You can target 1 face-up monster your opponent
#             controls; your opponent can send 1 card with that monster's name from their
#             Deck or Extra Deck to the GY to negate this effect, otherwise return both
#             this card and that monster to the hand."
# ---------------------------------------------------------------------------

func _bounce_unless_negated() -> EffectDef:
	var e := EffectDef.new("luna_bounce_unless_opponent_negates", CLAUSE_BOUNCE)
	e.of_type(Enums.EffectType.QUICK)
	e.with_spell_speed(Enums.SpellSpeed.SS2)
	e.activation_locations = [Enums.ActivationLocation.FIELD_FACE_UP]
	# 「自分・相手ターンに１度」 — ONE use per turn, on either player's turn, and no
	# "you can only use this effect of 'Fairy Tail - Luna' once per turn" naming the card.
	# That is a soft once-per-turn on THIS COPY, the `Fairy Tail - Rella` shape, and it is
	# spent at ACTIVATION — so an effect the opponent negates has still used it up.
	e.opt_instance()
	# Fact 2: 「ダメージステップ中には発動できません。」 NONE is the engine's default; it is
	# written out because this card's restriction is a verified ruling and not an accident.
	e.damage_step_permission = Enums.DamageStepPermission.NONE
	e.targeting(1)
	e.ruling("R11")

	e.legal_targets = func(ctx: EffectContext) -> Array:
		# "1 FACE-UP monster your opponent controls" — `opponent_monsters()` is exactly the
		# controller check plus the face-up check, and nothing else qualifies the target.
		return EffectPrimitives.opponent_monsters(ctx)

	e.resolve = func(ctx: EffectContext) -> void:
		var luna: CardInstance = ctx.source
		var target = ctx.first_target()

		# Fact 3 — BOTH-OR-NOTHING, and the zone named is the MONSTER ZONE. Control is not
		# consulted: the supplement enumerates the resolution-time cases and names only
		# presence in a Monster Zone (R11 Part E, and the reason this card does not inherit
		# R29).
		if target == null \
				or luna.zone != Enums.Zone.MONSTER_ZONE \
				or target.zone != Enums.Zone.MONSTER_ZONE:
			ctx.log_note("this card or the target is no longer in a Monster Zone, so "
				+ "nothing is done and the opponent is not offered the negation")
			return

		# Fact 4 — the offer exists only while the target is FACE-UP. A face-down target is
		# still returned; its controller simply never gets the chance to stop it.
		var decider_id := ctx.opponent_id()
		if target.is_face_up():
			# "1 card with that monster's name, from THEIR Deck **or Extra Deck**" — one
			# look-through over both of the deciding player's private zones. Both V1 Extra
			# Decks are empty, so the Extra Deck half contributes nothing in this pool; it
			# is asked for anyway, because that is what the card says. R11 Part B.
			#
			# Everything about how that decision is offered, logged, kept out of the other
			# player's sight and prevented from leaking an empty Deck lives in the generic
			# primitive and its gate in `HiddenInfoTests`. Nothing about it is this card's.
			var sent := EffectPrimitives.player_may_send_from_deck_to_gy(ctx, decider_id,
				EffectPrimitives.has_name_of(target),
				"Send 1 card named \"%s\" from your Deck or Extra Deck to the GY to "
					% target.card_name() + "negate this effect?", true)
			if sent != null:
				EffectPrimitives.negate_own_effect(ctx, decider_id,
					"the opponent sent %s to the GY to negate this effect"
						% sent.card_name())
				return
			# Nothing was sent — declined, nothing to send, or a send that could not be
			# carried out. The official wording measures 「墓地へ送らなかった場合」, "if they
			# did not send it", so all three are the same case and the return happens.

		# 「墓地へ送らなかった場合、このカードと対象のモンスターを持ち主の手札に戻す」 — both
		# cards, each to its OWNER's hand (fact 6).
		#
		# `return_to_hand()` can legitimately fail for the target and not for Luna: fact 5,
		# a target that is unaffected by this effect is refused by the immunity gate inside
		# `move_card()` and only Luna goes back. Nothing here special-cases that — the gate
		# does it — but each half is reported so a failure is never silent.
		var luna_returned := EffectPrimitives.return_to_hand(ctx, luna)
		var target_returned := EffectPrimitives.return_to_hand(ctx, target)
		ctx.log_note("returned %s and %s to their owners' hands" % [
			"this card" if luna_returned else "nothing (this card stayed)",
			target.card_name() if target_returned else
				"nothing (%s was not returned)" % target.card_name()])

	return e
