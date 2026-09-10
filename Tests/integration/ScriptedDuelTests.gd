class_name ScriptedDuelTests
extends RefCounted

## Scripted FULL duels between the two real 40-card decks. The post-card phase, unit 2.
##
## "Scripted" means deterministic: each duel is fixed by (seed, first player, two policy
## styles), plays itself through the public API with `DuelDriver`, and must reproduce itself
## exactly from its own replay payload. No duel here arranges a board.
##
## Several representative duels rather than one artificial mega-duel. Each asserts on its
## own: it ENDS by a real win condition inside its turn cap; nothing errored; the engine never
## refused an action it had offered; every per-step invariant held; nothing hidden leaked;
## and its replay reproduced it event for event. What the battery as a whole covered is
## asserted separately, from the event logs — a coverage claim is never taken on trust.

const DUELS := [
	{"label": "beatdown mirror", "seed": 1001, "first": 0,
		"styles": [DuelDriver.STYLE_BEATDOWN, DuelDriver.STYLE_BEATDOWN]},
	{"label": "control vs beatdown", "seed": 2002, "first": 1,
		"styles": [DuelDriver.STYLE_CONTROL, DuelDriver.STYLE_BEATDOWN]},
	{"label": "beatdown vs control", "seed": 3003, "first": 0,
		"styles": [DuelDriver.STYLE_BEATDOWN, DuelDriver.STYLE_CONTROL]},
	{"label": "control mirror", "seed": 4004, "first": 1,
		"styles": [DuelDriver.STYLE_CONTROL, DuelDriver.STYLE_CONTROL]},
	{"label": "passive deck-out", "seed": 5005, "first": 0,
		"styles": [DuelDriver.STYLE_PASSIVE, DuelDriver.STYLE_PASSIVE],
		"expect_reason": Enums.EndReason.DECK_OUT},
	{"label": "surrender", "seed": 6006, "first": 1,
		"styles": [DuelDriver.STYLE_BEATDOWN, DuelDriver.STYLE_BEATDOWN],
		"surrender_on_turn": 4, "expect_reason": Enums.EndReason.SURRENDER},
]


static func run() -> TestCase:
	var t := TestCase.new("ScriptedDuelTests")
	_test_the_harness_detectors_fire(t)
	_test_deck_initialisation(t)
	var drivers: Array = []
	for cfg in DUELS:
		drivers.append(_test_one_duel(t, cfg))
	_test_battery_coverage(t, drivers)
	_test_same_inputs_play_the_same_duel(t)
	_test_a_different_seed_plays_a_different_duel(t)
	return t


static func play(cfg: Dictionary) -> DuelDriver:
	var drv := DuelDriver.new()
	drv.seed_value = int(cfg["seed"])
	drv.first_player = int(cfg["first"])
	drv.styles = (cfg["styles"] as Array).duplicate()
	drv.surrender_on_turn = int(cfg.get("surrender_on_turn", -1))
	drv.max_turns = int(cfg.get("max_turns", 120))
	drv.play()
	return drv


## The expected pre-shuffle Deck list of a real deck, expanded from its JSON.
static func _expected_list(index: int) -> Array:
	var out: Array = []
	for def in TestFixtures.real_deck(index)["cards"]:
		out.append((def as CardDef).name)
	return out


# ---------------------------------------------------------------------------
# Tests
# ---------------------------------------------------------------------------

