class_name EffectContext
extends RefCounted

## Everything an effect callable needs. Passed to condition / cost / target / resolve.
##
## Effects never reach for globals: all state access goes through this object, which
## keeps card behaviour testable in isolation and keeps the engine the single authority.

var state: GameState = null
## The DuelEngine driving this activation. Effects that must talk to the timing machine
## use it — e.g. `Champion's Vigilance` negating a Summon that has been declared but has
## not yet succeeded. Null in pure-legality checks.
var engine = null
## The ContinuousEffects system, attached while apply_continuous() runs. A continuous
## clause that restricts a PLAYER rather than a card goes through it
## (`ctx.continuous.restrict_player(...)`), because those restrictions are namespaced and
## rebuilt on every recompute and must never be written from anywhere else.
var continuous = null
var source: CardInstance = null
var effect: EffectDef = null
var controller_id: int = 0

## The chain link this activation created. Null while merely testing legality
## (condition / can_pay_cost are evaluated before a link exists).
var link: ChainLink = null

## The event that made a TRIGGER/FLIP/QUICK effect eligible, if any.
var trigger_event: GameEvent = null

## Interface used to ask a player something mid-resolution. Master prompt 42.
## A PlayerController, assigned by DuelEngine; null in pure-legality checks.
##
## This one is THIS EFFECT'S CONTROLLER, and it is the only player almost every effect ever
## has to ask. `deciders` below is what an effect uses when the card's own text puts a
## decision to somebody else.
var decider = null

## Every player's PlayerController, indexed by player id — the engine's own table, handed
## down wherever `decider` is assigned. CARD_RULINGS.md R11.
##
## Some cards put a decision to the player who does NOT control the resolving Chain Link:
## `Fairy Tail - Luna` says "your opponent CAN send 1 card ... to negate this effect", and
## the choice is made by that opponent, during this effect's resolution, out of their own
## private zones. `decider` cannot express that at all, and routing such a question to the
## controller would be wrong in three separate ways: the wrong person would answer, the
## answer would be recorded against the wrong player in the replay payload, and the
## controller would be shown the contents of the opponent's Deck.
##
## Deliberately the engine's controller TABLE rather than a second scalar: "ask the
## opponent" is only the first instance of "ask a named player", and a table answers both
## without a second mechanism. Nothing here decides WHO is asked — the card's text does,
## and it passes the id in.
var deciders: Array = []

## Targets chosen at activation, before the Chain Link exists. RULES_SPEC.md 10.
## Cost callables read this so a cost may depend on the chosen target.
var chosen_target_ids: Array = []

## Written by pay_cost() to record what the cost actually consumed. Copied onto the
## Chain Link, so an effect can reference what was paid when it later resolves.
var cost_payload: Dictionary = {}

## Caller-supplied query parameters. Used by rules-layer queries that ask a card a
## question outside of activation, e.g. SummonRules asking a potential Tribute
## "are you worth 2 Tributes for THIS summon?" via {"summoning_card": CardInstance}.
var params: Dictionary = {}


func _init(p_state: GameState = null, p_source: CardInstance = null,
		p_effect: EffectDef = null) -> void:
	state = p_state
	source = p_source
	effect = p_effect
	if p_source != null:
		controller_id = p_source.controller_id


func me() -> PlayerState:
	return state.player(controller_id)


func opponent() -> PlayerState:
	return state.opponent_of(controller_id)


func opponent_id() -> int:
	return state.opponent_id(controller_id)


func targets() -> Array:
	if link != null:
		return link.targets(state)
	var out := []
	for tid in chosen_target_ids:
		var c = state.instance(tid)
		if c != null:
			out.append(c)
	return out


## Ask this effect's controller a question mid-resolution. Master prompt 42.
## Returns null when no decider is attached (pure-legality evaluation).
func ask(request: DecisionRequest):
	return ask_player(controller_id, request)


## The PlayerController that answers for `pid`, or null when nobody can.
##
## A context built for a pure-legality check carries only `decider` and no table; that
## decider belongs to this effect's controller by construction, which is why the fallback
## is keyed on `controller_id` and on nothing else. Guessing for any other player would
## silently let one player answer for the other.
func decider_for(pid: int):
	if pid >= 0 and pid < deciders.size() and deciders[pid] != null:
		return deciders[pid]
	if pid == controller_id:
		return decider
	return null


## Ask a NAMED player a question mid-resolution. `ask()` is this with `controller_id`.
## CARD_RULINGS.md R11.
##
## The request already carries the player it is addressed to, so the two are checked
## against each other rather than one being trusted: a request built for the wrong player
## would be answered by the right controller and then recorded against the wrong one, and
## the replay would no longer describe the duel that happened.
##
## Returns null when no controller is attached for `pid` (a pure-legality evaluation), the
## same as `ask()` always has. A caller must treat null as "not asked", never as "declined
## on their behalf" — for an OPTIONAL step those two happen to coincide, and for anything
## else they must not.
func ask_player(pid: int, request: DecisionRequest):
	if request == null:
		return null
	if request.player_id != pid:
		# Master prompt 67: fail loudly rather than quietly asking the wrong person.
		push_error("EffectContext.ask_player: request addressed to p%d but asked of p%d"
			% [request.player_id, pid])
		return null
	var ctrl = decider_for(pid)
	if ctrl == null:
		return null
	var answer = ctrl.decide(request)
	# A mid-resolution choice is a duel INPUT, so the replay payload must carry it.
	# Master prompt 70. It is recorded for whichever player made it — `request` carries
	# that — so a decision the opponent made replays as the opponent's.
	if engine != null and engine.log != null:
		engine.log.record_decision(state, request, answer)
	return answer


func first_target():
	var t := targets()
	return t[0] if not t.is_empty() else null


## Convenience: is this effect's source still where it needs to be to resolve?
func source_still_valid(required_zone: Enums.Zone) -> bool:
	return source != null and source.zone == required_zone


func log_note(text: String) -> void:
	if link != null:
		link.resolution_note = text
