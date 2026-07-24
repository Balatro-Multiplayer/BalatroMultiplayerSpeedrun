MPAPI.GameMode({
	key = SPDRN.Gamemode.STAKE_CLIMB,
	display_name = 'Stake Climb',
	max_players = {
		public = 16,
		private = 16,
	},
	-- Best-of-8 progressive format: replaying an earlier stake on a fresh seed would undermine
	-- the climb, same rationale as White Stake Triple's seed lock.
	seed_change_allowed = false,
	-- Pre-run deck draft: not used in matchmaking (this mode is never queueable), but reused
	-- here purely so SPDRN.required_deck_count picks up "needs 1 deck" for the up-front picker,
	-- exactly like Gold Stake Single.
	ban_pick = { pool_size = 5, keep = 1 },
	-- §16.7: 8 runs (one per stake, White through Gold).
	duration_cap_seconds = 8 * SPDRN.DURATION_CAP_PER_RUN_SECONDS,
	init = function(self)
		self._run_count = 0
		self._ante9_fired = false
		self._forfeited = {}
	end,
	calculate = function(self, context)
		if not context.ante_change then
			return
		end
		local ante = context.ante
		if ante < 9 then
			self._ante9_fired = false
			return
		end
		if self._ante9_fired then
			return
		end
		self._ante9_fired = true
		SPDRN.record_run_completed()

		self._run_count = self._run_count + 1

		if self._run_count < 8 then
			self._ante9_fired = false
			local run_idx = self._run_count + 1
			-- Same deck every run -- only the stake climbs (see start_run) -- so there's no
			-- per-run deck to resolve, just the single deck locked in at match start.
			local deck = (self._run_decks and self._run_decks[1]) or SPDRN.Deck.DEFAULT
			-- Each run plays a distinct seed derived deterministically from the match's base
			-- seed, exactly like White Stake Triple, so both players climb identical boards.
			local seed = SPDRN.derive_seed(self._base_seed, run_idx)
			SPDRN.request_run_transition(self, deck, seed)
		else
			self._run_count = 0
			local lobby = MPAPI.get_current_lobby()
			if not lobby then
				return
			end
			return { winner = lobby.player_id }
		end
	end,
	on_player_forfeit = function(self, player_id)
		local winner_id = self:check_single_survivor(player_id)
		if not winner_id then
			return
		end
		return { winner = winner_id }
	end,
	start_run = function(self, deck_name, seed)
		-- Multi-run progression reaches start_run directly (not via safe_start_run), so tear
		-- down the finished run's blind HUD here too, else it dangles into the next run and
		-- crashes the smods HUD_blind_debuff assert. Same as White Stake Triple.
		SPDRN.teardown_existing_run()
		local key = SPDRN.resolve_back_key(deck_name)
		if G.GAME and key and G.P_CENTERS[key] then
			G.GAME.viewed_back = G.P_CENTERS[key]
		end
		-- Stake climbs with the run: run 1 = White (1) ... run 8 = Gold (8). _run_count counts
		-- COMPLETED runs, so the run currently starting is _run_count + 1 -- recomputed here
		-- rather than stored, so "Restart Run" (which calls start_run again without touching
		-- _run_count) naturally replays the same stake instead of accidentally advancing it.
		local stake = math.min((self._run_count or 0) + 1, 8)
		G.FUNCS.start_run(nil, {
			stake = stake,
			seed = seed,
		})
	end,
})