## A clean duel proves nothing about a detector that can never fire. Each detector the duels
## rely on is fed ONE synthetic fault it must flag, and one legal lookalike it must not — so
## deleting or weakening a detector fails here even while every real duel stays clean.
static func _test_the_harness_detectors_fire(t: TestCase) -> void:
	t.start("the harness's own detectors fire on the faults they claim to catch, and stay "
		+ "quiet on the legal lookalike of each")
	var drv := DuelDriver.new()
	drv.seed_value = 7101
	drv.setup()
	var engine := drv.engine
	var s := engine.state
	drv._scan_new_events()

	# 1. Once per turn, per card instance and per STAY on the field (RULES_SPEC.md 11).
	var def := TestFixtures.monster("Opt Probe", 4, 1000, 1000)
	TestFixtures.with_effect(def, EffectDef.new("opt_probe", "Test: once per turn.").opt_instance())
	var card := TestFixtures.give_monster_on_field(engine, 0, def)
	var act := {"card_id": card.id, "effect_id": "opt_probe", "controller": 0}
	s.emit(GameEvent.Kind.EFFECT_ACTIVATED, act.duplicate())
	drv._scan_new_events()
	t.eq(drv.opt_violations.size(), 0, "lookalike: one use is not flagged")
	s.emit(GameEvent.Kind.EFFECT_ACTIVATED, act.duplicate())
	drv._scan_new_events()
	t.eq(drv.opt_violations.size(), 1, "fault: a second use in the same stay IS flagged")
	s.move_card(card, Enums.Zone.HAND, Enums.MoveReason.RETURNED_TO_HAND)
	s.move_card(card, Enums.Zone.MONSTER_ZONE, Enums.MoveReason.RULE,
		{"position": Enums.Position.FACE_UP_ATTACK})
	s.emit(GameEvent.Kind.EFFECT_ACTIVATED, act.duplicate())
	drv._scan_new_events()
	t.eq(drv.opt_violations.size(), 1,
		"lookalike: a use after it left the field and came back — a new card — is not")

	# 2. A move event naming a card to a player who could see it at neither end.
	var secret := TestFixtures.give_to_hand(engine, 1,
		TestFixtures.monster("Leak Probe", 4, 1000, 1000))
	s.move_card(secret, Enums.Zone.MONSTER_ZONE, Enums.MoveReason.SET,
		{"position": Enums.Position.FACE_DOWN_DEFENSE})
	drv._scan_new_events()
	t.eq(drv.log_leaks, [], "lookalike: the engine's own Set move is private, and not flagged")
	s.emit(GameEvent.Kind.CARD_MOVED, {"card_id": secret.id, "card_name": "Leak Probe",
		"from_zone": Enums.Zone.HAND, "to_zone": Enums.Zone.MONSTER_ZONE, "from_player": 1,
		"to_player": 1, "reason": Enums.MoveReason.SET, "source_id": -1})
	drv._scan_new_events()
	t.eq(drv.log_leaks.size(), 1, "fault: the same move made PUBLIC is flagged")

	# 3. LP that the LP_CHANGED events do not account for.
	var before := drv.invariant_failures.size()
	drv._check_all()
	t.eq(drv.invariant_failures.size(), before, "lookalike: a consistent board is not flagged")
	s.emit(GameEvent.Kind.LP_CHANGED, {"player": 0, "delta": -100, "life_points": 1234,
		"reason": "", "source_id": -1})
	drv._scan_new_events()
	t.is_true(drv.invariant_failures.size() > before,
		"fault: an LP_CHANGED whose total does not add up is flagged")

	# 4. A card in two zones at once.
	before = drv.invariant_failures.size()
	var dup: CardInstance = s.player(0).hand[0]
	s.player(0).graveyard.append(dup)
	drv._check_conservation()
	s.player(0).graveyard.erase(dup)
	t.is_true(drv.invariant_failures.size() > before, "fault: a card in two zones is flagged")
	before = drv.invariant_failures.size()
	drv._check_conservation()
	t.eq(drv.invariant_failures.size(), before, "lookalike: once repaired, it is not")


