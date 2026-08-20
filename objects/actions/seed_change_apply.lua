-- Broadcast by the host once SPDRN.register_seed_vote (ui/lobby/seed_vote.lua)
-- sees a unanimous spdrn_seed_vote -- every client (host included, via the
-- loopback) applies the SAME given seed to whatever run it's currently on.
-- Deliberately not spdrn_start_game: that resets the whole match (fresh
-- draft/countdown, _run_count back to 0), which is wrong for an in-run
-- reseed that's meant to leave run progression untouched (see
-- SPDRN.apply_current_run_seed's own comment).
MPAPI.ActionType({
	key = 'spdrn_seed_change_apply',
	on_receive = function(action_type, from_player_id, params)
		SPDRN.apply_current_run_seed(params.seed)
	end,
})
