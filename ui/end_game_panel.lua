-- §16.10/17: the win/lose end-screen's opponent jokers + deck viewer, modeled
-- on PvP's ui/game/game_end.lua (real CardArea jokers + a G.UIDEF.view_deck()
-- based deck viewer), generalized from PvP's binary you/nemesis toggle into a
-- create_option_cycle selector that rotates through every player in the
-- lobby -- SPDRN is N-player, not 1v1. Both the jokers area and the deck
-- viewer read from SPDRN._collected_results (objects/matchmaking/result.lua),
-- populated as each player's own spdrn_player_result broadcast arrives.

-- Rebuilds a full deck of real (dummy) playing cards from the
-- semicolon-joined "suit-rank-enhancement-edition-seal" string
-- objects/matchmaking/progress.lua's capture_local_deck encodes -- the same
-- wire format PvP's card_to_string/load_nemesis_deck use. Invalid entries are
-- skipped rather than erroring, same defensiveness as PvP's version.
function SPDRN.decode_deck_string(deck_string)
	local cards = {}
	if not deck_string or deck_string == '' then
		return cards
	end
	if not SPDRN._end_screen_deck_area then
		SPDRN._end_screen_deck_area = CardArea(-100, -100, G.CARD_W, G.CARD_H, { type = 'deck' })
	end
	local area = SPDRN._end_screen_deck_area
	for card_str in string.gmatch(deck_string, '([^;]+)') do
		local parts = {}
		for part in string.gmatch(card_str, '([^-]+)') do
			parts[#parts + 1] = part
		end
		-- G.P_CARDS keys are "<suit letter>_<rank letter>" (e.g. "S_A", "H_T")
		-- -- progress.lua's capture_local_deck already encodes both as these
		-- exact short forms, so front_key is built directly from parts[1]/[2]
		-- with no further expansion (matching PvP's load_nemesis_deck, which
		-- also uses card_params[1]/[2] as-is).
		local suit, rank = parts[1], parts[2]
		local enhancement, edition, seal = parts[3], parts[4], parts[5]
		local front_key = suit and rank and (suit .. '_' .. rank)
		if front_key and G.P_CARDS[front_key] then
			local center = (enhancement and enhancement ~= 'none') and G.P_CENTERS[enhancement] or nil
			local card = create_playing_card({ front = G.P_CARDS[front_key], center = center }, area, true, true)
			if edition and edition ~= 'none' and G.P_CENTERS['e_' .. edition] then
				card:set_edition({ [edition] = true }, true, true)
			end
			if seal and seal ~= 'none' and G.P_SEALS[seal] then
				card:set_seal(seal, true, true)
			end
			-- create_playing_card unconditionally inserts into the REAL
			-- G.playing_cards regardless of `area` -- undo that (same trick
			-- PvP's load_nemesis_deck uses) so a viewer built after the match
			-- ends never corrupts the actual deck array.
			table.remove(G.playing_cards, #G.playing_cards)
			cards[#cards + 1] = card
		end
	end
	return cards
end

-- G.UIDEF.view_deck() (base game) always reads G.playing_cards -- swap it to
-- the currently-selected player's decoded deck for the duration of the call,
-- exactly like PvP's G.UIDEF.view_nemesis_deck().
function G.UIDEF.view_selected_player_deck()
	local playing_cards_ref = G.playing_cards
	G.playing_cards = SPDRN._end_screen_deck_cards or {}
	local t = G.UIDEF.view_deck()
	G.playing_cards = playing_cards_ref
	return t
end

G.FUNCS.spdrn_view_selected_deck = function()
	local player_id = SPDRN._end_screen_selected_player_id
	local result = player_id and SPDRN._collected_results and SPDRN._collected_results[player_id]
	SPDRN._end_screen_deck_cards = SPDRN.decode_deck_string(result and result.deck)
	G.FUNCS.overlay_menu({
		definition = create_UIBox_generic_options({ contents = {
			{ n = G.UIT.R, config = { align = 'cm', padding = 0.1 }, nodes = {
				{ n = G.UIT.T, config = { text = (SPDRN._end_screen_selected_player_name or 'Player') .. "'s Deck", scale = 0.5, colour = G.C.UI.TEXT_LIGHT, shadow = true } },
			} },
			G.UIDEF.view_selected_player_deck(),
		} }),
	})
end

-- Clears and repopulates the shared jokers CardArea from the selected
-- player's captured snapshot (objects/matchmaking/progress.lua's
-- capture_local_jokers) -- plain key/edition/eternal/perishable data, not a
-- CardArea:save() round-trip, same technique ui/roster_screen.lua's own
-- build_joker_area already uses.
local function rebuild_end_game_jokers(player_id, player_name)
	local area = SPDRN.end_game_jokers
	if not area then
		return
	end
	if area.cards then
		for _, card in ipairs(area.cards) do
			-- Avoid Jokers being removed from activating removal abilities
			-- (e.g. Negatives) during the swap, same guard PvP's
			-- toggle_players_jokers uses.
			card.added_to_deck = false
		end
		remove_all(area.cards)
	end
	area.cards = {}

	local result = player_id and SPDRN._collected_results and SPDRN._collected_results[player_id]
	if result and result.jokers then
		for _, j in ipairs(result.jokers) do
			local center = G.P_CENTERS[j.key]
			if center then
				local card = Card(area.T.x, area.T.y, G.CARD_W, G.CARD_H, nil, center, { bypass_discovery_center = true })
				if j.edition then
					card:set_edition(j.edition, true, true)
				end
				card.ability.eternal = j.eternal or false
				card.ability.perishable = j.perishable or false
				area:emplace(card)
			end
		end
		SPDRN.end_game_jokers_text = (player_name or 'Player') .. "'s Jokers"
	else
		SPDRN.end_game_jokers_text = (player_name or 'Player') .. ' -- still playing...'
	end
end

G.FUNCS.spdrn_end_screen_select_player = function(e)
	if not e then
		return
	end
	local lobby = MPAPI.get_current_lobby()
	local players = lobby and lobby:get_players()
	local p = players and players[e.to_key]
	if not p then
		return
	end
	SPDRN._end_screen_selected_player_id = p.id
	SPDRN._end_screen_selected_player_name = p.displayName or p.id
	rebuild_end_game_jokers(p.id, SPDRN._end_screen_selected_player_name)
end

-- The shared body content both SPDRN.win_body and SPDRN.lose_body embed:
-- jokers area + a selector rotating through every lobby member + a View Deck
-- button for whichever player is currently selected. Rebuilt fresh each time
-- the end screen opens (SPDRN.end_game_jokers itself is recreated so a stale
-- CardArea from a previous match never lingers).
function SPDRN.build_end_game_extras()
	SPDRN.end_game_jokers = CardArea(
		0,
		0,
		5 * G.CARD_W,
		G.CARD_H,
		{ card_limit = G.GAME.starting_params and G.GAME.starting_params.joker_slots or 5, type = 'joker', highlight_limit = 1, fixed_limit = true }
	)

	local lobby = MPAPI.get_current_lobby()
	local players = (lobby and lobby:get_players()) or {}
	local options = {}
	local current_option = 1
	for i, p in ipairs(players) do
		options[i] = p.displayName or p.id
		if p.id == (lobby and lobby.player_id) then
			current_option = i
		end
	end
	if #options == 0 then
		options = { '--' }
	end

	local selected = players[current_option]
	SPDRN._end_screen_selected_player_id = selected and selected.id
	SPDRN._end_screen_selected_player_name = selected and (selected.displayName or selected.id)
	rebuild_end_game_jokers(SPDRN._end_screen_selected_player_id, SPDRN._end_screen_selected_player_name)

	return {
		{ n = G.UIT.R, config = { align = 'cm', padding = 0.08 }, nodes = {
			{ n = G.UIT.T, config = { ref_table = SPDRN, ref_value = 'end_game_jokers_text', scale = 0.7, maxw = 5, shadow = true } },
		} },
		{ n = G.UIT.R, config = { align = 'cm', padding = 0.08 }, nodes = {
			{ n = G.UIT.O, config = { object = SPDRN.end_game_jokers } },
		} },
		{ n = G.UIT.R, config = { align = 'cm', padding = 0.1 }, nodes = {
			{ n = G.UIT.C, config = { align = 'cm', minw = 3 }, nodes = {
				create_option_cycle({
					options = options,
					current_option = current_option,
					opt_callback = 'spdrn_end_screen_select_player',
					w = 3,
					cycle_shoulders = true,
					no_pips = true,
					focus_args = { snap_to = true, nav = 'wide' },
				}),
			} },
			{ n = G.UIT.C, config = { minw = 0.15 } },
			{
				n = G.UIT.C,
				config = { button = 'spdrn_view_selected_deck', align = 'cm', padding = 0.12, colour = G.C.BLUE, emboss = 0.05, minh = 0.7, minw = 2, maxw = 2, r = 0.1, shadow = true, hover = true },
				nodes = {
					{ n = G.UIT.T, config = { text = 'View Deck', colour = G.C.UI.TEXT_LIGHT, scale = 0.5, col = true } },
				},
			},
		} },
	}
end
