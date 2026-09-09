extends RefCounted

## Witchcrafter Golem Aruru — LIGHT / Spellcaster / Level 8 / 2800 ATK / 0 DEF, Effect Monster.
## One copy, deck 2 ("Fairy-Tail Tribute Guard").
##
## Official English text (verified against the Konami card database, cid 14483; see
## `Data/cards/cards.json`, and re-fetched from the live database on 2026-09-08 and diffed
## against it character for character before this file was written):
##
##   "When your opponent activates a card or effect that targets a Spellcaster monster(s) you
##    control, or targets it for an attack (Quick Effect): You can target 1 card your opponent
##    controls, or 1 "Witchcrafter" Spell in your GY; Special Summon this card from your hand,
##    and if you do, return that targeted card to the hand. You can only use this effect of
##    "Witchcrafter Golem Aruru" once per turn. Once per turn, during your opponent's Standby
##    Phase: Return this card to the hand."
##
## Official Japanese text and supplemental information, cid 14483, supplement dated
## **2020-07-04**, plus Q&A **fid 22558** (2022-12-30), both fetched with `request_locale=ja`
## per R40's methodology note. The full record is `CARD_RULINGS.md` **R13**, which this file
## does not restate — what follows is only the mapping from each settled fact onto the code.
##
##   1. **Clause ① is ONE clause with TWO trigger windows, and it is a QUICK EFFECT activated
##      IN THE HAND.** 「手札で発動できる誘発即時効果です。」 — `EffectType.QUICK` (Spell Speed 2)
##      with `ActivationLocation.HAND`. The printed English puts both triggers in one sentence
##      under one "(Quick Effect)", and the supplement describes ① as one 誘発即時効果 with two
##      windows, so this is **one** `EffectDef` declaring **two** `trigger_events`.
##
##      This is where Aruru and `Maiden with Eyes of Blue` genuinely differ and must not be
##      made to match. Maiden prints two sentences and only the first says "(Quick Effect)",
##      so Maiden is a Quick Effect **plus** a Spell Speed 1 Trigger Effect. R13 Part B.
##
##   2. **CANNOT be activated during the Damage Step.** 「ダメージステップ中には発動できません。」
##      This is an **activation restriction the printed English text does not carry** — the
##      fourth batch running that §8's standing warning has been right. It needs **no code at
##      all**: `damage_step_permission` defaults to `DamageStepPermission.NONE` and
##      `ActivationRules.damage_step_ok()` answers false for `NONE` inside a Damage Step. It is
##      asserted in both directions precisely *because* it is the default — a later edit that
##      granted this clause a permission would silently break the ruling. R13 Part A.
##
##   3. **The Spellcaster must be FACE-UP and in YOUR MONSTER ZONE**, which is narrower than
##      the printed "a Spellcaster monster(s) you control":
##      「自分のモンスターゾーンの表側表示の魔法使い族モンスター」. `PlayerState.face_up_monsters()`
##      is exactly that set — the Monster Zones plus the Extra Monster Zone, face-up — so a
##      Trap Monster sitting in a Spell & Trap Zone does not qualify and neither does a
##      face-down monster, whose Race is not a property either player may act on. The Race is
##      read with `CardInstance.current_race()`, the field reader (R33), never the printed one.
##      R13 Part C.
##
##   4. **The targeting trigger is the OPPONENT's activation only.** 「相手が効果を発動した時」.
##      `EffectPrimitives.is_targeted_by_a_live_activation()` — shipped for `Maiden with Eyes
##      of Blue` — does not ask whose activation it is, because Maiden's text does not care.
##      This card needed the one genuinely new primitive in batch 14,
##      `is_targeted_by_a_live_opponent_activation()`, written as a sibling so Maiden's
##      behaviour could not move. R13 Part C.
##
##   5. **A multi-target opponent effect qualifies when ONE of its targets is yours.** Official
##      Q&A fid 22558. The Chain walk is per card (`link.target_ids.has(card.id)`), so this
##      falls out rather than being coded for; it is asserted anyway, because comparing the
##      whole target set or only its first entry would pass every single-target test. R13 Part D.
##
##   6. **The attack window keys on `GameEvent.Kind.ATTACK_TARGET_SELECTED`**, which existed
##      with one emitter and **zero readers** until now — the dead-vocabulary shape batch 5
##      found in `cannot_be_targeted` and batch 6 in `CONTROL_CHANGED`. It is emitted only for
##      a **non-direct** attack, which is exactly 「攻撃対象に選択された時」, so a direct attack
##      correctly opens no window. The condition still reads the authoritative battle state
##      rather than the event, because a Quick Effect is offered with **no** event
##      (`DuelEngine._activation_actions()` passes null) — the same reason Maiden's clause 1
##      reads the Chain.
##
##   7. **It TARGETS 1 card, from a union of two pools.** 「…１枚または…１枚を対象として発動できる」
##      — "1 card your opponent controls, **or** 1 'Witchcrafter' Spell in your GY". Exactly one
##      target out of a heterogeneous candidate list, so membership plus a count of 1 is a
##      complete check and `targets_valid` is **not** needed (contrast `Kunai with Chain`,
##      which chooses two targets of different kinds).
##
##   8. **RESOLUTION ORDER, and the fact that decides whether this card is right.**
##      「処理時に、『このカードを特殊召喚し』の処理を行います。特殊召喚に成功した場合、『そのカードを
##      手札に戻す』処理を行います。」 The Special Summon happens **first**; the bounce happens
##      **only if it succeeded** (the printed "and if you do"). And:
##      「処理時に、対象のカードがフィールドに存在しない場合、このカードを特殊召喚する処理のみを行います。」
##      — **a dead target does NOT make the effect fizzle**; the Special Summon still happens.
##      That inverts the ordinary reading of a single-target effect and no English-only reading
##      would have found it. R13 Part E.
##
##   9. **The two are treated as SIMULTANEOUS.** 「特殊召喚の処理と手札に戻す処理は同時に行われた
##      ものとして扱います。」 The engine gives this for free: a Chain Link resolves without
##      interruption and the events it emits are collected into one trigger check afterwards.
##      What the suite asserts is the observable consequence — no Chain Link forms between the
##      Summon and the bounce.
##
##  10. **The target is re-checked at resolution by re-running this clause's OWN candidate
##      builder.** "1 card your opponent controls" is the wording R29 already decided is
##      re-checked for CONTROL, so R13 inherits R29 rather than reopening it (and inherits its
##      MEDIUM confidence). Re-running `_candidates()` rather than hand-writing a second test
##      is what makes the field branch and the GY branch answer the *same* question and makes
##      drift between activation and resolution impossible. R13 Part F.
##
##  11. **The bounce goes to the target's OWNER's hand.** `EffectPrimitives.return_to_hand()`
##      passes no `to_player` and `GameState.move_card()` forces the owner, the same as
##      `Compulsory Evacuation Device`. Ownership is never consulted when choosing the target —
##      control is what the text names (R29) — so a card this player owns but the opponent
##      controls is a legal target and comes back to this player's own hand.
##
##  12. **The GY branch is NEVER live in the V1 pool.** `Witchcrafter Golem Aruru` is the only
##      card with "Witchcrafter" in its name in either deck and it is a Monster, so no
##      "Witchcrafter" **Spell** exists. Implemented in full and tested against a synthetic one,
##      the R21 / R23 treatment, with a real-pool assertion in the other direction. A
##      "Witchcrafter" **Trap** is not a legal target: the text says Spell and so does
##      「魔法カード」. R13 Part G.
##
##  13. **Clause ② is a MANDATORY Trigger Effect in the Monster Zone.**
##      「モンスターゾーンで発動する誘発効果です。」「相手のスタンバイフェイズごとに１度、必ず発動します。」
##      `mandatory()` + `opt_instance()` + `FIELD_FACE_UP`, keyed on `PHASE_CHANGED` and gated
##      by `event_is_phase_change_to(..., ctx.opponent_id())` — the
##      `Nefarious Archfiend Eater of Nefariousness` shape, reused unchanged.
##
##  14. **"You can only use this effect of 'Witchcrafter Golem Aruru' once per turn"** governs
##      ① only — the Japanese says 「このカード名の①の効果は」 explicitly. So `opt_named_effect()`
##      on ①, and **no restriction group**: the two clauses do **not** share an allowance, which
##      is the opposite of `Maiden with Eyes of Blue` (R37) and is worth stating because the two
##      cards otherwise look alike.
##
## **What this card deliberately does NOT add.** No new activation location, no new event kind,
## no new Damage Step permission, no new zone, no new summon route, no new targeting machinery.
## One `EffectPrimitives` sibling and two clauses built out of shipped parts.