static func _test_deck_initialisation(t: TestCase) -> void:
	t.start("both REAL 40-card decks instantiate: 80 slots, 77 unique cards, 5-card "
		+ "opening hands, no Draw-Phase draw for the first player on turn 1")
	var drv := DuelDriver.new()
	drv.seed_value = 7007
	drv.first_player = 0
	t.is_true(drv.setup(), "both decks load with no errors: %s" % str(drv.deck_errors))
	var s := drv.engine.state
	t.eq(drv.deck_names, ["Blue-Eyes Dragon Guard", "Fairy-Tail Tribute Guard"],
		"the two decks are the two physical decks")
	t.eq(s.all_instances().size(), 80, "all 80 physical deck slots are instantiated")
	var names := {}
	var missing_impl: Array = []
	for c in s.all_instances():
		var card: CardInstance = c
		names[card.card_name()] = true
		if card.definition == null or (card.definition.effects.is_empty() \
				and not card.definition.is_vanilla()):
			missing_impl.append(card.card_name())
	t.eq(names.size(), 77, "the 80 slots are the 77 unique cards of the V1 pool")
	t.eq(missing_impl, [], "every slot has an implementation (effects, or a vanilla body)")
	for pid in [0, 1]:
		var p := s.player(pid)
		t.eq(p.hand.size(), 5, "player %d opened with 5 cards [S1 p.33]" % pid)
		t.eq(p.deck.size(), 35, "and 35 left in the Deck")
		var owned := 0
		for c in s.all_instances():
			if (c as CardInstance).owner_id == pid:
				owned += 1
		t.eq(owned, 40, "player %d owns exactly 40 cards" % pid)
		t.eq(drv.engine.log.deck_lists[pid], _expected_list(pid),
			"player %d's pre-shuffle Deck list in the replay payload is the JSON deck" % pid)
	# The opening hands are drawn before turn 1 exists (turn 0), so they are told apart from
	# a Draw Phase draw by the TURN, not by the phase field.
	var opening := 0
	var turn1_draws := 0
	for ev in s.events:
		if ev.kind != GameEvent.Kind.CARD_DRAWN:
			continue
		if ev.turn == 0:
			opening += 1
		elif ev.turn == 1:
			turn1_draws += 1
	t.eq(opening, 10, "the two opening hands were 10 draws before turn 1 began")
	t.eq(turn1_draws, 0, "the first player drew nothing in their first Draw Phase [S1 p.33]")
	t.eq(s.turn_number, 1, "the duel is on turn 1")
	t.eq(s.turn_player_id, 0, "with the chosen first player")


static func _test_one_duel(t: TestCase, cfg: Dictionary) -> DuelDriver:
	var label: String = cfg["label"]
	t.start("scripted duel '%s' (seed %d): the two real decks, from the opening shuffle to a "
		% [label, int(cfg["seed"])] + "legitimate game over")
	var drv := play(cfg)
	var engine := drv.engine
	var s := engine.state

	t.eq(drv.outcome, "ended", "'%s' ENDED — %s" % [label, drv.summary()])
	t.is_true(s.is_duel_over(), "the engine agrees the duel is over")
	t.eq(TestFixtures.count_events(engine, GameEvent.Kind.DUEL_ENDED), 1,
		"exactly one DUEL_ENDED")
	t.is_true(s.turn_number <= drv.max_turns, "inside the %d-turn cap" % drv.max_turns)
	_assert_legitimate_end(t, drv, cfg)

	t.eq(drv.errors, [], "'%s': no push_error and no SCRIPT ERROR anywhere in the duel" % label)
	t.eq(drv.rejected, [], "the engine never refused an action it had itself offered")
	t.eq(drv.invariant_failures, [],
		"every card in exactly one zone, the one it believes it is in; LP moved only by LP_CHANGED")
	t.eq(drv.hidden_failures, [], "neither player's view ever identified a hidden card")
	t.eq(drv.log_leaks, [],
		"no event either player may read named a card hidden from them at both ends of its move")
	t.eq(drv.opt_violations, [], "no once-per-turn allowance was exceeded")
	t.eq(drv.suppressed, 0, "and no failure message was suppressed")
	for c in drv.controllers:
		t.eq((c as ScriptedController).errors, [],
			"player %d answered every prompt validly" % (c as ScriptedController).player_id)

	t.is_true(drv.steps > 10, "non-vacuity: %d actions were really played" % drv.steps)
	t.is_true(drv.hidden_checks > 0,
		"non-vacuity: %d hidden-card view entries were inspected" % drv.hidden_checks)
	t.is_true(drv.move_checks > 0,
		"non-vacuity: %d move events were checked for privacy" % drv.move_checks)
	_assert_every_turn_drew(t, engine)

	var payload := engine.log.to_replay()
	var r := DuelDriver.replay(payload)
	var replayed: DuelEngine = r["engine"]
	t.eq(r["errors"], [], "the payload answered every question the replayed duel asked")
	t.eq(int(r["applied"]), (payload["actions"] as Array).size(),
		"every recorded action was accepted again by a fresh engine")
	var a := DuelDriver.event_lines(engine)
	var b := DuelDriver.event_lines(replayed)
	var diff := DuelDriver.first_difference(a, b)
	t.eq(diff, -1, "replaying the payload reproduces all %d events exactly%s" % [a.size(),
		"" if diff == -1 else " — first difference at %d: %s vs %s" % [diff,
		a[diff] if diff < a.size() else "<end>", b[diff] if diff < b.size() else "<end>"]])
	t.eq(DuelDriver.final_board(replayed), DuelDriver.final_board(engine),
		"and the same final board, LP, result and turn")
	return drv


