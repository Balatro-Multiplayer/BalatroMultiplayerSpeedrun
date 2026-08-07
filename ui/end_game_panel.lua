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
	-- view_deck() returns a G.UIT.ROOT node, not a G.UIT.R row -- splicing it directly
	-- into `contents` (a sibling of the title row) breaks create_UIBox_generic_options's
	-- width computation used for centering (engine/ui.lua's calculate_xywh only stacks
	-- G.UIT.R children vertically; anything else, including ROOT, is added to the WIDTH
	-- accumulator instead), which visibly shifted the deck view off-center. Wrapping it in
	-- its own child UIBox behind an O node -- exactly how the base game's own view_deck()
	-- hosts its content internally, and how create_tabs hosts each tab -- makes it a
	-- single fixed-width leaf from the parent row's perspective.
	--
	-- No explicit back_func: the default (exit_overlay_menu) already returns to the SPDRN
	-- end screen via MPAPI's restorable-overlay mechanism -- see
	-- BalatroMultiplayerAPI/api/end_screen.lua's MPAPI.end_screen_show /
	-- G.FUNCS.exit_overlay_menu.
	G.FUNCS.overlay_menu({
		definition = create_UIBox_generic_options({ contents = {
			{ n = G.UIT.R, config = { align = 'cm', padding = 0.1 }, nodes = {
				{ n = G.UIT.T, config = { text = (SPDRN._end_screen_selected_player_name or 'Player') .. "'s Deck", scale = 0.5, colour = G.C.UI.TEXT_LIGHT, shadow = true } },
			} },
			{ n = G.UIT.R, config = { align = 'cm' }, nodes = {
				{ n = G.UIT.O, config = { object = UIBox{
					definition = G.UIDEF.view_selected_player_deck(),
					config = { offset = { x = 0, y = 0 } },
				} } },
			} },
		} }),
	})
end

-- Repopulates the shared jokers CardArea from the selected player's
-- captured snapshot (objects/matchmaking/progress.lua's capture_local_jokers)
-- via MPAPI.rebuild_jokers_area (BalatroMultiplayerAPI/api/end_screen.lua) --
-- the same plain key/edition/eternal/perishable shape PvP's own
-- PVP._collected_results uses, so that part is shared rather than
-- reimplemented per mod.
local function rebuild_end_game_jokers(player_id, player_name)
	local result = player_id and SPDRN._collected_results and SPDRN._collected_results[player_id]
	MPAPI.rebuild_jokers_area(SPDRN.end_game_jokers, result and result.jokers)
	SPDRN.end_game_jokers_text = (result and result.jokers) and ((player_name or 'Player') .. "'s Jokers")
		or ((player_name or 'Player') .. ' -- still playing...')
end

-- §end-screen stats: the 4 match-wide stat rows' reactive text (a plain table
-- read via ref_table/ref_value, same as end_game_jokers_text above), rebuilt
-- alongside the jokers area whenever the end-screen player selector changes.
SPDRN.end_game_stats_text = SPDRN.end_game_stats_text or {}

local function format_time_ms(ms)
	if not ms then
		return '--'
	end
	return SPDRN.timer.format(ms / 1000)
end

-- `player_id` prefers a finalized/broadcast SPDRN._collected_results entry
-- (works for any player, once their match has ended); falls back to a LIVE
-- read of the local player's own SPDRN._progress when nothing's been
-- broadcast yet (the OOPS run-lost screen, or a forfeit screen shown before
-- report_match_result runs) -- that fallback only ever applies to the local
-- player, since only their own in-progress state is available to read.
local function rebuild_end_game_stats(player_id)
	local lobby = MPAPI.get_current_lobby()
	local result = player_id and SPDRN._collected_results and SPDRN._collected_results[player_id]
	local text = SPDRN.end_game_stats_text

	if result then
		text.completion_time = format_time_ms(result.match_completion_ms)
		text.best_run_time = format_time_ms(result.best_run_time_ms)
		text.times_skipped = tostring(result.times_skipped or 0)
		text.best_hand = result.best_hand_amt and number_format(result.best_hand_amt) or '--'
	elseif player_id and lobby and player_id == lobby.player_id and SPDRN._progress then
		local p = SPDRN._progress
		local live_completion_ms = (love.timer.getTime() - (SPDRN._run_started_at or love.timer.getTime())) * 1000
		local live_hand_amt = G.GAME and G.GAME.round_scores and G.GAME.round_scores.hand and G.GAME.round_scores.hand.amt
		local live_best_hand = math.max(p.best_hand_amt or 0, live_hand_amt or 0)
		text.completion_time = format_time_ms(live_completion_ms)
		text.best_run_time = format_time_ms(p.best_run_time_ms)
		text.times_skipped = tostring(p.times_skipped or 0)
		text.best_hand = live_best_hand > 0 and number_format(live_best_hand) or '--'
	else
		text.completion_time = '--'
		text.best_run_time = '--'
		text.times_skipped = '--'
		text.best_hand = '--'
	end
