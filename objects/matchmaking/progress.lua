-- §16.8: per-player progress tracking used to rank non-winning players by how
-- far they got instead of tying everyone for last place, plus the per-run
-- timing needed for §11.7's "fastest individual run time" secondary metric.
-- Tracks only the LOCAL player's own progress -- each client reports its own
-- numbers, nothing is inferred about anyone else's run (see result.lua for how
-- those self-reports get collected and turned into a ranking).

-- §16.10: a lightweight snapshot of the local player's final jokers + deck
-- back, captured once at finalize time alongside furthest ante/round -- shown
-- on the win/lose screen's jokers area for every player (ui/end_game_panel.lua),
-- not just the local one. Plain data (not card:save()/CardArea:save(), which
-- round-trip engine-internal state this display has no use for) so it rides
-- cheaply on the existing spdrn_player_result broadcast.
local function capture_local_jokers()
	local jokers = {}
	if G.jokers and G.jokers.cards then
		for _, card in ipairs(G.jokers.cards) do
			local center = card.config and card.config.center
			if center then
				jokers[#jokers + 1] = {
					key = center.key,
					edition = card.edition,
					eternal = card.ability and card.ability.eternal or false,
					perishable = card.ability and card.ability.perishable or false,
				}
			end
		end
	end
	return jokers
end

local function capture_local_deck_back()
	if G.GAME and G.GAME.viewed_back and G.GAME.viewed_back.key then
		return G.GAME.viewed_back.key
	end
	return SPDRN.resolve_back_key(SPDRN._run_deck)
end

-- §16.10/17: the local player's full final deck, encoded as one
-- semicolon-joined string of "suit-rank-enhancement-edition-seal" per card --
-- the same wire format PvP's card_to_string/load_nemesis_deck (lib/card_utils.lua,
-- networking/action_handlers.lua) uses, reused here so a player's final deck
-- can be rebuilt as real playing cards on the end-screen (ui/deck_view.lua)
-- instead of only ever showing a deck_back label. Rides along on the same
-- spdrn_player_result broadcast as jokers/deck_back.
local RANK_TO_STRING = { ['10'] = 'T', Jack = 'J', Queen = 'Q', King = 'K', Ace = 'A' }
local _reversed_centers = nil

local function true_key(tbl)
	if not tbl then
		return nil
	end
	for k, v in pairs(tbl) do
		if v == true then
			return k
		end
	end
	return nil
end

local function card_to_string(card)
	if not card or not card.base or not card.base.suit or not card.base.value then
		return nil
	end
	if not _reversed_centers then
		_reversed_centers = {}
		for k, v in pairs(G.P_CENTERS) do
			_reversed_centers[v] = k
		end
	end
	local suit = string.sub(card.base.suit, 1, 1)
	local rank = RANK_TO_STRING[card.base.value] or card.base.value
	local enhancement = (card.config and _reversed_centers[card.config.center]) or 'none'
	local edition = true_key(card.edition) or 'none'
	local seal = card.seal or 'none'
	return suit .. '-' .. rank .. '-' .. enhancement .. '-' .. edition .. '-' .. seal
end

