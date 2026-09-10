extends RefCounted

## Fairy Tail - Sleeper — LIGHT / Spellcaster / Level 4 / 1850 ATK / 1000 DEF.
##
## Official text (re-fetched live from the Konami card database for this batch, cid 12625,
## and diffed CHARACTER FOR CHARACTER against `Data/cards/cards.json` — identical, 336
## characters):
##
##   "FLIP: You can Special Summon 1 monster from your hand.
##    When your opponent activates a Normal Spell/Trap Card (Quick Effect): You can
##    Tribute 1 other monster; the activated effect becomes "Change 1 face-up monster your
##    opponent controls to face-down Defense Position". You can only use this effect of
##    "Fairy Tail - Sleeper" once per turn."
##
## Research/CARD_RULINGS.md **R5**. Everything below that the English text does not say
## comes from cid 12625's 補足情報 (2020-07-04) and its four Q&A entries, read under
## `request_locale=ja`; nothing here is remembered.
##
## ---------------------------------------------------------------------------
## What clause ② needed that the engine did not have
## ---------------------------------------------------------------------------
##
## **An effect that REPLACES the text another Chain Link resolves.** The engine had two
## operations on a link — negate the activation, and negate the effect — and this is
## neither. The card is still activated, still occupies its link, still resolves, and a
## Normal Spell/Trap still reaches the Graveyard as a *resolved* card. Only the text is
## different.
##
## The gate for that is generic and was written and green BEFORE this file existed:
## `ChainLink.substituted_effect` / `resolving_effect()`,
## `ChainManager.substitute_link_effect()`, `GameEvent.Kind.CHAIN_LINK_EFFECT_SUBSTITUTED`
## and the substitution section of `ChainTests`. **Nothing in the mechanism knows this card
## exists.** RULES_SPEC.md §10.11.
##
## ---------------------------------------------------------------------------
## The counter-intuitive fact, and the one most likely to be implemented backwards
## ---------------------------------------------------------------------------
##
## **The replacement text becomes the OPPONENT's card's text, so its "your opponent" means
## THIS card's controller. Sleeper flips a monster on its OWN side of the field.**
##
## This reads like a bug and is not. It falls out of the substituted effect being resolved
## as the other card's effect — which is exactly what `substitute_activated_effect()` does
## by leaving the link's `controller_id` alone — and it is confirmed three ways:
##
##  1. the supplement measures the empty case against 「**自分**フィールドに表側表示のモンスターが
##     存在しない場合でも」. The supplement is written from Sleeper's controller's
##     perspective, so 自分's field is only the relevant field if that is where the
##     replacement looks;
##  2. Q&A fid 9677 says the effect 「**相手プレイヤーに**カードをセット（＝この場合、モンスターを
##     裏側守備表示に）**させる**」 — the OPPONENT is the one doing it;
##  3. the card is a **FLIP** monster. Re-arming clause ① — or any other Flip monster on
##     its controller's side — is the design intent, not a drawback bolted onto a negation.
##
## R5 Part B. It is asserted in both directions, because an implementation that resolved
## the replacement as *Sleeper's* effect would hit the wrong side of the field and every
## naive test would still pass.
##
## ---------------------------------------------------------------------------
## The six supplement facts, in the order the card uses them
## ---------------------------------------------------------------------------
##
##  1. **① is a Trigger Effect in the Monster Zone**, ② a Quick Effect in the Monster Zone.
##     「モンスターゾーンで発動できる誘発効果です。」/「…誘発即時効果です。」 Both are therefore
##     `FIELD_FACE_UP`, and ② is Spell Speed 2.
##
##  2. **① CAN BE ACTIVATED DURING THE DAMAGE STEP** —
##     「ダメージステップ中に条件を満たした場合でも発動できます。」 **This breaks an eight-batch
##     pattern, and in the opposite direction.** Every previous card whose supplement
##     carried a Damage Step fact the English text omitted was carrying a *restriction*
##     (`Burst Stream of Destruction`, `Damage Condenser`, `Honest`, `Witchcrafter Golem
##     Aruru`, `A Hero Emerges`, `The Monarchs Awaken`, `Fairy Tail - Luna`). This one is a
##     *permission*, and it is not a quirk: the ordinary way a Flip monster is turned
##     face-up is by being attacked, so the Damage Step is this clause's main line of play.
##     Taking the engine's default (`NONE`) would be **wrong** here — the exact inverse of
##     the last two batches, where the default happened to be right.
##
##  3. **② CANNOT be activated during the Damage Step** —
##     「ダメージステップ中には発動できません。」 That is the engine default, and it is written
##     out anyway for the reason batch 16 established: a default that happens to be right
##     is indistinguishable from a default nobody checked. Asserted at every sub-step.
##
##  4. **② must chain DIRECTLY to the Normal Spell/Trap it answers** —
##     「相手が通常魔法・通常罠カードを発動した時、その発動に直接チェーンして発動できます。」 So the
##     answered card must be the link immediately below, not merely somewhere underneath.
##     `opponent_normal_spell_trap_activation_below()` is that requirement and nothing else.
##
##  5. **The replacement CHOOSES at resolution; it does not target.** The Q&A wording is
##     「…１体を**選んで**裏側守備表示にする」 with no 「対象」 anywhere. Nothing is targeted: not
##     by the opponent's card (which was activated before Sleeper existed on the Chain),
##     and not by Sleeper. R5 Part C. The engine enforces it: a substituted link resolves
##     with an EMPTY target list.
##
##  6. **An empty field is a real outcome, not a failure.**
##     「処理時に、自分フィールドに表側表示のモンスターが存在しない場合でも、この効果は適用され…
##     （結果的に、発動した相手の通常魔法・通常罠カードの効果処理は何も行われなくなります。）」 The
##     substitution still HAPPENS; the replacement simply has nothing to act on, and the
##     opponent's card does nothing at all. **This is a vacuous-path trap** — an
##     implementation that quietly did nothing would look identical from the board — so
##     the substitution is asserted to have occurred separately from any visible effect.
##
## ---------------------------------------------------------------------------
## What survives the substitution — and why this card adds no code for it
## ---------------------------------------------------------------------------
##
## Official Q&A fid 8714 and fid 19695 are a PAIR with opposite outcomes:
##
##   * a restriction that resolves as part of the replaced effect is **replaced away**
##     (fid 8714, 「埋葬されし生け贄」);
##   * a restriction that is 「カードの効果の扱いではありません」 — an inherent restriction
##     applied at activation — **survives** (fid 19695, 「強欲で謙虚な壺」).
##
## The engine already gets both right, and not by luck:
## `ChainManager._resolve_link()` runs a card's `activation_confirmed` clauses off its own
## `definition.effects`, gated on `link.effect` — the ORIGINAL — while only the `resolve`
## is swapped. That is why `substitute_link_effect()` deliberately does not overwrite
## `link.effect`. Both halves are asserted in `ChainTests`, each against a control.
## R5 Part D, RULES_SPEC.md §10.11.
##
## ---------------------------------------------------------------------------
## Two facts recorded and NOT implemented, because they can never run in the V1 pool
## ---------------------------------------------------------------------------
##
##   * **fid 9677** — with one's own 「ダーク・シムルグ」 applying 「相手はカードをセットできない」,
##     ② cannot be activated **at all**, because the replacement would make the opponent
##     Set. No card in the V1 pool applies any such restriction (R5 Part E);
##   * **fid 24272** — ② does not itself count as an effect 「カードをセットする効果を含む」 for
##     another card's trigger condition: it is classified by what it does, not by what the
##     replacement says. No V1 pool card has such a trigger condition.
##
## These are deliberately NOT collapsed into each other: one reads a continuous restriction
## against the RESOLUTION, the other a trigger condition against the ACTIVATION.
##
## ---------------------------------------------------------------------------
## What this card deliberately does NOT add
## ---------------------------------------------------------------------------
##
## No new zone, no new Summon route, no new targeting machinery, no new once-per-turn
## shape, and no card-specific substitution code. One new `ChainLink` field pair, one new
## `ChainManager` operation, one new event kind, and three new `EffectPrimitives` siblings
## — all of them generic, all of them gated before this file was written.