static func _assert_legitimate_end(t: TestCase, drv: DuelDriver, cfg: Dictionary) -> void:
	var s := drv.engine.state
	if cfg.has("expect_reason"):
		t.eq(s.end_reason, cfg["expect_reason"], "it ended the way this duel was built to: %s"
			% Enums.EndReason.keys()[int(cfg["expect_reason"])])
	var loser := 0 if s.result == Enums.DuelResult.PLAYER_1_WINS else 1
	match s.end_reason:
		Enums.EndReason.LP_ZERO:
			t.is_true(s.player(loser).life_points <= 0,
				"LP_ZERO: the loser's LP really reached 0 (%d)" % s.player(loser).life_points)
			t.is_true(s.player(1 - loser).life_points > 0, "and the winner's did not")
			t.is_true(int(drv.event_counts.get("LP_CHANGED", 0)) > 0,
				"and LP was really changed by events")
		Enums.EndReason.DECK_OUT:
			t.eq(s.player(loser).deck.size(), 0, "DECK_OUT: the loser's Deck really is empty")
			t.eq(s.turn_player_id, loser, "and it ran out on the loser's own draw")
			t.eq(s.phase, Enums.Phase.DRAW, "in the Draw Phase [S1 p.35]")
		Enums.EndReason.SURRENDER:
			t.eq(int(drv.submitted.get("SURRENDER", 0)), 1, "SURRENDER: one was submitted")
			t.eq(loser, s.turn_player_id, "by the player who lost")
			t.eq(s.turn_number, int(cfg.get("surrender_on_turn", -1)), "on the scripted turn")
		Enums.EndReason.SIMULTANEOUS_LP_ZERO:
			t.eq(s.result, Enums.DuelResult.DRAW, "both reached 0: a draw")
		_:
			t.check(false, "an end reason this pool cannot produce: %s"
				% Enums.EndReason.keys()[s.end_reason])


## Every turn but the first player's first began with a Draw Phase draw by the turn player
## — unless that is exactly the draw that lost the duel.
static func _assert_every_turn_drew(t: TestCase, engine: DuelEngine) -> void:
	var s := engine.state
	var drew := {}
	var turn_player := {}
	for ev in s.events:
		if ev.kind == GameEvent.Kind.TURN_STARTED:
			turn_player[ev.turn] = int(ev.data.get("player", -1))
		elif ev.kind == GameEvent.Kind.CARD_DRAWN and ev.phase == Enums.Phase.DRAW \
				and int(ev.data.get("player", -1)) == int(turn_player.get(ev.turn, -2)):
			drew[ev.turn] = int(drew.get(ev.turn, 0)) + 1
	var missing: Array = []
	for turn in turn_player.keys():
		if int(turn) == 1:
			continue
		var ended_here := s.is_duel_over() and int(turn) == s.turn_number \
			and s.end_reason == Enums.EndReason.DECK_OUT
		if int(drew.get(turn, 0)) != 1 and not ended_here:
			missing.append(turn)
	t.eq(missing, [], "every turn after the first opened with exactly one Draw Phase draw "
		+ "(%d turns checked)" % (turn_player.size() - 1))


