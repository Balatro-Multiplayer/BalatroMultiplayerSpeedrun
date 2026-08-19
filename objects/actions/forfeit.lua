MPAPI.ActionType({
	key = 'spdrn_forfeit',
	on_receive = function(action_type, from_player_id, params)
		local lobby = MPAPI.get_current_lobby()
		if not lobby then
			return
		end

		if from_player_id == lobby.player_id then
			-- Closes this MATCH's RLOG block (end_run is now once-per-match, see
			-- ui/lobby/run_start.lua's begin_run) -- forfeiting is this client's
			-- own match-ending event, same as objects/matchmaking/result.lua's
			-- report_match_result. finalize_match_progress must run first: a
			-- non-terminal forfeit (>=3 players, someone else still playing)
			-- never reaches report_match_result at all (on_winner_declared only
			-- fires for the LAST survivor), so without this a forfeiting
			-- player's furthest ante/round/jokers/deck would never get
			-- snapshotted. Idempotent either way (finalize_match_progress no-ops
			-- once already finalized, end_run no-ops once already closed), so
			-- harmless if report_match_result already ran first for a terminal
			-- forfeit.
			SPDRN.finalize_match_progress()
			MPAPI.replay.end_run({ result = 'forfeit' })
			G.E_MANAGER:add_event(Event({
				func = function()
					if G.STAGE == G.STAGES.RUN then
						SPDRN.show_forfeit_screen()
					end
					return true
				end,
			}))
		end

		local instance = lobby:get_gamemode_instance()
		if instance and instance.on_player_forfeit then
			MPAPI._handle_gamemode_result(instance, instance:on_player_forfeit(from_player_id))
		end
	end,
})
