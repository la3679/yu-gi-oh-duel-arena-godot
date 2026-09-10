class_name NegationImmunity
extends RefCounted

## "…cannot be negated", and "…cannot be targeted or destroyed by your opponent's card
## effects", applied to a PLAYER for the rest of a turn.
## RULES_SPEC.md 19, CARD_RULINGS.md R14.
##
## The generic gate for the three lingering rules `Hidden Springs of the Far East` grants.
## It was written before that card existed and it names no card: every function takes a
## player id, and the card's own text is what decides which id goes in.
##
## ---------------------------------------------------------------------------
## Three protections, deliberately three
## ---------------------------------------------------------------------------
##
## They are separate because the official text separates them, they are gated at three
## different entry points, and each one is false in cases where the others are true.
## Collapsing any two into a general "this player is protected" flag would be wrong in
## every case the third covers.
##
##  1. **SUMMON negation** — 「自分のモンスターの召喚・特殊召喚は無効化されない。」
##     A Normal or Special Summon by the protected player cannot be negated.
##
##     **A FLIP SUMMON IS NOT COVERED.** The Japanese names 「召喚・特殊召喚」 and the English
##     "The Normal and Special Summons"; neither mentions 「反転召喚」, which the OCG treats
##     as its own Summon route and which this engine also keeps separate. This is an
##     inference from omission rather than a statement — the card has **no Q&A entries at
##     all** — so it is recorded at MEDIUM confidence in R14 and asserted in both
##     directions, giving a later correction exactly one place to land.
##
##  2. **ACTIVATION negation, but only for an activation that INCLUDES a Special Summon** —
##     「モンスターを特殊召喚する効果を含む、モンスターの効果・魔法・罠カードを自分が発動した場合、
##     その発動は無効化されない。」 Two narrowings that must both be kept:
##
##       * only **activation** negation. Negating the EFFECT while the activation stands is
##         a different operation (master prompt 18, and `ChainManager` keeps them apart),
##         and it is **not** blocked;
##       * only an activation whose effect **includes** a Special Summon. Whether it does
##         is `EffectDef.includes_special_summon`, a declared property of the printed text,
##         not something inferred from a `resolve` callable at run time.
##
##  3. **SET Spell/Trap protection** — 「自分フィールドにセットされた魔法・罠カードは相手の効果の
##     対象にならず、相手の効果では破壊されない。」 Three narrowings:
##
##       * **SET** cards only. A face-up Continuous, Field or Equip card is not protected —
##         including the `Hidden Springs of the Far East` that granted this;
##       * **Spell/Trap** cards only. Monsters are not protected by this clause at all;
##       * only against the **OPPONENT's** effects. The protected player's own effects
##         reach their own Set cards normally, and so do **battle** and **rules**
##         destruction, neither of which is a card effect.
##
## ---------------------------------------------------------------------------
## Why the state lives on PlayerState and is turn-scoped
## ---------------------------------------------------------------------------
##
## The official duration is 「このターン中」 — the rest of the turn in which the effect
## resolved — and it attaches to a PLAYER, not to a card. `Hidden Springs of the Far East`
## stays on the field afterwards and its protections must not follow it: a second turn
## needs a second activation.
##
## So these are plain per-player restriction keys, cleared by `TurnFlow`'s end-of-turn
## cleanup, exactly like `skip_battle_phase_this_turn`. They are deliberately **not**
## `ContinuousEffects` restriction flags: those are wiped and rebuilt from the board on
## every recompute, which would make the protection blink out and back depending on what
## else happened to be face-up, and would tie it to the card rather than to the turn.
##
## The keys are NOT namespaced with `ContinuousEffects.PLAYER_KEY_PREFIX`, and that is
## load-bearing — a continuous recompute must not wipe them.

## "Your Normal and Special Summons cannot be negated" — this turn.
const KEY_SUMMONS := "summons_cannot_be_negated_this_turn"
## "An activation of yours that includes a Special Summon cannot be negated" — this turn.
const KEY_SPECIAL_SUMMON_ACTIVATIONS := \
	"special_summoning_activations_cannot_be_negated_this_turn"
## "Your SET Spell/Traps cannot be targeted or destroyed by your opponent" — this turn.
const KEY_SET_SPELL_TRAPS := "set_spell_traps_protected_from_opponent_this_turn"

const ALL_KEYS := [KEY_SUMMONS, KEY_SPECIAL_SUMMON_ACTIVATIONS, KEY_SET_SPELL_TRAPS]

