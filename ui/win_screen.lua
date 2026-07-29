-- The speedrun-specific body of the win screen, rendered inside the shared
-- MPAPI.end_screen shell (background, ph_you_win title, jimbo-spot wrap + quip live in
-- the API). Layout mirrors PvP's ui/game/game_end.lua end_game_body: jokers
-- area + player selector at the top of the left column (SPDRN.build_end_game_extras,
-- ui/end_game_panel.lua), stats below, buttons on the right.
function SPDRN.win_body()
	local right_col = {
		create_UIBox_round_scores_row('furthest_ante', G.C.FILTER),
		create_UIBox_round_scores_row('furthest_round', G.C.FILTER),
		{ n = G.UIT.R, config = { align = 'cm', minh = 0.2, minw = 0.1 }, nodes = {} },
	}
	for _, b in ipairs(SPDRN.end_screen_buttons(true)) do
		right_col[#right_col + 1] = b
	end

	local left_col = {}
	for _, row in ipairs(SPDRN.build_end_game_extras()) do
		left_col[#left_col + 1] = row
	end
	left_col[#left_col + 1] = { n = G.UIT.R, config = { align = 'cm', padding = 0.08 }, nodes = {
		create_UIBox_round_scores_row('hand'),
		create_UIBox_round_scores_row('poker_hand'),
	} }
	left_col[#left_col + 1] = {
		n = G.UIT.R,
		config = { align = 'cm' },
		nodes = {
			{
				n = G.UIT.C,
				config = { align = 'cm', padding = 0.08 },
				nodes = {
					create_UIBox_round_scores_row('cards_played', G.C.BLUE),
					create_UIBox_round_scores_row('cards_discarded', G.C.RED),
					create_UIBox_round_scores_row('cards_purchased', G.C.MONEY),
					create_UIBox_round_scores_row('times_rerolled', G.C.GREEN),
					create_UIBox_round_scores_row('new_collection', G.C.WHITE),
					create_UIBox_round_scores_row('seed', G.C.WHITE),
					UIBox_button({ button = 'copy_seed', label = { localize('b_copy') }, colour = G.C.BLUE, scale = 0.3, minw = 2.3, minh = 0.4 }),
				},
			},
			{
				n = G.UIT.C,
				config = { align = 'tr', padding = 0.08 },
				nodes = right_col,
			},
		},
	}

	return {
		n = G.UIT.R,
		config = { align = 'cm', padding = 0.15 },
		nodes = {
			{
				n = G.UIT.C,
				config = { align = 'cm' },
				nodes = left_col,
			},
		},
	}
end

function SPDRN.create_win_screen()
	return MPAPI.end_screen_uibox({ won = true, id = 'spdrn_win_UI', body = SPDRN.win_body })
end

SPDRN.show_win_screen = function()
	if SPDRN.timer then
		SPDRN.timer.stop()
	end
	MPAPI.end_screen_show({
		won = true,
		id = 'spdrn_win_UI',
		sounds = 'win',
		quip = { prefix = 'wq_', max = 7 },
		body = SPDRN.win_body,
	})
end