const CARD_NAME := "Witchcrafter Golem Aruru"

const ARCHETYPE := "Witchcrafter"
const SPELLCASTER := "Spellcaster"

const CLAUSE_QUICK := "When your opponent activates a card or effect that targets a " \
	+ "Spellcaster monster(s) you control, or targets it for an attack (Quick Effect): You " \
	+ "can target 1 card your opponent controls, or 1 \"Witchcrafter\" Spell in your GY; " \
	+ "Special Summon this card from your hand, and if you do, return that targeted card to " \
	+ "the hand. You can only use this effect of \"Witchcrafter Golem Aruru\" once per turn."

const CLAUSE_STANDBY := "Once per turn, during your opponent's Standby Phase: Return this " \
	+ "card to the hand."

const QUICK_EFFECT_ID := "summon_from_hand_and_bounce_when_a_spellcaster_is_targeted"
const STANDBY_EFFECT_ID := "return_this_card_to_hand_in_opponent_standby_phase"


func effects() -> Array:
	return [_quick_bounce(), _opponent_standby_return()]


# ---------------------------------------------------------------------------
# The two questions clause ① asks, each asked in exactly one place
# ---------------------------------------------------------------------------

## The face-up Spellcaster monsters in THIS player's Monster Zones — detail 3.
##
## `face_up_monsters()` is the Monster Zones plus the Extra Monster Zone, so a Trap Monster
## occupying a Spell & Trap Zone is correctly outside it, and a face-down monster is too.
static func _my_face_up_spellcasters(ctx: EffectContext) -> Array:
	var out: Array = []
	for entry in ctx.me().face_up_monsters():
		var card: CardInstance = entry
		if card.definition == null:
			continue
		if card.current_race() == SPELLCASTER:
			out.append(card)
	return out