## The Summon routes protection 1 covers. A FLIP Summon is deliberately absent — see the
## note above, and R14's "What R14 leaves OPEN".
const PROTECTED_SUMMON_KINDS := [
	Enums.SummonKind.NORMAL,
	Enums.SummonKind.TRIBUTE,
	Enums.SummonKind.SPECIAL,
]


# ---------------------------------------------------------------------------
# Granting
# ---------------------------------------------------------------------------

## Grant all three protections to `pid` for the rest of this turn.
##
## One function rather than three, because the official supplement says the LP gain and all
## three ● effects 「同時に行われます」 — they are applied simultaneously, in one resolution,
## and there is no state in which a card has granted some of them but not others. A future
## card that grants only one would call the individual setters instead.
static func grant_all(state: GameState, pid: int) -> void:
	for key in ALL_KEYS:
		state.player(pid).set_restriction(key, true)


static func grant(state: GameState, pid: int, key: String) -> void:
	state.player(pid).set_restriction(key, true)


## Cleared by `TurnFlow._end_of_turn_cleanup()`. 「このターン中」 and no longer.
static func clear_all(state: GameState) -> void:
	for p in state.players:
		for key in ALL_KEYS:
			p.clear_restriction(key)


static func has(state: GameState, pid: int, key: String) -> bool:
	if pid < 0 or pid >= state.players.size():
		return false
	return bool(state.player(pid).get_restriction(key, false))


# ---------------------------------------------------------------------------
# The three queries, one per gated call site
# ---------------------------------------------------------------------------

## Protection 1. Is a pending Summon of `kind` by `pid` protected from negation?
##
## Gated in `DuelEngine.negate_pending_summon()`, which is the single entry point every
## Summon negation in the library goes through.
static func summon_negation_blocked(state: GameState, pid: int,
		kind: Enums.SummonKind) -> bool:
	if not has(state, pid, KEY_SUMMONS):
		return false
	return PROTECTED_SUMMON_KINDS.has(kind)


## Protection 2. Is negation of `link`'s ACTIVATION blocked?
##
## Gated in `ChainManager.negate_activation()` and nowhere else — `negate_effect()` is a
## different operation and is deliberately left reachable.
static func activation_negation_blocked(state: GameState, link: ChainLink) -> bool:
	if link == null or link.effect == null:
		return false
	if not has(state, link.controller_id, KEY_SPECIAL_SUMMON_ACTIVATIONS):
		return false
	# Read the effect the card ACTIVATED, not what it may now resolve: the protection is
	# about the activation, and batch 18 unit A made those two things able to differ.
	return link.effect.includes_special_summon


## Protection 3, targeting half. May an effect controlled by `by_player` target `card`?
##
## Gated in `ActivationRules.legal_targets()`, beside the separate and unrelated
## `CardInstance.cannot_be_targeted()` flag — that one is a property of a MONSTER granted by
## another card, this one is a property of a PLAYER'S SET Spell/Traps. They must not be
## merged: this one is relative to who is doing the targeting, and that one is not.
static func targeting_blocked(state: GameState, card: CardInstance,
		by_player: int) -> bool:
	if not _is_protected_set_spell_trap(state, card):
		return false
	# "their OPPONENT cannot target" — the protected player's own effects are unaffected.
	return by_player != card.controller_id


## Protection 3, destruction half. May an effect sourced at `source_id` destroy `card`?
##
## Gated in `GameState.destroy()`, and only for `DESTROYED_BY_EFFECT`: battle destruction
## and rules destruction are not card effects and are never blocked. A `source_id` of -1 is
## the game rules and is never blocked.
static func destruction_blocked(state: GameState, card: CardInstance,
		source_id: int) -> bool:
	if not _is_protected_set_spell_trap(state, card):
		return false
	if source_id < 0:
		return false
	var source = state.instance(source_id)
	if source == null:
		return false
	return source.controller_id != card.controller_id


static func _is_protected_set_spell_trap(state: GameState, card: CardInstance) -> bool:
	if card == null or card.definition == null:
		return false
	# "SET Spell/Traps": a Spell or Trap card, on the field, face-DOWN. A card that has
	# been activated is face-up and is not protected — including the card that granted this.
	if card.is_monster():
		return false
	if not card.is_on_field():
		return false
	if card.is_face_up():
		return false
	return has(state, card.controller_id, KEY_SET_SPELL_TRAPS)
