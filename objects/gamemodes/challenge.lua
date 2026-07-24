-- §16.4: a real drafted pool of random Challenge presets, same shape as Gold Stake
-- Single/Stake Climb's 5-candidate deck draft -- previously this mode had no
-- pick/ban at all, just a host-only cycle through the FULL G.CHALLENGES list
-- written straight into lobby metadata. Tiles are ban_pick's ordinary deck-back
-- Cards (the engine is deck-shaped), so each pool item pins a fixed neutral
-- Red Deck back purely for tile art and carries the real challenge id/name as
-- metadata; decorate_tile labels the tile with the challenge's name so players
-- can actually tell them apart.
local function challenge_pool(count)
	local indices = {}
	for i = 1, #G.CHALLENGES do
		indices[i] = i
	end
	for i = #indices, 2, -1 do
		local j = math.random(i)
		indices[i], indices[j] = indices[j], indices[i]
	end
	local pool = {}
	for i = 1, math.min(count, #indices) do
		local c = G.CHALLENGES[indices[i]]
		pool[i] = { key = 'b_red', challenge_id = c.id, challenge_name = c.name or c.id }
	end
	return pool
end

local function decorate_challenge_tile(card, item)
	if not (type(item) == 'table' and item.challenge_name) then
		return
	end
	card.children.mp_challenge_label = UIBox({
		definition = {
			n = G.UIT.ROOT,
			config = { padding = 0, colour = G.C.CLEAR },
			nodes = {
				{ n = G.UIT.R, config = { r = 0.08, padding = 0.06, align = 'cm', minw = card.T.w - 0.1, colour = G.C.BLACK, shadow = true }, nodes = {
					{ n = G.UIT.T, config = { text = item.challenge_name, colour = G.C.UI.TEXT_LIGHT, scale = 0.26, shadow = true } },
				} },
			},
		},
		config = { align = 'tmi', offset = { x = 0, y = -0.4 }, parent = card },
	})
end

MPAPI.GameMode({
	key = SPDRN.Gamemode.CHALLENGE,
	display_name = 'Challenge',
	max_players = {
		public = 16,
		private = 16,
	},
	-- Opts into MPAPI.BanPick.start running in private lobbies too, not just matchmaking (this
	-- mode is never queueable, same rationale as All Deck).
	always_draft = true,
	ban_pick = {
		pool_size = 5,
		keep = 1,
		build_pool = function() return challenge_pool(5) end,
		decorate_tile = decorate_challenge_tile,
	},
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
	start_run = function(self, deck_ref, seed)
		-- deck_ref is a { key, challenge_id, challenge_name } draft survivor in matchmaking/
		-- private-lobby play (always_draft); practice mode has no draft (solo, per
		-- ui/main_menu/practice.lua) and instead stamps the id straight into lobby metadata,
		-- read here via self._meta_challenge (see SPDRN.begin_run).
		local challenge_id = (type(deck_ref) == 'table' and deck_ref.challenge_id) or self._meta_challenge
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
