-- §16.11: receives another player's own location broadcast (see
-- objects/matchmaking/location.lua) and stores it keyed by the broadcasting
-- player's id -- never a single shared scalar (see that file's header comment
-- for why that distinction is exactly what PvP's own equivalent got wrong).
MPAPI.ActionType({
	key = 'spdrn_location',
	on_receive = function(action_type, from_player_id, params)
		if not params then
			return
		end
		SPDRN._locations[from_player_id] = { run = params.run, ante = params.ante, round = params.round }
	end,
})
