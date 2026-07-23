-- The defined winning code path: a gamemode's calculate/on_player_forfeit just
-- returns { winner = player_id } and never touches this ActionType directly.
MPAPI.on_winner_declared(function(winner_id)
	local lobby = MPAPI.get_current_lobby()
	if lobby then
		lobby:action(MPAPI.ActionTypes['spdrn_player_won']):broadcast({ player_id = winner_id })
	end
end)

MPAPI.ActionType({
	key = 'spdrn_player_won',
	on_receive = function(action_type, from_player_id, params)
		local lobby = MPAPI.get_current_lobby()
		if not lobby then
			return
		end
		local winner_id = params and params.player_id
		if not winner_id then
			return
		end

		local won = (winner_id == lobby.player_id)

		G.E_MANAGER:add_event(Event({
			func = function()
				if G.STAGE == G.STAGES.RUN then
					if won then
						SPDRN.show_win_screen()
					else
						SPDRN.show_lose_screen()
					end
				end
				return true
			end,
		}))

		-- §11.6/§16.8: every player reports its own result now, not just the
		-- host -- see result.lua's report_match_result.
		SPDRN.report_match_result(winner_id)
	end,
})
