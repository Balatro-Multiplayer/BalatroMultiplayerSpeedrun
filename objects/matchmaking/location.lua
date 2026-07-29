-- §16.11: Enemy Location Indicator. Each client broadcasts its own current
-- ante/round whenever it changes; every other client stores it keyed by
-- SENDER id in SPDRN._locations, never overwriting a single shared "the
-- enemy" scalar. This deliberately avoids PvP's own Enemy Location HUD bug
-- (ROADMAP.md §17.11, still open there): PvP's equivalent broadcast
-- (pvp_location) is received unconditionally into one global
-- PVP.GAME.enemy.location field regardless of which lobby member sent it, so
-- in any N>2 mode the last broadcast to arrive stomps every other player's
-- location -- a last-write-wins race, not scoped to any particular opponent.
-- Keying by player id here means an N-player SPDRN lobby (up to 16) never
-- has that problem: every player's own last-known location is independently
-- tracked and correct regardless of broadcast ordering.
SPDRN._locations = SPDRN._locations or {}

-- Multi-run modes (WST/Stake Climb/All Deck) reset ante/round back down for
-- every new run via request_run_transition, so ante/round alone can't tell a
-- player just starting run 3 apart from one still grinding out run 1 -- the
-- former is further along in the race despite the lower ante. Every
-- multi-run gamemode's own calculate() increments _run_count once per
-- completed run, so "current run" is that count + 1; single-run modes
-- (Gold Stake Single, Challenge) never set it, so this naturally falls back
-- to run 1. Guarded for lobbies that don't implement get_gamemode_instance
-- (the fake lobbies used by this file's own tests).
local function current_run(lobby)
	if not lobby or not lobby.get_gamemode_instance then
		return 1
	end
	local instance = lobby:get_gamemode_instance()
	if not instance then
		return 1
	end
	return (instance._run_count or 0) + 1
end

local function current_location(lobby)
	if not G.GAME then
		return nil
	end
	return {
		run = current_run(lobby),
		ante = (G.GAME.round_resets and G.GAME.round_resets.ante) or 1,
		round = G.GAME.round or 0,
	}
end

-- Polled every frame from this file's own Game:update hook (below), the same
-- wall-clock/poll pattern as SPDRN._check_seed_scout_timer and
-- SPDRN._check_match_duration -- there is no single engine event covering
-- every way a run's ante/round can change (shop, blind select, mid-round).
function SPDRN._check_location_broadcast()
	if not (MPAPI.is_active(SPDRN.id) and MPAPI.get_current_lobby()) then
		return
	end
	if not (G.GAME and G.STAGE == G.STAGES.RUN) then
		return
	end
	local lobby = MPAPI.get_current_lobby()
	local loc = current_location(lobby)
	if not loc then
		return
	end
	local last = SPDRN._last_broadcast_location
	if last and last.run == loc.run and last.ante == loc.ante and last.round == loc.round then
		return
	end
	SPDRN._last_broadcast_location = loc
	SPDRN._locations[lobby.player_id] = loc
	lobby:action(MPAPI.ActionTypes['spdrn_location']):broadcast(loc)
end

-- Is `loc` further along than `other` (nil `other` always loses)? Run takes
-- priority over ante/round for the multi-run reason explained above `current_run`;
-- `run` defaults to 1 for locations broadcast before this field existed.
local function is_further(loc, other)
	if not other then
		return true
	end
	local run, other_run = loc.run or 1, other.run or 1
	if run ~= other_run then
		return run > other_run
	end
	if loc.ante ~= other.ante then
		return loc.ante > other.ante
	end
	return loc.round > other.round
end

-- The furthest-along OTHER player's location (design doc: "a single indicator
-- for the furthest-along opponent's current run/ante/round") -- excludes the
-- local player themselves, even if they're actually in the lead. Returns
-- nil, nil if no other player has broadcast a location yet.
function SPDRN.furthest_opponent_location()
	local lobby = MPAPI.get_current_lobby()
	if not lobby then
		return nil, nil
	end
	local best_id, best_loc
	for _, p in ipairs(lobby:get_players()) do
		if p.id ~= lobby.player_id then
			local loc = SPDRN._locations[p.id]
			if loc and is_further(loc, best_loc) then
				best_id, best_loc = p.id, loc
			end
		end
	end
	return best_id, best_loc
end
