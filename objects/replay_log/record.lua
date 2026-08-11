-- RLOG recording for SPDRN: now just the run_info deferral (below) -- the 14
-- generic shop/hand/blind opcodes this file used to hook itself (play,
-- discard, buy, sell, use, pack_pick, pack_skip, reroll, reorder, cashout,
-- select_blind, skip_blind, money_delta) are hooked exactly once, generically,
-- by BalatroMultiplayerAPI/api/replay/generic_codes.lua now -- see that
-- file's header comment for why installing them per-mod (this file AND
-- PvP's overrides/game.lua both wrapping the same vanilla G.FUNCS) caused a
-- real double-record bug the old MPAPI.is_active(mod_id) ownership guard
-- (formerly this file's own `rlog_active()`) only worked around rather than
-- fixed.
local RLOG = MPAPI.replay

-------------------------------------------------------------------------------
-- run_info: deferred to BLIND_SELECT (see SPDRN._check_pending_run_info
-- below) because `stake` is only known inside each gamemode's own start_run
-- method (objects/gamemodes/*.lua), not at the generic run-transition choke
-- point (ui/lobby/run_start.lua's _check_pending_run_transition) where
-- seed/deck/gamemode are captured. One run_info event per individual Balatro
-- run (first start AND every restart/seed-change) -- NOT one RLOG "run"
-- (begin_run/end_run) per Balatro run anymore, that's now once per whole
-- SPDRN MATCH (see ui/lobby/run_start.lua's SPDRN.begin_run and this file's
-- own end_run retiming below). A SPDRN match can contain several individual
-- Balatro runs (death -> restart, multi-run formats like White Stake Triple);
-- run_info is what lets a replay/viewer tell them apart within the single
-- match-scoped recording.
-------------------------------------------------------------------------------

SPDRN._rlog_pending_run_info = nil

local check_pending_run_transition_ref = SPDRN._check_pending_run_transition
function SPDRN._check_pending_run_transition()
	local pending = SPDRN._pending_run_transition
	if pending and RLOG.is_active() then
		SPDRN._rlog_pending_run_info = {
			seed = pending.seed,
			deck = tostring(pending.deck),
		}
	end
	check_pending_run_transition_ref()
end

-- Polled from core.lua's Game:update hook, same condition
-- SPDRN._check_pending_dollars_override already waits on (BLIND_SELECT fully
-- set up on the NEW run's G.GAME, not the dying old one). Fires on EVERY run
-- transition (first run and every restart), not just match-start.
function SPDRN._check_pending_run_info()
	local pending = SPDRN._rlog_pending_run_info
	if not pending then return end
	if not (G.GAME and G.STATE == G.STATES.BLIND_SELECT and G.blind_select ~= nil) then return end
	SPDRN._rlog_pending_run_info = nil
	MPAPI.RLOGCodes.run_info:write(pending.seed, pending.deck, G.GAME.stake)
end
