MPAPI.GameMode({
	key = SPDRN.Gamemode.WHITE_STAKE_TRIPLE,
	display_name = 'White Stake Triple',
	has_ranked_mode = true,
	-- Best-of-3 across three runs; re-rolling a seed mid-format is not allowed.
	seed_change_allowed = false,
	max_players = {
		public = 16,
		private = 16,
		ranked = 2,
	},
	-- Pre-run deck draft (matchmaking only): 9 random decks, ban down to 3 -- one per run.
	ban_pick = { pool_size = 9, keep = 3 },
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

		if self._run_count < 3 then
			self._ante9_fired = false
			local lobby = MPAPI.get_current_lobby()
			local meta = lobby and lobby:get_metadata()
			-- The three decks map to runs 1/2/3 in order (ban-pick survivors in matchmaking,
			-- or the host/practice picker's ordered selection elsewhere). _run_count was just
			-- incremented for the completed run, so the next run's deck is index _run_count + 1.
			local run_idx = self._run_count + 1
			local deck = self._run_decks and self._run_decks[run_idx]
			if not deck and meta and meta.deck then
				-- Fall back to the metadata deck: index the per-run list, or reuse the single deck.
				deck = type(meta.deck) == 'table' and (meta.deck[run_idx] or meta.deck[#meta.deck]) or meta.deck
			end
			-- Last-resort guard so the next run never starts with no deck (which black-screens):
			-- reuse the first run's deck rather than handing start_run a nil.
			if not deck then
				deck = (self._run_decks and self._run_decks[1]) or SPDRN.Deck.DEFAULT
			end
			-- Each run plays a distinct seed derived deterministically from the match's base
			-- seed, so both players in a ranked best-of-3 race the same boards (run 1 is the
			-- broadcast seed; runs 2 and 3 derive from it). A same-seed restart-on-death reuses
			-- this run's live seed, so it stays consistent with the derived sequence.
			local seed = SPDRN.derive_seed(self._base_seed, run_idx)
			-- calculate's ante_change branch runs synchronously inside ease_ante. Calling
			-- G.FUNCS.start_run there restarts the game while the in-flight ante/round
			-- transition still holds references to the old state, which crashes. Defer via
			-- SPDRN.request_run_transition (consumed on the next Game:update tick, outside
			-- any Event's call stack) rather than another queued Event -- the latter can
			-- still be mid-iteration when this fires, and start_run's own clear_queue() call
			-- would corrupt that iteration (see the comment on request_run_transition for the
			-- full mechanism -- this was the actual cause of the black-screen-on-deck-switch
			-- bug, not just the crash this defer originally guarded against).
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
		-- crashes the smods HUD_blind_debuff assert.
		SPDRN.teardown_existing_run()
		-- The deck is applied via G.GAME.viewed_back (the proven pattern); start_run's
		-- `deck` arg is ignored by the base game. Resolve the ref (key or display name)
		-- to a Back center and stage it before starting.
		local key = SPDRN.resolve_back_key(deck_name)
		if G.GAME and key and G.P_CENTERS[key] then
			G.GAME.viewed_back = G.P_CENTERS[key]
		end
		G.FUNCS.start_run(nil, {
			stake = 1,
			seed = seed,
		})
	end,
})
