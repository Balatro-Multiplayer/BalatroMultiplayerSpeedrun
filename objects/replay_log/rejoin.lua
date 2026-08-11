-- Rejoin (crash-relaunch resume): fast-forwards through the player's own
-- buffered RLOG events for the still-active run via the same bootstrap/
-- driver machinery "My Replays" uses (playback_launch.lua/
-- playback_handlers.lua), then hands off to live play by rejoining the real
-- lobby instead of ending in a "replay finished" toast. SPDRN is solo (no
-- opponent to catch up), so live hand-off is just MPAPI.join_lobby -- there
-- is no opponent-HUD projection state that needs a separate catch-up pass
-- here.
--
-- Takes `active` (MPAPI.replay.get_active_run's own response shape --
-- {runId, lobbyCode, modId, events}) rather than fetching by run_id itself:
-- an ACTIVE run has no DB-persisted matchRunLogs row yet (only written at
-- finalize), so MPAPI.replay.get(run_id) 403s "not a participant" for a
-- genuinely active run's own participant -- confirmed live. `events` is
-- already this player's own buffered stream (server-side getTail against
-- the live in-memory buffer), so no second fetch is needed at all.
function SPDRN._launch_rejoin(active)
	local conn = MPAPI.get_connection()
	local my_id = conn and conn.player_id

	local manifest = nil
	local timeline = {}
	for _, ev in ipairs(active.events or {}) do
		if ev.opcode == 'manifest' then manifest = ev.args end
		timeline[#timeline + 1] = { t = ev.t, player_id = my_id, opcode = ev.opcode, args = ev.args }
	end
	if not manifest then
		SPDRN.sendWarnMessage('[rejoin] no manifest event in active run ' .. tostring(active.runId))
		return
	end

	SPDRN._start_playback(manifest, function()
		local driver = MPAPI.playback.new_driver(timeline, {
			mod_id = 'spdrn',
			pov_player_id = my_id,
			on_complete = function()
				local lobby = MPAPI.join_lobby(SPDRN.id, active.lobbyCode)
				-- Opt out of on_lobby_connected's "match formed while practicing,
				-- exit the run" behavior (api/mod_registry/focus.lua) -- we're
				-- reconnecting to the SAME run we just fast-forwarded, not
				-- discovering a new one; must be set before the async connect
				-- callback fires. Confirmed live: without this, rejoin silently
				-- exited the just-restored run back to the main menu.
				if lobby then lobby._skip_run_exit_on_connect = true end
			end,
		})
		driver:finish()
		driver:play()
	end)
end

MPAPI.playback.register_rejoin(SPDRN.id, SPDRN._launch_rejoin)
