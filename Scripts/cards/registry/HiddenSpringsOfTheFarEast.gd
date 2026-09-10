extends RefCounted

## Hidden Springs of the Far East — Field Spell.
##
## Official text (re-fetched live from the Konami card database for this batch, cid 16027,
## and diffed CHARACTER FOR CHARACTER against `Data/cards/cards.json` — identical, 573
## characters):
##
##   "Once per turn, during the Main Phase 2: The turn player can activate this effect;
##    they gain 500 LP, and until the end of this turn apply these effects.
##    ●The Normal and Special Summons of their monsters cannot be negated.
##    ●If they activate a Spell/Trap Card, or monster effect, that includes an effect that
##     Special Summons a monster, that activation cannot be negated.
##    ●Their opponent cannot target Set Spells/Traps they control with card effects, also
##     they cannot be destroyed by their opponent's card effects.
##    You can only activate 1 "Hidden Springs of the Far East" per turn."
##
## Research/CARD_RULINGS.md **R14**. Everything below that the English text does not say
## comes from cid 16027's 補足情報 (2021-01-16), read under `request_locale=ja`.
##
## **This card has NO Q&A entries** — 「このカードに関連するＱ＆Ａはありません。」 — so the
## supplement is the entire authority and there is no second source to cross-check it
## against. Every other ruling closed in batches 13–18 had at least one Q&A entry, and in
## batches 13, 15 and 16 the Q&A carried facts the supplement did not. Anything below that
## the three supplement bullets do not cover is an INFERENCE and is labelled as one.
##
## ---------------------------------------------------------------------------
## §8 was WRONG about what this card needs, and it is worth recording why
## ---------------------------------------------------------------------------
##
## §8 called this "three or four subsystems in one card" and led with **the Field Spell
## Zone**. The Field Spell Zone already existed and was fully wired — `Enums.Zone.FIELD_ZONE`,
## `PlayerState.field_zone`, Field Spell placement and replacement in `DuelEngine`, and two
## cards already reading it. **Main Phase 2** already existed too (`Enums.Phase.MAIN_2` plus
## `EffectDef.legal_phases`), and so did the LP gain and both once-per-turn shapes this card
## needs. That is §8's eighth consecutive misprediction, pessimistic this time rather than
## optimistic.
##
## What was genuinely new is **two** things, not four: an effect activated by the TURN
## PLAYER rather than by the controller, and the negation-immunity gate. Both are generic,
## both were written and green before this file existed, and neither names this card.
##
## ---------------------------------------------------------------------------
## The three supplement facts, in the order the card uses them
## ---------------------------------------------------------------------------
##
##  1. **It creates a Chain Block.** 「フィールドで発動できるチェーンブロックの作られる効果です。」
##     So ① is an ordinary activation: it goes on the Chain, it can be responded to, and it
##     can itself be negated. Note that its own second bullet does **not** protect it —
##     ① includes no Special Summon — which is asserted rather than assumed.
##
##  2. **EITHER player may activate it, in their OWN Main Phase 2.**
##     「このカードがフィールドゾーンに表側表示で存在する場合、お互いのプレイヤーは、自身のメイン
##     フェイズ２にこの効果を発動できます。」 Since a player only has a Main Phase 2 on their own
##     turn, the eligible activator is exactly the **turn player** — and that may be the
##     **opponent of this card's controller**, who then gets the LP and all three
##     protections. 「自分」 throughout ① means *the player who activated the effect*, never
##     "the player who controls the Field Spell". R14 Part A.
##
##     The two once-per-turn clauses are **different restrictions** and both are needed:
##       * 「このカード名のカードは１ターンに１枚しか発動できない。」 — a HARD once-per-turn on
##         activating the **card**, by name. That is `opt_named_activation()`, and it lives
##         on the card-activation clause, not on ①;
##       * 「お互いのプレイヤーは１ターンに１度…発動できる。」 — once per turn **per player** on
##         the ① effect. `opt_named_effect()` is already keyed on the ACTIVATING player, so
##         each player gets their own use and neither can take the other's.
##
##  3. **The LP gain and all three ● effects are applied SIMULTANEOUSLY.**
##     「この効果の処理時に、『自分は５００ＬＰ回復し』の処理と、３つの『●』の効果の適用を行います。
##     （これらは同時に行われます。）」 One resolution, four things, no ordering between them.
##     There is no state in which the LP has been gained but a protection is not yet
##     applying, which is why `NegationImmunity.grant_all()` is one call rather than three.
##
## ---------------------------------------------------------------------------
## The three protections, and the narrowings that are easy to lose
## ---------------------------------------------------------------------------
##
## All three belong to `NegationImmunity` and none of them is implemented here. What this
## card does is name the player and the turn; the gate decides what that means. The
## narrowings, each of which is asserted with a paired control:
##
##   * **a FLIP Summon is NOT protected.** 「召喚・特殊召喚」 names two routes and the OCG
##     treats 「反転召喚」 as a third. An inference from omission, at MEDIUM confidence,
##     because there is no Q&A to confirm it;
##   * **only ACTIVATION negation** is blocked by the second bullet, and only for an
##     activation that **includes** a Special Summon. Negating the EFFECT is a different
##     operation and stays reachable;
##   * **only SET Spell/Traps** are protected by the third, **only against the OPPONENT's**
##     effects, and only against **card effects** — battle and rules destruction are
##     untouched. A face-up card is not protected, *including this one*.
##
## ---------------------------------------------------------------------------
## What this card deliberately does NOT add
## ---------------------------------------------------------------------------
##
## No new zone, no new phase, no new once-per-turn shape, no new LP machinery, and no
## card-specific negation code. Two declarative `EffectDef` markers, one new rules file,
## four gated call sites, and one line in the end-of-turn cleanup.