## Is clause ①'s printed trigger condition satisfied right now?
##
## Both windows are decided here so the `condition` cannot drift from what the suite drives:
##
##   * **the targeting window** — one of my face-up Monster-Zone Spellcasters is a target of a
##     live, un-negated Chain Link activated by the OPPONENT (details 3, 4, 5);
##   * **the attack window** — one of them is the monster the current attack was declared
##     against (detail 6). `is_current_attack_target()` reads the authoritative battle state
##     and answers false for a direct attack, so "attack TARGET" really means one.
##
## "During the Damage Step" needs nothing here: `damage_step_permission` is `NONE`, so
## `ActivationRules.damage_step_ok()` refuses the whole clause inside a Damage Step (detail 2).
## Unlike `Honest`, this clause's window is not a *named* part of the Battle Phase, so the
## `RULES_SPEC.md` §7.2 trap that caught `Honest` does not apply: there is nothing to re-state.
static func _trigger_is_live(ctx: EffectContext) -> bool:
	for entry in _my_face_up_spellcasters(ctx):
		var caster: CardInstance = entry
		if EffectPrimitives.is_targeted_by_a_live_opponent_activation(ctx, caster):
			return true
		if EffectPrimitives.is_current_attack_target(ctx, caster):
			return true
	return false


## "1 card your opponent controls, or 1 'Witchcrafter' Spell in your GY" — detail 7.
##
## Called at ACTIVATION to publish the candidates and again at RESOLUTION to ask whether the
## chosen one is still among them (detail 10). One builder, so the two can never disagree.
static func _candidates(ctx: EffectContext) -> Array:
	var out: Array = EffectPrimitives.opponent_field_cards(ctx)
	for entry in ctx.me().graveyard:
		var card: CardInstance = entry
		if card == null or card.definition == null:
			continue
		# "Witchcrafter SPELL" — a Trap of the same archetype is not a legal target, and
		# `is_spell()` is the current reader rather than the printed one for the same reason
		# `current_race()` is above.
		if not card.is_spell():
			continue
		if not EffectPrimitives.name_matches_archetype(card, ARCHETYPE):
			continue
		out.append(card)
	return out


## The chosen target, if it is STILL a legal target for this clause; null otherwise.
## Never used to decide whether the Special Summon happens — detail 8 forbids that.
static func _surviving_target(ctx: EffectContext):
	var chosen = ctx.first_target()
	if chosen == null:
		return null
	return chosen if _candidates(ctx).has(chosen) else null


# ---------------------------------------------------------------------------
# ① The Quick Effect, activated in the hand
# ---------------------------------------------------------------------------

