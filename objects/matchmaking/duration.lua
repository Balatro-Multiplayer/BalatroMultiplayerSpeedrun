-- §16.7: match duration cap. Casual/ranked matches are always capped; a
-- private lobby only if the host opts in (ui/lobby/options.lua's Duration Cap
-- toggle, meta.duration_cap_opt_in). Practice is solo (nothing to rank
-- against, and MPAPI.is_matchmaking/get_lobby_kind already treat it as neither
-- matchmaking nor private) so it's never capped.
--
-- SPDRN.DURATION_CAP_PER_RUN_SECONDS (domain/duration_cap.lua) is 15 minutes
-- per run the format actually plays, not a single flat number -- a 3-run
-- format like White Stake Triple gets 3x as long as a 1-run format like Gold
-- Stake Single, matching the design doc's "fifteen minutes per run in the
-- format" wording exactly.

-- Every gamemode except All Deck declares a fixed duration_cap_seconds
-- (run count is fixed per format, so it can be computed once by hand). All
-- Deck's run count is only known once its draft has picked a play order
-- (instance._run_decks, populated at begin_run/after the draft completes) --
-- it deliberately has no static duration_cap_seconds field, so this always
-- falls through to the dynamic per-instance computation below for that mode.
local function duration_cap_seconds(gm_def, instance)
	if gm_def.duration_cap_seconds then
		return gm_def.duration_cap_seconds
	end
	local runs = (instance and instance._run_decks and #instance._run_decks) or 1
	return SPDRN.DURATION_CAP_PER_RUN_SECONDS * runs
end

local function cap_applies(meta)
	local kind = SPDRN.get_lobby_kind()
	if SPDRN.is_matchmaking(kind) then
		return true
	end
	if kind == SPDRN.LobbyKind.PRIVATE then
		return meta.duration_cap_opt_in == true
	end
	return false
end

-- Polled every frame from core.lua's Game:update hook -- the same wall-clock-
-- driven pattern as SPDRN._check_seed_scout_timer, since there is no engine
-- event for "N seconds have passed". Host-authoritative: only the host
-- actually broadcasts the cutoff, so every client ends the match on the same
-- broadcast rather than each racing to detect it independently off
-- slightly-drifted local clocks.
function SPDRN._check_match_duration()
	if not (MPAPI.is_active(SPDRN.id) and MPAPI.get_current_lobby()) then
		return
	end
	if SPDRN._match_timeout_fired then
		return
	end
	local lobby = MPAPI.get_current_lobby()
	if not lobby.is_host then
		return
	end
	local meta = lobby:get_metadata() or {}
	if not cap_applies(meta) then
		return
	end
	local gm_def = meta.gamemode and MPAPI.GameModes[meta.gamemode]
	if not gm_def then
		return
	end
	if not (G.GAME and G.STAGE == G.STAGES.RUN) then
		return
	end
	if not SPDRN._run_started_at then
		return
	end
	local instance = lobby:get_gamemode_instance()
	local cap = duration_cap_seconds(gm_def, instance)
	if love.timer.getTime() - SPDRN._run_started_at < cap then
		return
	end

	-- Set the guard first (same idiom as _check_seed_scout_timer): the very
	-- next poll sees it set and returns immediately, so a slow broadcast round
	-- trip can never fire this twice.
	SPDRN._match_timeout_fired = true
	lobby:action(MPAPI.ActionTypes['spdrn_match_timeout']):broadcast({})
end
