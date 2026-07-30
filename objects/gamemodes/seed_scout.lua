-- How long the scouting phase lasts (seconds) before the real timed race begins. Kept as a
-- module-level var (not a magic number in _check_seed_scout_timer) so it's easy to temporarily
-- shorten for local iteration/testing without hunting through the file.
SPDRN.SEED_SCOUT_DURATION = 60

-- §16.4: a combined deck+stake draft, the same shape PvP itself uses for its own
-- matches (pvp_api/actions/run_lifecycle.lua's BAN_PICK) -- pool items are
-- { key = <deck back>, stake = <1-8> } pairs, decorated with the vanilla stake
-- sticker. Previously this mode drafted only the deck (a plain 5-pool ban_pick)
-- and picked the stake through an entirely separate host-only metadata button,
-- uncoordinated with the deck draft and never exposed to the other player at all.
local function scout_pool(count)
	local keys = {}
	for _, center in ipairs(G.P_CENTER_POOLS.Back or {}) do
		keys[#keys + 1] = center.key
	end
	for i = #keys, 2, -1 do
		local j = math.random(i)
		keys[i], keys[j] = keys[j], keys[i]
	end
	local pool = {}
	for i = 1, math.min(count, #keys) do
		pool[i] = { key = keys[i], stake = math.random(8) }
	end
	return pool
end

local function decorate_scout_tile(card, item)
	if type(item) == 'table' and item.stake then
		card.sticker = G.sticker_map[SMODS.stake_from_index(item.stake)]
	end
end

MPAPI.GameMode({
	key = SPDRN.Gamemode.SEED_SCOUT,
	display_name = 'Seed Scout',
	max_players = {
		public = 16,
		private = 16,
	},
	-- The whole mechanic is committing to and mastering one specific seed -- re-rolling mid-
	-- format would undermine that, same rationale as White Stake Triple's seed lock.
	seed_change_allowed = false,
	-- Opts into MPAPI.BanPick.start running in private lobbies too, not just matchmaking (this
	-- mode is never queueable, same rationale as All Deck/Challenge).
	always_draft = true,
	ban_pick = {
		pool_size = 5,
		keep = 1,
		build_pool = function() return scout_pool(5) end,
		decorate_tile = decorate_scout_tile,
	},
	-- §16.7: 1 run -- the race phase only. SPDRN._run_started_at (what the
	-- duration-cap poll measures elapsed time against) is reset when the scout
	-- phase transitions to the race phase (see _check_seed_scout_timer below),
	-- so the scouting window is already excluded automatically.
	duration_cap_seconds = SPDRN.DURATION_CAP_PER_RUN_SECONDS,
	init = function(self)
		-- 'scout' (SEED_SCOUT_DURATION-second $500 free-play window on the match's seed/deck/stake, thrown away)
		-- -> 'race' (the real timed run, regular money, same seed/deck/stake).
		self._phase = 'scout'
		self._scout_locked = false
		self._scout_deck = nil
		self._scout_seed = nil
		self._scout_stake = nil
		self._scout_started_at = nil
		self._scout_restart_pending = false
		self._win_fired = false
		self._forfeited = {}
	end,
	-- Win detection only runs once the real race has begun -- a freak fast scouting-phase
	-- clear (unlikely within SEED_SCOUT_DURATION, but not impossible) must never end the match early.
	calculate = function(self, context)
		if self._phase ~= 'race' then
			return
		end
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
	-- Dying during scouting doesn't matter (everything is thrown away anyway) -- silently
	-- restart a fresh scout attempt instead of showing the normal Restart/Forfeit lose screen.
	-- A 'race'-phase death falls through to that normal screen unchanged (return false).
	on_run_lost = function(self)
		if self._phase ~= 'scout' then
			return false
		end
		if not self._scout_restart_pending then
			self._scout_restart_pending = true
			SPDRN.request_run_transition(self, self._scout_deck, self._scout_seed)
		end
		return true
	end,
	start_run = function(self, deck_ref, seed)
		self._scout_restart_pending = false
		-- Multi-run-style progression (scout restarts, and the scout->race transition) reaches
		-- start_run directly (not via safe_start_run), so tear down here too, same as White
		-- Stake Triple/Stake Climb/All Deck.
		SPDRN.teardown_existing_run()

		-- Lock in the deck/seed/stake on the very first call (the initial scout start) and
		-- reuse them for every subsequent call (scout-death restarts, the scout->race
		-- transition). deck_ref is a { key, stake } draft survivor in matchmaking/private-lobby
		-- play (always_draft); practice mode has no draft (solo) and instead passes a plain
		-- deck ref plus self._meta_stake from lobby metadata (see SPDRN.begin_run).
		if not self._scout_locked then
			self._scout_locked = true
			local deck_key, stake
			if type(deck_ref) == 'table' then
				deck_key, stake = deck_ref.key, deck_ref.stake
			else
				deck_key = deck_ref
			end
			self._scout_deck = deck_key
			self._scout_seed = seed
			self._scout_stake = stake or self._meta_stake or 1
		end

		local key = SPDRN.resolve_back_key(self._scout_deck)
		if G.GAME and key and G.P_CENTERS[key] then
			G.GAME.viewed_back = G.P_CENTERS[key]
		end

		if self._phase == 'scout' then
			-- Anchor the countdown once (survives scout-death restarts -- dying doesn't buy
			-- more scouting time). SPDRN._check_seed_scout_timer (polled from core.lua) is what
			-- actually advances the phase once this elapses.
			self._scout_started_at = self._scout_started_at or love.timer.getTime()
			SPDRN._pending_dollars_override = 500
		end
		-- 'race'-phase calls (the scout->race transition) intentionally do NOT set a dollars
		-- override -- regular starting money, per the mechanic's own design.

		G.FUNCS.start_run(nil, {
			stake = self._scout_stake,
			seed = self._scout_seed,
		})
	end,
})

-- Polled every frame from core.lua's Game:update hook. Advances a Seed Scout match from the
-- scouting phase to the real race once SPDRN.SEED_SCOUT_DURATION has elapsed. Wall-clock driven
-- (not ante/context driven, unlike every other gamemode hook) since there is no engine event
-- for "N seconds have passed" -- this is why it needs its own poll rather than reacting to
-- MPAPI.calculate_context like calculate() does.
function SPDRN._check_seed_scout_timer()
	if not (MPAPI.is_active(SPDRN.id) and MPAPI.get_current_lobby()) then
		return
	end
	local lobby = MPAPI.get_current_lobby()
	local meta = lobby:get_metadata() or {}
	if meta.gamemode ~= SPDRN.Gamemode.SEED_SCOUT then
		return
	end
	local instance = lobby:get_gamemode_instance()
	if not instance or instance._phase ~= 'scout' or not instance._scout_started_at then
		return
	end
	-- Mirrors SPDRN.timer._tick's own "only once actually in the run" guard -- don't fire while
	-- still mid blind-select/menu transition.
	if not (G.GAME and G.STAGE == G.STAGES.RUN) then
		return
	end
	if love.timer.getTime() - instance._scout_started_at < SPDRN.SEED_SCOUT_DURATION then
		return
	end

	-- Setting _phase = 'race' here (synchronously, before the actual restart happens) is itself
	-- the re-entry guard: the very next poll sees _phase ~= 'scout' and returns immediately.
	instance._phase = 'race'
	-- The OFFICIAL displayed speedrun clock only counts the real race, not the scouting phase --
	-- reset it exactly like a fresh begin_run would, then let request_run_transition (not
	-- another queued Event -- see its own comment in ui/lobby/run_start.lua for why) perform
	-- the actual restart on the next tick, outside this poll's own call stack.
	SPDRN._run_started_at = love.timer.getTime()
	if SPDRN.timer then
		SPDRN.timer.start()
	end
	SPDRN.request_run_transition(instance, instance._scout_deck, instance._scout_seed)
end

-- Read by ui/timer/lifecycle.lua's timer._tick: while a Seed Scout match's
-- scouting phase is still running, the shared race clock counts DOWN the
-- remaining scouting time instead of counting up an elapsed time -- there's
-- no meaningful "final time" to accumulate during a phase whose whole point
-- is to throw the run away, so a countdown to the phase's own end is more
-- useful than an elapsed counter. Returns nil outside Seed Scout's scout
-- phase, in which case the timer falls back to its normal elapsed display.
-- Mirrors _check_seed_scout_timer's own lobby/instance/phase checks above.
function SPDRN._seed_scout_remaining_seconds()
	local lobby = MPAPI.get_current_lobby()
	local meta = lobby and lobby:get_metadata()
	if not (meta and meta.gamemode == SPDRN.Gamemode.SEED_SCOUT) then
		return nil
	end
	local instance = lobby:get_gamemode_instance()
	if not (instance and instance._phase == 'scout' and instance._scout_started_at) then
		return nil
	end
	local elapsed = love.timer.getTime() - instance._scout_started_at
	return math.max(0, SPDRN.SEED_SCOUT_DURATION - elapsed)
end
