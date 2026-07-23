-- §16.8: per-player progress tracking used to rank non-winning players by how
-- far they got instead of tying everyone for last place, plus the per-run
-- timing needed for §11.7's "fastest individual run time" secondary metric.
-- Tracks only the LOCAL player's own progress -- each client reports its own
-- numbers, nothing is inferred about anyone else's run (see result.lua for how
-- those self-reports get collected and turned into a ranking).

-- Called once per match (SPDRN.begin_run), before the first run starts.
function SPDRN.reset_match_progress()
	SPDRN._progress = {
		furthest_ante = 1,
		furthest_round = 0,
		arrived_at = 0,
		best_run_time_ms = nil,
		finalized = false,
	}
	SPDRN._collected_results = {}
	SPDRN._current_winner_id = nil
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
	end
	p.finalized = true
	return p
end