static func _test_battery_coverage(t: TestCase, drivers: Array) -> void:
	t.start("across the scripted duels every part of a full game really happened — each "
		+ "claim read from the event logs, never assumed")
	var ev := {}
	var sub := {}
	var mv := {}
	var reasons := {}
	var phases := {}
	var ends := {}
	var activated := {}
	var max_chain := 0
	var manual := 0
	var responses := 0
	var cross := 0
	var opt_reset := 0
	var tribute_summons := 0
	var monster_sets := 0
	var spell_trap_sets := 0
	for d in drivers:
		var drv: DuelDriver = d
		_sum(ev, drv.event_counts)
		_sum(sub, drv.submitted)
		_sum(mv, drv.moves)
		_sum(reasons, drv.move_reasons)
		_sum(phases, drv.phases_entered)
		_sum(activated, drv.activated_effects)
		max_chain = maxi(max_chain, drv.max_chain)
		manual += drv.manual_passes
		responses += drv.response_activations
		cross += drv.cross_responses
		ends[drv.engine.state.end_reason] = true
		for k in drv.opt_turns.keys():
			if (drv.opt_turns[k] as Dictionary).size() >= 2:
				opt_reset += 1
		for e in drv.engine.state.events:
			var ge: GameEvent = e
			if ge.kind == GameEvent.Kind.CARD_SET:
				if bool(ge.data.get("is_monster", false)):
					monster_sets += 1
				else:
					spell_trap_sets += 1
			elif ge.kind == GameEvent.Kind.NORMAL_SUMMON_SUCCEEDED:
				var c: CardInstance = drv.engine.state.instance(int(ge.data.get("card_id", -1)))
				if c != null and c.definition != null and c.definition.level >= 5:
					tribute_summons += 1

	for k in ["DUEL_STARTED", "TURN_STARTED", "CARD_DRAWN", "PHASE_CHANGED",
			"NORMAL_SUMMON_SUCCEEDED", "SPECIAL_SUMMON_SUCCEEDED", "CARD_TRIBUTED",
			"CARD_SET", "EFFECT_ACTIVATED", "CHAIN_LINK_ADDED", "CHAIN_LINK_RESOLVED",
			"ATTACK_DECLARED", "DAMAGE_SUBSTEP_CHANGED", "DAMAGE_CALCULATED",
			"BATTLE_DAMAGE_INFLICTED", "LP_CHANGED", "CARD_DESTROYED", "CARD_SENT_TO_GY",
			"CARD_ADDED_TO_HAND", "PLAYER_DEFEATED", "DUEL_ENDED"]:
		t.is_true(int(ev.get(k, 0)) > 0, "%s happened (%d)" % [k, int(ev.get(k, 0))])
	for p in [Enums.Phase.DRAW, Enums.Phase.STANDBY, Enums.Phase.MAIN_1, Enums.Phase.BATTLE,
			Enums.Phase.MAIN_2, Enums.Phase.END]:
		t.is_true(int(phases.get(p, 0)) > 0, "the %s was entered (%d)"
			% [Enums.phase_name(p), int(phases.get(p, 0))])
	for k in ["NORMAL_SUMMON", "TRIBUTE_SUMMON", "NORMAL_SET", "SET_SPELL_TRAP",
			"ACTIVATE_CARD", "ACTIVATE_EFFECT", "DECLARE_ATTACK", "ENTER_BATTLE_PHASE",
			"END_BATTLE_PHASE", "END_PHASE", "PASS", "SURRENDER"]:
		t.is_true(int(sub.get(k, 0)) > 0, "a %s was submitted and accepted (%d)"
			% [k, int(sub.get(k, 0))])
	t.is_true(tribute_summons > 0, "a Level 5+ monster was Tribute Summoned (%d)" % tribute_summons)
	t.is_true(monster_sets > 0, "a monster was Set (%d)" % monster_sets)
	t.is_true(spell_trap_sets > 0, "a Spell/Trap was Set (%d)" % spell_trap_sets)
	t.is_true(max_chain >= 2, "a Chain reached Chain Link %d" % max_chain)
	t.is_true(manual > 0, "a player was really offered a response window and declined it (%d)"
		% manual)
	# Chains of 2+ also arise from simultaneous triggers, so neither of the two above proves a
	# player ever ANSWERED the opponent — the mutation pass showed a policy that never responds
	# passing them both. These two do.
	t.is_true(responses > 0, "a card or effect was activated IN a response window (%d)" % responses)
	t.is_true(cross > 0, "a Chain Link was added by the player who did not start that Chain (%d)"
		% cross)
	var negations := int(ev.get("EFFECT_NEGATED", 0)) + int(ev.get("ACTIVATION_NEGATED", 0)) \
		+ int(ev.get("SUMMON_NEGATED", 0)) + int(ev.get("ATTACK_NEGATED", 0))
	t.is_true(negations > 0, "something was negated (%d: effect %d, activation %d, summon %d, "
		% [negations, int(ev.get("EFFECT_NEGATED", 0)), int(ev.get("ACTIVATION_NEGATED", 0)),
		int(ev.get("SUMMON_NEGATED", 0))] + "attack %d)" % int(ev.get("ATTACK_NEGATED", 0)))
	t.is_true(int(mv.get("DECK>HAND", 0)) > 0,
		"a card was added from the Deck to the hand by an effect (%d)" % int(mv.get("DECK>HAND", 0)))
	var from_gy := 0
	for k in mv.keys():
		if str(k).begins_with("GRAVEYARD>"):
			from_gy += int(mv[k])
	t.is_true(from_gy > 0, "a card left the Graveyard (%d)" % from_gy)
	t.is_true(int(reasons.get("HAND_SIZE_DISCARD", 0)) > 0,
		"the End Phase hand-size discard happened (%d)" % int(reasons.get("HAND_SIZE_DISCARD", 0)))
	t.is_true(opt_reset > 0, "a once-per-turn effect was used again on a later turn — the "
		+ "allowance reset (%d effects)" % opt_reset)
	for r in [Enums.EndReason.LP_ZERO, Enums.EndReason.DECK_OUT, Enums.EndReason.SURRENDER]:
		t.is_true(ends.has(r), "a duel ended by %s" % Enums.EndReason.keys()[r])
	var cards := {}
	for k in activated.keys():
		cards[str(k).split("::")[0]] = true
	t.is_true(cards.size() > 0, "%d distinct cards activated an effect across the battery"
		% cards.size())
	print("  [coverage] %d distinct cards activated: %s" % [cards.size(),
		", ".join(PackedStringArray(cards.keys()))])


