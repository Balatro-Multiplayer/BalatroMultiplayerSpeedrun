-- Bootstraps a local, single-player run seeded to reproduce a previously
-- recorded RLOG run's exact seed/deck/stake/gamemode -- ported from
-- BalatroMultiplayerPvP's lib/playback_launch.lua. Reuses SPDRN's own
-- practice-mode bootstrap (SPDRN._start_practice, ui/main_menu/practice.lua)
-- almost verbatim: both are a local lobby (MPAPI.create_local_lobby, no
-- `.code`) that calls SPDRN.begin_run -- the same reason RLOG never
-- re-records during a playback session applies here unchanged (rlog_active(),
-- objects/replay_log/record.lua, gates on the current lobby having a code).
--
-- Known v1 gap: SPDRN.begin_run creates a FRESH gamemode instance
-- (_run_count = 0), so a multi-run format's (Stake Climb, White Stake Triple)
-- own per-run stake computed from _run_count reproduces correctly for a
-- match's FIRST run, but not exactly for a later run replayed on its own --
-- the instance would need its run-count fast-forwarded first. Gold Stake
-- Single/All Deck/Seed Scout/Challenge (single-run-focused formats) are
-- unaffected. Not solved this pass -- flagged, not silently wrong: a
-- mismatched stake would still play back the recorded actions, just at a
-- different (usually lower) stake than the original run.
function SPDRN._start_playback(manifest, on_ready)
	local current = MPAPI.get_current_lobby()
	if current and current.code then
		SPDRN.sendWarnMessage('_start_playback: refusing to start while connected to a real lobby (' .. tostring(current.code) .. ')')
		return
	end

	SPDRN._lobby_kind = SPDRN.LobbyKind.PRACTICE
	local lobby = MPAPI.create_local_lobby(SPDRN.id, { max_players = 1 })
	if not lobby then
		SPDRN._lobby_kind = nil
		return
	end
	lobby.suppress_lobby_view = true
	SPDRN.setup_lobby_events(lobby)

	lobby:on('connected', function()
		lobby:set_metadata({
			gamemode = manifest.gamemode,
			deck = manifest.deck,
			ruleset = SPDRN.Ruleset.ORDER,
			kind = SPDRN.LobbyKind.PRACTICE,
		})
		SPDRN.begin_run(manifest.gamemode, manifest.deck, manifest.seed)
	end)

	SPDRN._playback_wait_for(function()
		return G.STATE == G.STATES.BLIND_SELECT
	end, on_ready)
end

-- Minimal, self-contained one-shot condition poll -- same shape as PvP's own
-- (lib/playback_launch.lua), kept as SPDRN's own copy rather than a shared
-- MPAPI utility since MPAPI.playback's driver (api/playback/driver.lua)
-- already owns the per-EVENT pacing; this is only for the one-time
-- bootstrap-to-BLIND_SELECT wait before a driver even exists.
SPDRN._playback_waiters = SPDRN._playback_waiters or {}

function SPDRN._playback_wait_for(predicate, callback)
	SPDRN._playback_waiters[#SPDRN._playback_waiters + 1] = { predicate = predicate, callback = callback }
end

local _playback_launch_update_ref = Game.update
function Game:update(dt)
	_playback_launch_update_ref(self, dt)
	for i = #SPDRN._playback_waiters, 1, -1 do
		local w = SPDRN._playback_waiters[i]
		if w.predicate() then
			table.remove(SPDRN._playback_waiters, i)
			w.callback()
		end
	end
end