local function capture_local_deck()
	local cards = {}
	if G.playing_cards then
		for _, card in ipairs(G.playing_cards) do
			local s = card_to_string(card)
			if s then
				cards[#cards + 1] = s
			end
		end
	end
	return table.concat(cards, ';')
end

-- Called once per match (SPDRN.begin_run), before the first run starts.
function SPDRN.reset_match_progress()
	SPDRN._progress = {
		furthest_ante = 1,
		furthest_round = 0,
		arrived_at = 0,
		best_run_time_ms = nil,
		jokers = {},
		deck_back = nil,
		deck = nil,
		finalized = false,
		-- §end-screen stats: match-wide, cumulative across every run in the
		-- match -- deliberately NOT reset in reset_current_run_timer, only
		-- here, so a run restart never loses them.
		match_completion_ms = nil,
		times_skipped = 0,
		best_hand_amt = nil,
	}
	-- Cleared (not just left stale) so run_start.lua's _check_pending_run_transition
	-- can tell "the very first run of this match, nothing to fold in yet" (nil)
	-- apart from "a later transition, fold in the run that just ended" -- without
	-- this, a leftover value from a PREVIOUS match could make the first run
	-- wrongly capture stale G.GAME.round_scores as this match's best hand.
	SPDRN._current_run_started_at = nil
	SPDRN._collected_results = {}
	SPDRN._current_winner_id = nil
	-- §16.7: whether THIS client has already finalized/broadcast its own result --
	-- tracked separately from _current_winner_id because a duration-cap cutoff
	-- calls report_match_result(nil) (no single winner), and player_result.lua's
	-- retry-on-receipt needs a signal that survives a nil winner id.
	SPDRN._match_result_pending = false
	SPDRN._match_timeout_fired = false
	-- §16.11: per-player live location tracking (Enemy Location Indicator),
	-- keyed by sender id -- see objects/matchmaking/location.lua.
	SPDRN._locations = {}
	SPDRN._last_broadcast_location = nil
end

-- Called at the start of every individual run, first and subsequent, within a
-- multi-run match (SPDRN._check_pending_run_transition covers both cases).
function SPDRN.reset_current_run_timer()
	SPDRN._current_run_started_at = love.timer.getTime()
end

-- Called once a single run completes (reaches the win ante) within the match --
-- multi-run formats call this once per run, not just at the last one, so the
-- reported metric is the fastest INDIVIDUAL run, not the whole match's elapsed
-- time (see design doc §11.7/§16.8).
function SPDRN.record_run_completed()
	local p = SPDRN._progress
	if not p or p.finalized then
		return
	end
	local started_at = SPDRN._current_run_started_at or love.timer.getTime()
	local run_time_ms = (love.timer.getTime() - started_at) * 1000
	if not p.best_run_time_ms or run_time_ms < p.best_run_time_ms then
		p.best_run_time_ms = run_time_ms
	end
	-- Closes out this individual run's RLOG block (see objects/replay_log/record.lua's
	-- begin_run wiring) -- a no-op if RLOG isn't active for this run (end_run itself
	-- guards on RLOG._run_active), so this is safe to call unconditionally.
	MPAPI.replay.end_run({ result = 'run_complete' })
end

-- §end-screen stats: called once, the moment this client's own match
-- involvement ends (it won, or it personally forfeited): increments the
-- match-wide "times skipped" counter, called from a G.FUNCS.skip_blind hook
-- (objects/matchmaking/skip_tracking.lua) rather than from anywhere in this
-- file, since skipping is a base-game button press, not a gamemode event.
function SPDRN.record_skip()
	local p = SPDRN._progress
	if not p or p.finalized then
		return
	end
	p.times_skipped = (p.times_skipped or 0) + 1
end

-- §end-screen stats: folds the CURRENTLY LIVE run's best hand (if any) into
-- the match-wide running max, without touching G.GAME. Called from two spots
-- since a run's round_scores are about to be wiped by the next start_run:
-- finalize_match_progress (the run that ends the match) and
-- ui/lobby/run_start.lua's _check_pending_run_transition (every other
-- transition -- restart, seed change, multi-run progression), right before
-- it kicks off the next run.
function SPDRN.capture_best_hand_for_running_run()
	local p = SPDRN._progress
	if not p or p.finalized then
		return
	end
	local amt = G.GAME and G.GAME.round_scores and G.GAME.round_scores.hand and G.GAME.round_scores.hand.amt
	if amt and (not p.best_hand_amt or amt > p.best_hand_amt) then
		p.best_hand_amt = amt
	end
end

-- Called once, the moment this client's own match involvement ends (it won, or
-- it personally forfeited): snapshots the furthest ante/round actually reached
-- and how long into the run that happened, then freezes the result so nothing
-- afterward (e.g. a lingering tick during teardown) can change what gets
-- reported.
function SPDRN.finalize_match_progress()
	if not SPDRN._progress then
		SPDRN.reset_match_progress()
	end
	local p = SPDRN._progress
	if not p.finalized and G.GAME then
		local ante = (G.GAME.round_resets and G.GAME.round_resets.ante) or p.furthest_ante
		local round = G.GAME.round or 0
		if ante and ante > p.furthest_ante then
			p.furthest_ante = ante
			p.furthest_round = round
			p.arrived_at = love.timer.getTime() - (SPDRN._run_started_at or love.timer.getTime())
		elseif ante == p.furthest_ante and round > p.furthest_round then
			p.furthest_round = round
		end
		p.jokers = capture_local_jokers()
		p.deck_back = capture_local_deck_back()
		p.deck = capture_local_deck()
		SPDRN.capture_best_hand_for_running_run()
		p.match_completion_ms = (love.timer.getTime() - (SPDRN._run_started_at or love.timer.getTime())) * 1000
	end
	p.finalized = true
	return p
end
