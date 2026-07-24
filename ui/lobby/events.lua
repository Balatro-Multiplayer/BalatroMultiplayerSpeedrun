SPDRN.setup_lobby_events = function(lobby)
	local L = SPDRN.lobby
	L.ref = lobby
	L.ui_ref = MPAPI.create_lobby_ui(lobby)
	L.ready:reset()
	L.seed_votes:reset()
	L.local_ready = false
	L.start_broadcasted = false
	-- One-shot guard for the guest's ready re-announce (see player_ready action).
	SPDRN._ready_resent = false

	local function update_game_buttons()
		if L.buttons.start_game then
			L.buttons.start_game:update()
		end
		SPDRN.refresh_matchmaking_status()
	end

	lobby:on('player_joined', function(player_id)
		SPDRN.sendDebugMessage('Player joined: ' .. tostring(player_id))
		update_game_buttons()
		-- A late arrival may complete the ready set.
		SPDRN.maybe_autostart()
	end)

	lobby:on('player_left', function(player_id)
		SPDRN.sendDebugMessage('Player left: ' .. tostring(player_id))
		L.ready:remove(player_id)
		-- A full reset, not just this player's own vote: §16.5 resets everyone's
		-- vote whenever membership changes (an "unanimous" bar computed against
		-- the old roster would otherwise misfire once someone leaves).
		L.seed_votes:reset()
		update_game_buttons()
	end)

	lobby:on('player_reconnected', function(player_id)
		SPDRN.sendDebugMessage('Player reconnected: ' .. tostring(player_id))
		-- §16.5: votes reset on a reconnect too, same as a leave -- a stale
		-- unanimous vote from before the drop shouldn't fire again the instant
		-- the reconnecting player's own client re-syncs.
		L.seed_votes:reset()
	end)

	lobby:on('connected', function()
		update_game_buttons()
	end)

	-- Private lobbies build their control bar from lobby state at build time (deck label,
	-- host's START/OPTIONS vs guest's READY), so a deck or host change has to rebuild the
	-- view, not just patch the START button. Matchmaking lobbies have only a status line, so
	-- they keep the light path (and avoid player-card flicker).
	lobby:on('metadata_changed', function(metadata)
		if not SPDRN.is_matchmaking() then
			MPAPI.refresh_current_view()
		end
		update_game_buttons()
	end)

	lobby:on('host_changed', function()
		if not SPDRN.is_matchmaking() then
			MPAPI.refresh_current_view()
		end
		update_game_buttons()
	end)

	lobby:on('error', function(err)
		SPDRN.sendWarnMessage('Lobby error: ' .. tostring(err))
	end)

	lobby:on('disconnected', function()
		SPDRN.sendDebugMessage('Disconnected from lobby')
		L.ref = nil
		L.ui_ref = nil
		L.buttons_initialized = false
		L.ready:reset()
		L.seed_votes:reset()
		L.local_ready = false
		L.start_broadcasted = false
		SPDRN._lobby_kind = nil
		-- The match handle is independent of the lobby (lobby:leave() does not fire the
		-- handle's 'left'). Drop it here so a later solo run's win path can't report a result
		-- against the finished match.
		SPDRN._current_match_handle = nil
	end)
end