const CARD_NAME := "Fairy Tail - Sleeper"

const CLAUSE_FLIP := "FLIP: You can Special Summon 1 monster from your hand."
const CLAUSE_SUBSTITUTE := "When your opponent activates a Normal Spell/Trap Card " \
	+ "(Quick Effect): You can Tribute 1 other monster; the activated effect becomes " \
	+ "\"Change 1 face-up monster your opponent controls to face-down Defense " \
	+ "Position\". You can only use this effect of \"Fairy Tail - Sleeper\" once per turn."

## The text the substituted card comes to carry. Quoted from the official English, and
## built by a generic primitive because it is not this card's behaviour — it is the other
## card's, for one resolution.
const REPLACEMENT_TEXT := "Change 1 face-up monster your opponent controls to " \
	+ "face-down Defense Position"


func effects() -> Array:
	return [_flip_special_summon(), _substitute_opponent_normal_spell_trap()]


# ---------------------------------------------------------------------------
# Clause ① — "FLIP: You can Special Summon 1 monster from your hand."
# ---------------------------------------------------------------------------

func _flip_special_summon() -> EffectDef:
	var e := EffectDef.new("flip_special_summon_from_hand", CLAUSE_FLIP)
	e.of_type(Enums.EffectType.FLIP)
	# "You can" — OPTIONAL, which is the default and is stated because `Crystal Seer`, the
	# pool's only other FLIP monster, is MANDATORY and the contrast is the whole reason
	# `Enums.Optionality` exists on a Flip effect at all.
	e.optionality = Enums.Optionality.OPTIONAL
	e.activation_locations = [Enums.ActivationLocation.FIELD_FACE_UP]
	e.trigger_events = [GameEvent.Kind.CARD_FLIPPED_FACE_UP]
	# Fact 2 — 「ダメージステップ中に条件を満たした場合でも発動できます。」 A Flip monster turned
	# face-up by an attacker becomes a Chain Link in Damage Step sub-step 4, which is what
	# `MANDATORY_TRIGGER` describes for the trigger system: it is collected there rather
	# than offered as a fast-effect choice. The clause's own optionality is a separate
	# axis and is set above — the player is still asked whether to use it.
	e.damage_step_permission = Enums.DamageStepPermission.MANDATORY_TRIGGER
	e.ruling("R5")

	e.condition = func(ctx: EffectContext) -> bool:
		# THIS card being flipped face-up, not any card.
		var ev: GameEvent = ctx.trigger_event
		if ev == null or int(ev.data.get("card_id", -1)) != ctx.source.id:
			return false
		# "Special Summon 1 monster from your hand" — an effect activated IN ORDER TO
		# Special Summon cannot be activated with nothing to Summon and nowhere to put it.
		# The same list is re-checked at resolution, by the same function, so the two
		# checks cannot drift apart.
		return not EffectPrimitives.hand_monsters_that_could_be_special_summoned(
			ctx, ctx.controller_id).is_empty()

	e.resolve = func(ctx: EffectContext) -> void:
		var candidates := EffectPrimitives.hand_monsters_that_could_be_special_summoned(
			ctx, ctx.controller_id)
		if candidates.is_empty():
			ctx.log_note("no monster in the hand can be Special Summoned")
			return
		# The text names no position, so the summoning player picks one.
		var summoned := EffectPrimitives.special_summon_one_any_position(ctx, candidates,
			"Special Summon 1 monster from your hand")
		if summoned == null:
			ctx.log_note("no monster was Special Summoned")
		else:
			ctx.log_note("Special Summoned %s from the hand" % summoned.card_name())

	return e


