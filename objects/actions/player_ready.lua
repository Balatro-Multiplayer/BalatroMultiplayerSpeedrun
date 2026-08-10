MPAPI.ActionType({
	key = 'spdrn_player_ready',
	parameters = {
		{ key = 'ready', type = 'boolean', required = false },
	},
	on_receive = function(action_type, from_player_id, params)
		local lobby = MPAPI.get_current_lobby()

		-- Feeds MPAPI core's shared ready-status badge (every client, not just
		-- host) -- separate from SPDRN.set_player_ready's host-only tally below,
		-- which still gates START/auto-start on its own.
		if lobby then
			MPAPI.set_player_ready(lobby, from_player_id, params and params.ready)
		end

		-- Lobby-join race fix: a guest's initial ready (sent the instant its lobby is
		-- ready) can be published before the host has subscribed to the actions topic,
		-- so the host never sees it and the auto-start stalls. The host->guest direction
		-- is reliable, so when a guest hears any *peer's* ready it re-announces its own
		-- once -- by now both ends are subscribed, so the host receives the re-send.
		if lobby and not lobby.is_host and SPDRN.is_matchmaking()
			and from_player_id ~= lobby.player_id and not SPDRN._ready_resent then
			SPDRN._ready_resent = true
			SPDRN.signal_ready(true)
		end

		if not lobby or not lobby.is_host then
			return
		end
		-- The host tallies every client's ready state (its own arrives via the
		-- broadcast loopback). This gates START (private) and the matchmaking
		-- auto-start.
		SPDRN.set_player_ready(from_player_id, params and params.ready)
	end,
})