func _quick_bounce() -> EffectDef:
	var e := EffectDef.new(QUICK_EFFECT_ID, CLAUSE_QUICK)
	# Detail 1: a Quick Effect (Spell Speed 2) activated IN THE HAND — one clause, two windows.
	e.of_type(Enums.EffectType.QUICK)
	e.from_locations([Enums.ActivationLocation.HAND])
	# Detail 6: the two windows this clause may be offered in. `TARGET_SELECTED` is emitted by
	# `ChainManager.add_link()` for any activation that chose targets; `ATTACK_TARGET_SELECTED`
	# by `BattleRules.declare_attack()` for a non-direct attack only.
	e.on_events([GameEvent.Kind.TARGET_SELECTED,
		GameEvent.Kind.ATTACK_TARGET_SELECTED])
	# Detail 7: exactly one target, out of a union of two pools.
	e.targeting(1)
	# Detail 14: the printed restriction governs ① alone, so there is no restriction group.
	e.opt_named_effect()
	e.ruling("R13")
	# Detail 2: `damage_step_permission` is deliberately left at its default `NONE`.

	e.condition = func(ctx: EffectContext) -> bool:
		return _trigger_is_live(ctx)

	e.legal_targets = func(ctx: EffectContext) -> Array:
		return _candidates(ctx)

	e.resolve = func(ctx: EffectContext) -> void:
		# Detail 8, first half: the Special Summon is performed FIRST and is NOT conditional
		# on the target. `special_summon_self()` re-checks the hand itself and asks for the
		# position, which the card does not fix.
		if not EffectPrimitives.special_summon_self(ctx, Enums.Zone.HAND):
			# "Special Summon this card from your hand, AND IF YOU DO, …" — no Summon means
			# no bounce, even when the target is still perfectly legal.
			ctx.log_note("%s could not be Special Summoned, so nothing is returned"
				% CARD_NAME)
			return
		ctx.log_note("Special Summoned itself from the hand")
		# Detail 8, second half: a target that is no longer legal costs the BOUNCE and
		# nothing else. This is the official ruling and it is the opposite of a fizzle.
		var target = _surviving_target(ctx)
		if target == null:
			ctx.log_note("the target is no longer a legal target, so only the Special "
				+ "Summon was performed")
			return
		# Detail 11: no `to_player`, so the card reaches its OWNER's hand.
		if EffectPrimitives.return_to_hand(ctx, target):
			ctx.log_note("returned %s to its owner's hand" % target.card_name())
		else:
			ctx.log_note("the return to the hand did not happen")

	return e


# ---------------------------------------------------------------------------
# ② The mandatory return during the opponent's Standby Phase
# ---------------------------------------------------------------------------

func _opponent_standby_return() -> EffectDef:
	var e := EffectDef.new(STANDBY_EFFECT_ID, CLAUSE_STANDBY)
	# Detail 13: a MANDATORY Trigger Effect activated in the Monster Zone.
	e.of_type(Enums.EffectType.TRIGGER)
	e.mandatory()
	e.on_events([GameEvent.Kind.PHASE_CHANGED])
	e.from_locations([Enums.ActivationLocation.FIELD_FACE_UP])
	e.in_phases([Enums.Phase.STANDBY])
	e.opt_instance()
	e.ruling("R13")

	e.condition = func(ctx: EffectContext) -> bool:
		# "during YOUR OPPONENT's Standby Phase" — the opponent is the turn player.
		if not EffectPrimitives.event_is_phase_change_to(ctx.trigger_event,
				Enums.Phase.STANDBY, ctx.opponent_id()):
			return false
		# "FIELD のこのカード" — it has to still be there. `from_locations` already says
		# face-up on the field; this re-states it so the resolution-time re-check below has
		# one meaning rather than two.
		return ctx.source.is_on_field() and ctx.source.is_face_up()

	e.resolve = func(ctx: EffectContext) -> void:
		# Re-checked at resolution for the reason R29 gives and `Honest`'s clause ① follows:
		# a copy flipped face-down or removed in response is no longer "this card on the
		# field". Nothing else may be returned in its place.
		if not (ctx.source.is_on_field() and ctx.source.is_face_up()):
			ctx.log_note("%s is no longer face-up on the field" % CARD_NAME)
			return
		if EffectPrimitives.return_to_hand(ctx, ctx.source):
			ctx.log_note("%s returned itself to the hand" % CARD_NAME)

	return e
