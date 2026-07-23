-- Vanilla-only deck pool, shuffled. Excludes any deck added by an installed mod (identified by
-- carrying a `.mod` field -- vanilla decks are hardcoded in the base game, not registered via
-- any mod's SMODS.Back{...} call, so they never get one stamped; confirmed empirically via
-- `cctl eval 'G.P_CENTERS.b_red.mod'` returning nil). Keeps the deck sequence identical across
-- clients with different mod sets installed, rather than drifting per-player.
function SPDRN.vanilla_deck_pool()
	local keys = {}
	for _, center in ipairs(G.P_CENTER_POOLS.Back or {}) do
		if center.mod == nil then
			keys[#keys + 1] = center.key
		end
	end
	for i = #keys, 2, -1 do
		local j = math.random(i)
		keys[i], keys[j] = keys[j], keys[i]
	end
	return keys
end

MPAPI.GameMode({
	key = SPDRN.Gamemode.ALL_DECK,
	display_name = 'All Deck',
	max_players = {
		public = 16,
		private = 16,
	},
	-- Opts into MPAPI.BanPick.start running in private lobbies too, not just matchmaking (see
	-- objects/actions/start_game.lua) -- this mode's draft decides PLAY ORDER, not survivors, so
	-- it needs to run wherever the mode is actually played (private lobbies only, since it's
	-- never queueable).
	always_draft = true,
	-- keep = 0: every pool item gets banned, nothing survives -- the ban ORDER (not the empty
	-- survivor list) becomes the run sequence (see start_game.lua's keep==0 handling and
	-- BalatroMultiplayerAPI/api/ban_pick.lua's ban_order tracking). No pool_size: let the
	-- schedule size itself off the real vanilla-deck count via build_pool rather than a
	-- hardcoded number that could drift on a future game update.
	--
	-- Known, accepted limitation: MPAPI.BanPick's turn engine is strictly 2-actor (host + one
	-- other player) regardless of lobby size -- in a 3-16 player lobby, only 2 of the players
	-- actually take turns in the draft; the rest just play whatever order results. Extending
	-- BanPick to true N-player turn order is out of scope (see the implementation plan).
	ban_pick = { keep = 0, build_pool = SPDRN.vanilla_deck_pool },
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
		local total = (self._run_decks and #self._run_decks) or 1

		if self._run_count < total then
			self._ante9_fired = false
			local run_idx = self._run_count + 1
			local deck = (self._run_decks and self._run_decks[run_idx])
				or (self._run_decks and self._run_decks[1])
				or SPDRN.Deck.DEFAULT
			-- Same deterministic per-run derivation as White Stake Triple/Stake Climb, so both
			-- clients land on the same seed for every deck in the sequence.
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
		G.FUNCS.start_run(nil, {
			stake = 1,
			seed = seed,
		})
	end,
})
