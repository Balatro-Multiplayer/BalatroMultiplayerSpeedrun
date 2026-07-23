MPAPI.GameMode({
	key = SPDRN.Gamemode.CHALLENGE,
	display_name = 'Challenge',
	max_players = {
		public = 16,
		private = 16,
	},
	-- Drives the lobby's deck-panel dispatcher (ui/lobby/controls.lua) to show a "Choose
	-- Challenge" button instead of "Choose Deck" -- the challenge itself fixes the deck, there
	-- is nothing else to draft, so this mode has no ban_pick at all.
	picks_challenge = true,
	init = function(self)
		self._win_fired = false
		self._forfeited = {}
	end,
	-- Single run, same ante>=9 win detection as Gold Stake Single -- confirmed (Phase 0 of the
	-- implementation plan) that no installed Challenge overrides win_ante away from 8.
	calculate = function(self, context)
		if not context.ante_change then
			return
		end
		local ante = context.ante
		if ante < 9 then
			self._win_fired = false
			return
		end
		if self._win_fired then
			return
		end
		self._win_fired = true
		SPDRN.record_run_completed()

		local lobby = MPAPI.get_current_lobby()
		if not lobby then
			return
		end
		return { winner = lobby.player_id }
	end,
	on_player_forfeit = function(self, player_id)
		local winner_id = self:check_single_survivor(player_id)
		if not winner_id then
			return
		end
		return { winner = winner_id }
	end,
	start_run = function(self, deck_name, seed)
		-- self._meta_challenge is stamped by SPDRN.begin_run from the lobby metadata's
		-- `challenge` field (set by the Choose Challenge picker) -- read directly rather than
		-- cached in init(), since init() runs before begin_run stamps it (same ordering as
		-- White Stake Triple's own _run_decks/_base_seed).
		local challenge_id = self._meta_challenge
		local idx = challenge_id and get_challenge_int_from_id(challenge_id)
		local challenge = idx and idx > 0 and G.CHALLENGES[idx]
		if not challenge then
			SPDRN.sendWarnMessage('spdrn_challenge: unknown challenge id: ' .. tostring(challenge_id))
		end
		-- Matches vanilla's own G.FUNCS.start_challenge_run: stake is always 1, the challenge
		-- itself supplies the deck/jokers/vouchers/restrictions.
		G.FUNCS.start_run(nil, {
			stake = 1,
			seed = seed,
			challenge = challenge,
		})
	end,
})
