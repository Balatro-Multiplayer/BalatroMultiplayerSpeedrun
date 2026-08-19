-- SPDRN's live transport for MPAPI.replay (the generic RLOG recorder in
-- BalatroMultiplayerAPI/api/replay/recorder.lua), ported from
-- BalatroMultiplayerPvP/pvp_api/replay_log_actions.lua. SPDRN's own SMODS
-- prefix is already "spdrn", so unlike PvP's "pvp_log_event" (which needs
-- prefix_config={key=false} because PvP's SMODS prefix is "mp", not "pvp"),
-- "spdrn_log_event" already carries SPDRN's own prefix -- SMODS.modify_key
-- skips re-prefixing a key that already starts with "<prefix>_" (see every
-- other spdrn_* action in objects/actions/), so no prefix_config override
-- is needed here to match that existing convention.
--
-- One event per broadcast, not batched, so the server-side buffer (and any
-- future spectator) sees each line as it happens -- same rationale as PvP's.
-- _last_seen_t tracks each sender's own elapsed-t high-water mark; SPDRN has
-- no opponent-HUD projection to feed today (each player races their own
-- board), but this is the same bookkeeping a future reconnect-tail-replay
-- would need, so it's kept for parity rather than reinvented later.
MPAPI.replay._last_seen_t = MPAPI.replay._last_seen_t or {}

local function self_id()
	local lobby = MPAPI.get_current_lobby()
	return lobby and lobby.player_id
end

SPDRN.RLOG_EVENT_ACTION = MPAPI.ActionType({
	key = 'spdrn_log_event',
	parameters = {
		{ key = 't', type = 'number', required = true },
		{ key = 'opcode', type = 'string', required = true },
		{ key = 'args', type = 'table', required = false },
	},
	on_receive = function(_at, from, params)
		if from == self_id() then
			return
		end
		local prev = MPAPI.replay._last_seen_t[from] or 0
		if params.t and params.t > prev then
			MPAPI.replay._last_seen_t[from] = params.t
		end
	end,
})

-- Mirrors MPAPI.replay.record's flexible args shape (nil | scalar | table)
-- into what spdrn_log_event's `args` param needs: nil, or a table (a bare
-- scalar gets wrapped so it still round-trips).
local function normalize_args(args)
	if args == nil then
		return nil
	end
	if type(args) == 'table' then
		return args
	end
	return { args }
end

-- Registered by mod id (MPAPI.replay.register_broadcaster), not assigned
-- directly to MPAPI.replay.broadcast_event -- see BalatroMultiplayerAPI/
-- api/replay/recorder.lua's "Live transport" doc comment for why that's a
-- registry keyed by mod id rather than a single slot (PvP and SPDRN can both
-- be installed at once). No-ops cleanly with no lobby (practice mode,
-- headless tests) -- the local carbon/human text lines this pairs with are
-- unaffected either way.
MPAPI.replay.register_broadcaster(SPDRN.id, function(t, opcode, args)
	local lobby = MPAPI.get_current_lobby()
	if not lobby then
		return
	end
	lobby:action(SPDRN.RLOG_EVENT_ACTION):broadcast({ t = t, opcode = opcode, args = normalize_args(args) })
end)
