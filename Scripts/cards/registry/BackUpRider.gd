extends RefCounted

## Back-Up Rider — Normal Spell.
##
## Official text (verified against the Konami card database, cid 11848; see
## `Data/cards/cards.json`):
##
##   "Target 1 face-up monster on the field; it gains 1500 ATK until the end of this turn."
##
## One clause, no condition and no cost: everything before the semicolon is targeting, and
## everything after it is resolution. RULES_SPEC.md 10.
##
## The official supplement (cid 11848, 2015-04-25) gives three facts, all recorded in
## `CARD_RULINGS.md` **R41 Part E**, and this implementation asserts all three rather than
## assuming them:
##
##   1. **The target is a monster face-up in a MONSTER ZONE**, モンスターゾーンに表側表示で存在する
##      モンスター１体 — so "on the field" here is the Monster Zones, not every field zone.
##   2. **Either player's**, 自分のモンスターゾーンのモンスター、相手のモンスターゾーンのモンスターの
##      どちらも選択する事ができます. The English "on the field" is not narrowed to your own side,
##      and pumping an opponent's monster is a legal (if rarely useful) play that the card
##      does not forbid.
##   3. **The gain is NOT treated as the original ATK**, 元々の攻撃力の扱いではありません. The
##      engine already keeps these apart — `base_atk()` / `original_atk()` read the printed
##      value, `current_atk()` adds the modifiers — so this is an assertion, not a change.
##   4. **Two copies on the same monster in the same turn STACK to +3000**,
##      それぞれの効果が適用され…3000アップする. Deck 1 holds one copy, so that is exercised against
##      a second synthetic copy; it is the fact that proves the modifier is a per-application
##      addition rather than a set-to-value.
##
## **The duration is the whole implementation.** "Until the end of this turn" is exactly
## `EffectPrimitives.gain_atk_until_end_of_turn()`, whose `"end_of_turn"` modifiers
## `TurnFlow._end_of_turn_cleanup()` removes from every instance when the turn ends — whoever's
## turn it was, and whether or not this Spell is still anywhere. Nothing here is a continuous
## modifier: a continuous modifier vanishes the instant its source stops applying, and this
## card is in the Graveyard the moment it resolves.
##
## Two things this deliberately does NOT do, and both would be wrong in an observable way:
##
##   * it does not touch `CardDef` — that is the immutable canonical definition **shared by
##     every copy** of a card, so writing a temporary ATK into it would rewrite the card for
##     the whole Duel and for every other copy (RULES_SPEC.md 5.8);
##   * it does not use `CardInstance.atk_override`, which is what "make its ATK 0" needs
##     (`Hieratic Dragon of Tefnuit`). An override REPLACES the value and cannot stack; a
##     modifier ADDS to it and stacks, which is what fact 4 above requires.
##
## The modifier lives on the **target instance**, so `current_atk()` is authoritative
## everywhere — including `BattleRules.step_damage_calculation()`, which reads exactly that.
## Nothing is stored in, or read from, any UI state.

const CARD_NAME := "Back-Up Rider"

const CLAUSE := "Target 1 face-up monster on the field; it gains 1500 ATK until the end " \
	+ "of this turn."

const ATK_GAIN := 1500


func effects() -> Array:
	var e := EffectDef.new("target_monster_gains_1500_atk", CLAUSE)
	e.of_type(Enums.EffectType.CARD_ACTIVATION)
	e.activation_locations = [Enums.ActivationLocation.HAND,
		Enums.ActivationLocation.FIELD_FACE_DOWN]
	e.targeting(1)
	e.ruling("R41")

	e.legal_targets = func(ctx: EffectContext) -> Array:
		var out: Array = []
		for pid in range(GameState.PLAYER_COUNT):
			for entry in ctx.state.player(pid).face_up_monsters():
				out.append(entry as CardInstance)
		return out

	e.resolve = func(ctx: EffectContext) -> void:
		# Both halves of "1 FACE-UP monster on the field" are re-checked, for the reason
		# R29 gives: every word that made the target legal is part of what the effect needs
		# to still be true. A monster flipped face-down in response is not the thing that
		# was targeted, even though it never left its zone.
		var target := EffectPrimitives.surviving_target(ctx, Enums.Zone.MONSTER_ZONE)
		if target == null or not target.is_face_up():
			ctx.log_note("the target is no longer a face-up monster on the field")
			return
		if EffectPrimitives.gain_atk_until_end_of_turn(ctx, target, ATK_GAIN):
			ctx.log_note("%s gains %d ATK until the end of this turn"
				% [target.card_name(), ATK_GAIN])

	return [e]