const CARD_NAME := "Hidden Springs of the Far East"

const LP_GAIN := 500

const CLAUSE_ACTIVATE := "Activate this Field Spell. You can only activate 1 " \
	+ "\"Hidden Springs of the Far East\" per turn."
const CLAUSE_EFFECT := "Once per turn, during the Main Phase 2: The turn player can " \
	+ "activate this effect; they gain 500 LP, and until the end of this turn apply " \
	+ "these effects. ●The Normal and Special Summons of their monsters cannot be " \
	+ "negated. ●If they activate a Spell/Trap Card, or monster effect, that includes " \
	+ "an effect that Special Summons a monster, that activation cannot be negated. " \
	+ "●Their opponent cannot target Set Spells/Traps they control with card effects, " \
	+ "also they cannot be destroyed by their opponent's card effects."


func effects() -> Array:
	return [_activate_the_field_spell(), _turn_player_effect()]


# ---------------------------------------------------------------------------
# The card activation itself.
# "You can only activate 1 'Hidden Springs of the Far East' per turn."
# ---------------------------------------------------------------------------

func _activate_the_field_spell() -> EffectDef:
	var e := EffectDef.new("activate_hidden_springs", CLAUSE_ACTIVATE)
	e.of_type(Enums.EffectType.CARD_ACTIVATION)
	e.mandatory()
	e.activation_locations = [Enums.ActivationLocation.HAND,
		Enums.ActivationLocation.FIELD_FACE_DOWN]
	# 「このカード名のカードは１ターンに１枚しか発動できない。」 — a HARD once-per-turn on
	# activating the CARD, per player and per name. Distinct from the per-player once-per
	# turn on the ① effect below, which is a different clause with a different key.
	e.opt_named_activation()
	e.ruling("R14")

	# A Field Spell's activation does nothing by itself: it simply becomes face-up in the
	# Field Zone, which `DuelEngine` already does on the ACTIVATE_CARD route. The clause
	# still resolves, so it still needs a `resolve` — a missing one is an error by design
	# (master prompt 67), not an empty case.
	e.resolve = func(ctx: EffectContext) -> void:
		ctx.log_note("%s is now face-up in the Field Zone" % CARD_NAME)

	return e


# ---------------------------------------------------------------------------
# Clause ① — "Once per turn, during the Main Phase 2: The turn player can activate this
#             effect; they gain 500 LP, and until the end of this turn apply these
#             effects. ●…●…●…"
# ---------------------------------------------------------------------------

func _turn_player_effect() -> EffectDef:
	var e := EffectDef.new("turn_player_gains_lp_and_protections", CLAUSE_EFFECT)
	e.of_type(Enums.EffectType.IGNITION)
	e.activation_locations = [Enums.ActivationLocation.FIELD_FACE_UP]
	# Fact 2 — 「お互いのプレイヤーは、自身のメインフェイズ２にこの効果を発動できます。」
	# The eligible activator is the TURN PLAYER, who may be this card's controller's
	# opponent. This marker is the ONLY thing that lets a foreign card offer an effect.
	e.by_turn_player()
	# "during the Main Phase 2" — and only there. A player has a Main Phase 2 only on their
	# own turn, which is the other half of "the turn player".
	e.in_phases([Enums.Phase.MAIN_2])
	# 「お互いのプレイヤーは１ターンに１度」 — once per turn PER PLAYER. `opt_named_effect()` is
	# already keyed on the activating player, so each player has their own use and neither
	# can consume the other's. This is NOT the per-instance shape: a second copy of the
	# card would not give the same player a second use.
	e.opt_named_effect()
	# An Ignition Effect in an open Main Phase; the Damage Step never arises. The engine's
	# default refusal is correct here and is asserted rather than assumed.
	e.damage_step_permission = Enums.DamageStepPermission.NONE
	e.ruling("R14")

	e.resolve = func(ctx: EffectContext) -> void:
		# 「自分」 throughout this clause is the player who ACTIVATED the effect — the turn
		# player — and not this card's controller. `ctx.controller_id` is the activating
		# player, which is exactly right and is the reason this reads as if there were no
		# distinction at all.
		var pid := ctx.controller_id
		ctx.state.change_life_points(pid, LP_GAIN, CARD_NAME, ctx.source.id)
		# Fact 3 — 「これらは同時に行われます。」 One call, because there is no state in which
		# some of the three apply and others do not.
		NegationImmunity.grant_all(ctx.state, pid)
		ctx.log_note("player %d gained %d LP and, until the end of this turn: their "
			% [pid, LP_GAIN]
			+ "Normal and Special Summons cannot be negated; an activation of theirs "
			+ "that includes a Special Summon cannot be negated; and their Set "
			+ "Spell/Traps cannot be targeted or destroyed by their opponent's effects")

	return e
