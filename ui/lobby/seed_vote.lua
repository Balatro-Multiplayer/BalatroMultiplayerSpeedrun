-- Broadcast a vote to change the seed of whatever run every player is
-- currently on (see ui/run_options.lua's G.FUNCS.spdrn_seed_change - the
-- real, non-practice entry point).
function SPDRN.cast_seed_vote()
	local lobby = SPDRN.lobby.ref or MPAPI.get_current_lobby()
	if not lobby then
		return
	end
	local action = lobby:action(MPAPI.ActionTypes['spdrn_seed_vote'])
	action:broadcast({})
end

-- Runs on every client when any vote arrives (broadcast reaches all). Each client tallies
-- independently and shows progress; the host applies the new seed to the
-- current run (not a whole-match restart - see spdrn_seed_change_apply's own
-- comment) once the vote is unanimous, broadcasting it so every client lands
-- on the exact same seed rather than each generating their own.
function SPDRN.register_seed_vote(voter_id)
	local lobby = MPAPI.get_current_lobby()
	if not lobby then
		return
	end

	local count, total, unanimous = SPDRN.lobby.seed_votes:record(voter_id)

	-- Surface vote progress in the chat log (works even when chat send is disabled) rather
	-- than as an on-screen toast.
	if MPAPI.chat and MPAPI.chat.addMessage then
		MPAPI.chat.addMessage(
			(localize('k_seed_vote') or 'Vote to change seed') .. ': ' .. count .. '/' .. total,
			G.C.BLUE
		)
	end

	if lobby.is_host and unanimous then
		SPDRN.lobby.seed_votes:reset()
		local action = lobby:action(MPAPI.ActionTypes['spdrn_seed_change_apply'])
		action:broadcast({ seed = SPDRN.generate_seed() })
	end
end
