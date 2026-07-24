MPAPI.GameMode({
	key = SPDRN.Gamemode.GOLD_STAKE_SINGLE,
	display_name = 'Gold Stake Single',
	has_ranked_mode = true,
	max_players = {
		public = 16,
		private = 16,
		ranked = 4,
	},
	-- Pre-run deck draft (matchmaking only): 5 random decks, ban down to the 1 played.
	ban_pick = { pool_size = 5, keep = 1 },
	init = function(self)
		self._win_fired = false
		self._forfeited = {}
	end,
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
		-- The deck is applied via G.GAME.viewed_back (the proven pattern); start_run's
		-- `deck` arg is ignored by the base game. Resolve the ref (key or display name)
		-- to a Back center and stage it before starting.
		local key = SPDRN.resolve_back_key(deck_name)
		if G.GAME and key and G.P_CENTERS[key] then
			G.GAME.viewed_back = G.P_CENTERS[key]
		end
		G.FUNCS.start_run(nil, {
			stake = 8,
			seed = seed,
		})
	end,
})