# ---------------------------------------------------------------------------
# Clause ② — "When your opponent activates a Normal Spell/Trap Card (Quick Effect):
#             You can Tribute 1 other monster; the activated effect becomes '…'."
# ---------------------------------------------------------------------------

func _substitute_opponent_normal_spell_trap() -> EffectDef:
	var e := EffectDef.new("substitute_opponent_normal_spell_trap_effect",
		CLAUSE_SUBSTITUTE)
	e.of_type(Enums.EffectType.QUICK)
	e.with_spell_speed(Enums.SpellSpeed.SS2)
	e.activation_locations = [Enums.ActivationLocation.FIELD_FACE_UP]
	e.trigger_events = [GameEvent.Kind.EFFECT_ACTIVATED]
	# "You can only use this effect of 'Fairy Tail - Sleeper' once per turn" — the effect
	# is named, so this is per player + name + effect, NOT per instance. A second copy of
	# the card could not use it either. Spent at ACTIVATION, so an activation that ends up
	# changing nothing has still used it up.
	e.opt_named_effect()
	# Fact 3 — 「ダメージステップ中には発動できません。」 NONE is the engine's default; written
	# out because this is a verified ruling and not an accident.
	e.damage_step_permission = Enums.DamageStepPermission.NONE
	e.ruling("R5")

	e.condition = func(ctx: EffectContext) -> bool:
		# Fact 4 — the opponent's NORMAL Spell/Trap, activated DIRECTLY below this link.
		if EffectPrimitives.opponent_normal_spell_trap_activation_below(ctx) == null:
			return false
		# "Tribute 1 other monster" — a cost that cannot be paid makes the activation
		# illegal, not merely ineffective.
		return EffectPrimitives.can_pay_tribute_cost(ctx, _tribute_candidates(ctx), 1)

	e.pay_cost = func(ctx: EffectContext) -> bool:
		var paid := EffectPrimitives.pay_tribute_cost(ctx, _tribute_candidates(ctx), 1,
			"Tribute 1 other monster for Fairy Tail - Sleeper")
		if paid.is_empty():
			return false
		EffectPrimitives.record_cost(ctx, "tributed", paid)
		return true

	e.resolve = func(ctx: EffectContext) -> void:
		# The link is re-found at resolution rather than carried from activation: the
		# Chain may have changed underneath, and a card that is no longer there to be
		# substituted must produce nothing rather than a stale write.
		var link := EffectPrimitives.opponent_normal_spell_trap_activation_below(ctx)
		if link == null:
			ctx.log_note("the activation this card answered is no longer on the Chain, "
				+ "so there is nothing to change")
			return
		# The replacement is resolved as the SUBSTITUTED card's effect, under ITS
		# controller — which is what makes its "your opponent" mean this card's own
		# controller. Nothing here says so; leaving the link's controller alone does.
		EffectPrimitives.substitute_activated_effect(ctx, link,
			EffectPrimitives.become_change_opponent_monster_face_down(REPLACEMENT_TEXT))

	return e


## "Tribute 1 OTHER monster" — every monster this card's controller could Tribute
## except this card itself. The word is "other", and dropping it would let Sleeper
## Tribute itself and then substitute an effect from the Graveyard.
func _tribute_candidates(ctx: EffectContext) -> Array:
	return EffectPrimitives.tribute_cost_candidates(ctx,
		func(card: CardInstance) -> bool:
			return card.id != ctx.source.id)
