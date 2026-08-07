-- §end-screen stats: counts blind skips for the match-wide "times skipped"
-- end-screen stat (SPDRN._progress.times_skipped, objects/matchmaking/progress.lua).
-- G.FUNCS.skip_blind is a base-game button callback with no dedicated event to
-- hook into instead -- wrap-and-call-through is the same pattern PvP's
-- ui/game/functions.lua uses for the same button.
local skip_blind_ref = G.FUNCS.skip_blind
G.FUNCS.skip_blind = function(...)
	skip_blind_ref(...)
	if MPAPI.is_active(SPDRN.id) and MPAPI.get_current_lobby() then
		SPDRN.record_skip()
	end
end