end

-- Full-width row matching the base game's own hand/poker_hand row layout
-- (create_UIBox_round_scores_row, label_w = score_w = 3.5), but reading its
-- value from SPDRN.end_game_stats_text via ref_table/ref_value instead of a
-- fixed DynaText string, so it updates live when the player selector changes.
function SPDRN.create_end_game_stat_row(label, ref_value, colour)
	return {
		n = G.UIT.R,
		config = { align = 'cm', padding = 0.05, r = 0.1, colour = darken(G.C.JOKER_GREY, 0.1), emboss = 0.05 },
		nodes = {
			{ n = G.UIT.C, config = { align = 'cm', padding = 0.02, minw = 3.5, maxw = 3.5 }, nodes = {
				{ n = G.UIT.T, config = { text = label, scale = 0.5, colour = G.C.UI.TEXT_LIGHT, shadow = true } },
			} },
			{ n = G.UIT.C, config = { align = 'cr' }, nodes = {
				{ n = G.UIT.C, config = { align = 'cm', minh = 0.5, r = 0.1, minw = 3.5, colour = G.C.BLACK, emboss = 0.05 }, nodes = {
					{ n = G.UIT.C, config = { align = 'cm', padding = 0.05, r = 0.1, minw = 3.5 }, nodes = {
						{ n = G.UIT.T, config = { ref_table = SPDRN.end_game_stats_text, ref_value = ref_value, scale = 0.45, colour = colour or G.C.FILTER, shadow = true } },
					} },
				} },
			} },
		},
	}
end

-- The 4 rows SPDRN.win_body/lose_body pass as MPAPI.end_screen_body's
-- stat_rows override, in place of the base game's 6 vanilla stats. `player_id`
-- is the selected player when a panel/selector exists, or the local player
-- directly on panel-less screens (OOPS, forfeit) -- see rebuild_end_game_stats.
function SPDRN.build_end_game_stat_rows(player_id)
	rebuild_end_game_stats(player_id)
	return {
		SPDRN.create_end_game_stat_row(localize('k_stat_completion_time'), 'completion_time', G.C.FILTER),
		SPDRN.create_end_game_stat_row(localize('k_stat_best_run_time'), 'best_run_time', G.C.FILTER),
		SPDRN.create_end_game_stat_row(localize('k_stat_times_skipped'), 'times_skipped', G.C.RED),
		SPDRN.create_end_game_stat_row(localize('k_stat_best_hand'), 'best_hand', G.C.RED),
	}
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
	rebuild_end_game_stats(p.id)
end

-- The shared body content both SPDRN.win_body and SPDRN.lose_body embed:
-- jokers area + a selector rotating through every lobby member + a View Deck
-- button for whichever player is currently selected -- built via the shared
-- MPAPI.end_screen_player_panel (BalatroMultiplayerAPI/api/end_screen.lua),
-- which PvP's own PVP.UI.build_end_game_extras (ui/game/game_end.lua) also
-- calls. Rebuilt fresh each time the end screen opens (SPDRN.end_game_jokers
-- itself is recreated so a stale CardArea from a previous match never lingers).
function SPDRN.build_end_game_extras()
	SPDRN.end_game_jokers = CardArea(
		0,
		0,
		5 * G.CARD_W,
		G.CARD_H,
		{ card_limit = G.GAME.starting_params and G.GAME.starting_params.joker_slots or 5, type = 'joker', highlight_limit = 1, fixed_limit = true }
	)

	local lobby = MPAPI.get_current_lobby()
	local players, options, current_option = MPAPI.end_screen_default_selection(lobby)

	-- Preserve a still-valid prior selection across a rebuild (e.g. the pause menu or
	-- View Deck closing, BalatroMultiplayerAPI/api/end_screen.lua's restorable-overlay
	-- mechanism) instead of snapping back to the local player every time.
	if SPDRN._end_screen_selected_player_id then
		for i, p in ipairs(players) do
			if p.id == SPDRN._end_screen_selected_player_id then
				current_option = i
				break
			end
		end
	end

	local selected = players[current_option]
	SPDRN._end_screen_selected_player_id = selected and selected.id
	SPDRN._end_screen_selected_player_name = selected and (selected.displayName or selected.id)
	rebuild_end_game_jokers(SPDRN._end_screen_selected_player_id, SPDRN._end_screen_selected_player_name)

	return MPAPI.end_screen_player_panel({
		jokers_text_ref = { table = SPDRN, key = 'end_game_jokers_text' },
		jokers_area = SPDRN.end_game_jokers,
		options = options,
		current_option = current_option,
		opt_callback = 'spdrn_end_screen_select_player',
		view_deck_button = MPAPI.end_screen_view_deck_button('spdrn_view_selected_deck', 'View Deck'),
	})
end
