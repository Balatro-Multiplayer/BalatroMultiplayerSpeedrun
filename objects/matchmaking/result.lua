-- Collected per-player results for the current match, keyed by player id --
-- populated as each player's own client broadcasts its final progress (see
-- objects/actions/player_result.lua). Reset per match in reset_match_progress.
SPDRN._collected_results = SPDRN._collected_results or {}

-- §16.8: ranks the winner first, then every other player by furthest ante
-- (descending), then furthest round within that ante (descending), then by
-- arrival time at that ante (ascending -- got there sooner outranks got there
-- later). Returns nil until every player currently in the lobby has reported.
local function build_placements(winner_id)
	local lobby = MPAPI.get_current_lobby()
	if not lobby then
		return nil
	end

	local entries = {}
	for _, p in ipairs(lobby:get_players()) do
		local r = SPDRN._collected_results[p.id]
		if not r then
			return nil
		end
		entries[#entries + 1] = {
			playerId = p.id,
			is_winner = (p.id == winner_id),
			furthest_ante = r.furthest_ante or 1,
			furthest_round = r.furthest_round or 0,
			arrived_at = r.arrived_at or 0,
			best_run_time_ms = r.best_run_time_ms,
		}
	end

	table.sort(entries, function(a, b)
		if a.is_winner ~= b.is_winner then
			return a.is_winner
		end
		if a.furthest_ante ~= b.furthest_ante then
			return a.furthest_ante > b.furthest_ante
		end
		if a.furthest_round ~= b.furthest_round then
			return a.furthest_round > b.furthest_round
		end
		return a.arrived_at < b.arrived_at
	end)

	local placements = {}
	for i, e in ipairs(entries) do
		local entry = { playerId = e.playerId, place = i }
		-- §11.7: every player's own fastest individual run time rides along, not
		-- just the winner's -- the server only ever updates a player's own
		-- seasonBest from their own entry.
		if e.best_run_time_ms then
			entry.metric = e.best_run_time_ms
		end
		placements[#placements + 1] = entry
	end
	return placements
end

-- §11.6: any player may report a match result, not just the host -- tries once
-- per newly-collected result. The server's first-report-wins model makes it
-- safe for more than one client to independently succeed in calling this for
-- the same match: every client computes from the same converged
-- _collected_results, so their placements arrays agree rather than conflict.
function SPDRN._maybe_report_result(winner_id)
	local handle = SPDRN._current_match_handle
	if not handle or not handle.match_id then
		return
	end

	local placements = build_placements(winner_id)
	if not placements then
		return
	end

	handle:report_result(placements, function(err)
		if err then
			SPDRN.sendWarnMessage('report_result error: ' .. tostring(err))
		end
	end)
end

-- Called once, when this client's own match involvement ends (it won, or it
-- personally forfeited, per objects/actions/player_won.lua's receive handler):
-- finalizes and broadcasts its own progress, then checks whether every player
-- has now reported.
function SPDRN.report_match_result(winner_id)
	SPDRN._current_winner_id = winner_id
	SPDRN._match_result_pending = true

	local lobby = MPAPI.get_current_lobby()
	if not lobby then
		return
	end

	local progress = SPDRN.finalize_match_progress()
	-- §16.10: jokers/deck_back ride along for the end-of-run roster display only --
	-- build_placements (above) deliberately never reads them, so this stays a
	-- pure display concern with no effect on ranking/server reporting.
	SPDRN._collected_results[lobby.player_id] = {
		furthest_ante = progress.furthest_ante,
		furthest_round = progress.furthest_round,
		arrived_at = progress.arrived_at,
		best_run_time_ms = progress.best_run_time_ms,
		jokers = progress.jokers,
		deck_back = progress.deck_back,
	}
	lobby:action(MPAPI.ActionTypes['spdrn_player_result']):broadcast({
		player_id = lobby.player_id,
		furthest_ante = progress.furthest_ante,
		furthest_round = progress.furthest_round,
		arrived_at = progress.arrived_at,
		best_run_time_ms = progress.best_run_time_ms,
		jokers = progress.jokers,
		deck_back = progress.deck_back,
	})

	SPDRN._maybe_report_result(winner_id)
end