static func _sum(into: Dictionary, from: Dictionary) -> void:
	for k in from.keys():
		into[k] = int(into.get(k, 0)) + int(from[k])


static func _test_same_inputs_play_the_same_duel(t: TestCase) -> void:
	t.start("the same seed, first player and styles play the same duel twice, event for event")
	var cfg: Dictionary = DUELS[1]
	var one := play(cfg)
	var two := play(cfg)
	var a := DuelDriver.event_lines(one.engine)
	var b := DuelDriver.event_lines(two.engine)
	t.eq(DuelDriver.first_difference(a, b), -1, "identical event streams (%d events)" % a.size())
	t.eq(DuelDriver.final_board(one.engine), DuelDriver.final_board(two.engine),
		"identical final boards")
	t.eq(one.engine.log.to_json(), two.engine.log.to_json(), "identical replay payloads")


static func _test_a_different_seed_plays_a_different_duel(t: TestCase) -> void:
	t.start("non-vacuity of determinism: a different seed plays a DIFFERENT duel")
	var cfg: Dictionary = (DUELS[0] as Dictionary).duplicate()
	var one := play(cfg)
	cfg["seed"] = int(cfg["seed"]) + 1
	var two := play(cfg)
	t.ne(DuelDriver.first_difference(DuelDriver.event_lines(one.engine),
		DuelDriver.event_lines(two.engine)), -1, "the event streams differ")
