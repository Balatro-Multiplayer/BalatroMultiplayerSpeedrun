-- Join a matchmaking queue. kind is RANKED or CASUAL. The server treats any game_mode
-- without the ranked prefix as casual, so casual queues use the bare gamemode key.
function SPDRN._join_queue(kind, gamemode_key)
	SPDRN._lobby_kind = kind

	-- §16.2: casual scales via the gamemode's own .public field (2-16, already
	-- modeled correctly on every gamemode -- this just used to ignore it and
	-- always read .ranked instead, capping casual SPDRN at 2 players).
	local gm = MPAPI.GameModes[gamemode_key]
	local max_players_field = (kind == SPDRN.LobbyKind.RANKED) and 'ranked' or 'public'
	local mm_max = gm and gm.max_players and gm.max_players[max_players_field] or 2
	local game_mode = (kind == SPDRN.LobbyKind.RANKED) and (SPDRN.LobbyKind.RANKED_PREFIX .. gamemode_key) or gamemode_key

	SPDRN.sendDebugMessage('[mmdbg] _join_queue kind=' .. tostring(kind) .. ' gamemode_key=' .. tostring(gamemode_key) .. ' -> game_mode=' .. tostring(game_mode) .. ' mm_max=' .. tostring(mm_max))

	local handle = MPAPI.matchmaking.queue({
		mod_id = SPDRN.id,
		game_mode = game_mode,
		min_players = 2,
		max_players = mm_max,
		-- Without this, MPAPI.matchmaking.queue() has no way to know this is a
		-- ranked attempt (it can't infer that from game_mode's "ranked:" prefix
		-- alone - see that function's own doc comment), so its launcher-anti-cheat
		-- gate silently never ran for a real ranked queue attempt here. The
		-- server-side launcher-integrity gate is unaffected either way (it's
		-- independent, keyed off the game_mode prefix), but this client-side
		-- layer of defense-in-depth was a no-op for every ranked SPDRN queue.
		ranked = kind == SPDRN.LobbyKind.RANKED,
	})

	if not handle then
		SPDRN.sendWarnMessage('[mmdbg] Failed to create matchmaking handle')
		SPDRN._lobby_kind = nil
		return
	end

	SPDRN._current_match_handle = handle

	handle:on('error', function(err)
		SPDRN.sendWarnMessage('[mmdbg] Matchmaking error: ' .. tostring(err))
		SPDRN._current_match_handle = nil
		SPDRN._show_searching_state(false)
		SPDRN.update_main_menu_buttons()
	end)

	handle:on('queued', function(position)
		SPDRN.sendDebugMessage('[mmdbg] Queued at position: ' .. tostring(position))
		-- The elapsed "Queueing m:ss" display is driven centrally by the API now
		-- (api/matchmaking/queue_timer.lua), started on this same QUEUED event.
		SPDRN._show_searching_state(true)
	end)

	handle:on('match_found', function(data)
		SPDRN.sendDebugMessage('[mmdbg] Match found: ' .. tostring(data.matchId) .. ' lobbyCode=' .. tostring(data.lobbyCode) .. ' gameMode=' .. tostring(data.gameMode))
		SPDRN._show_searching_state(false)
	end)

	handle:on('lobby_ready', function(lobby)
		SPDRN.sendDebugMessage('[mmdbg] ' .. tostring(kind) .. ' lobby ready: ' .. tostring(lobby.code))
		SPDRN._lobby_kind = kind
		SPDRN.setup_lobby_events(lobby)
		if lobby.is_host then
			lobby:set_metadata({ gamemode = gamemode_key, ruleset = SPDRN.Ruleset.ORDER, kind = kind })
		end
		-- lobby_ready fires from inside the lobby's own 'connected' handler, so a 'connected'
		-- listener registered above would never fire. Signal ready now; the host auto-starts
		-- once every client has reported in. Re-announce a few times in case this first ready
		-- raced ahead of the peer's actions-topic subscription (else the host can stall).
		SPDRN.signal_ready(true)
		SPDRN.start_ready_resync()
	end)

	handle:on('match_resolved', function(ratings)
		SPDRN.sendDebugMessage('[mmdbg] Match resolved')
		SPDRN._current_match_handle = nil
	end)

	handle:on('left', function()
		SPDRN.sendDebugMessage('[mmdbg] handle left (queue dropped)')
		SPDRN._current_match_handle = nil
		SPDRN._lobby_kind = nil
		SPDRN._show_searching_state(false)
	end)
end

-- Back-compat alias (used by tests and older callers).
function SPDRN._join_ranked_queue(gamemode_key)
	return SPDRN._join_queue(SPDRN.LobbyKind.RANKED, gamemode_key)
end

function SPDRN._cancel_queue()
	local handle = SPDRN._current_match_handle
	if handle then
		handle:leave()
		SPDRN._current_match_handle = nil
	end
	SPDRN._lobby_kind = nil
	SPDRN._show_searching_state(false)
end

function SPDRN._is_in_ranked_match()
	return SPDRN._current_match_handle ~= nil and SPDRN._current_match_handle.match_id ~= nil
end
