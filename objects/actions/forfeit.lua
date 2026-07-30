MPAPI.ActionType({
	key = 'spdrn_forfeit',
	on_receive = function(action_type, from_player_id, params)
		local lobby = MPAPI.get_current_lobby()
		if not lobby then
			return
		end

		if from_player_id == lobby.player_id then
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
