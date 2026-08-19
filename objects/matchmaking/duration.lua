-- §16.7: match duration cap. This is a per-gamemode option
-- (MPAPI.GameMode's has_duration_cap, default false) -- only modes that opt in and
-- declare a duration_cap_seconds are ever capped; every other mode is never capped,
-- regardless of lobby kind. Currently only White Stake Triple (45 min) and Gold Stake
-- Single (25 min) opt in; the rest don't have the option yet.
--
-- For a mode that opts in: casual/ranked matches are always capped; a private lobby
-- only if the host opts in too (ui/lobby/options.lua's Duration Cap toggle,
-- meta.duration_cap_opt_in). Practice is solo (nothing to rank against, and
-- MPAPI.is_matchmaking/get_lobby_kind already treat it as neither matchmaking nor
-- private) so it's never capped.
local function cap_applies(gm_def, meta)
	if not gm_def.has_duration_cap then
		return false
	end
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
	local gm_def = meta.gamemode and MPAPI.GameModes[meta.gamemode]
	if not gm_def then
		return
	end
	if not cap_applies(gm_def, meta) then
		return
	end
	if not (G.GAME and G.STAGE == G.STAGES.RUN) then
		return
	end
	if not SPDRN._run_started_at then
		return
	end
	if love.timer.getTime() - SPDRN._run_started_at < gm_def.duration_cap_seconds then
		return
	end

	-- Set the guard first (same idiom as _check_seed_scout_timer): the very
	-- next poll sees it set and returns immediately, so a slow broadcast round
	-- trip can never fire this twice.
	SPDRN._match_timeout_fired = true
	lobby:action(MPAPI.ActionTypes['spdrn_match_timeout']):broadcast({})
end
