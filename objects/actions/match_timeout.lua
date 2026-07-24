-- §16.7: broadcast once the host's local clock detects the match has hit its
-- format's duration cap (see objects/matchmaking/duration.lua). Every client,
-- host included via the loopback, shows the neutral time's-up screen and
-- reports its own progress -- same as a natural finish (player_won.lua),
-- except there is no single declared winner: report_match_result(nil) still
-- resolves a full ranking via furthest ante/round/arrival time alone (see
-- objects/matchmaking/result.lua's build_placements).
MPAPI.ActionType({
	key = 'spdrn_match_timeout',
	on_receive = function(action_type, from_player_id, params)
		local lobby = MPAPI.get_current_lobby()
		if not lobby then
			return
		end

		G.E_MANAGER:add_event(Event({
			func = function()
				if G.STAGE == G.STAGES.RUN then
					SPDRN.show_timeout_screen()
				end
				return true
			end,
		}))

		SPDRN.report_match_result(nil)
	end,
})
