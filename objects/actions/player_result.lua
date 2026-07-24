-- §16.8/§11.6: every player broadcasts their own final progress once the match
-- ends for them (see objects/matchmaking/result.lua's report_match_result) --
-- collected locally by every client so any of them can compute and submit the
-- full ranked placements once everyone's result is in.
MPAPI.ActionType({
	key = 'spdrn_player_result',
	on_receive = function(action_type, from_player_id, params)
		if not params or not params.player_id then
			return
		end

		SPDRN._collected_results[params.player_id] = {
			furthest_ante = params.furthest_ante,
			furthest_round = params.furthest_round,
			arrived_at = params.arrived_at,
			best_run_time_ms = params.best_run_time_ms,
			jokers = params.jokers,
			deck_back = params.deck_back,
		}

		-- §16.10: the roster screen (if currently open) reacts live as each
		-- player's own result arrives, same idea as SPDRN.lobby.refresh_mm_status
		-- for the ban-pick draft view.
		if SPDRN.refresh_roster then
			SPDRN.refresh_roster()
		end

		-- §16.7: keyed on _match_result_pending (this client has itself already
		-- finalized/broadcast), not on _current_winner_id's truthiness -- a
		-- duration-cap cutoff finalizes with winner_id = nil, which must still
		-- retry as later players' results arrive.
		if SPDRN._match_result_pending then
			SPDRN._maybe_report_result(SPDRN._current_winner_id)
		end
	end,
})
