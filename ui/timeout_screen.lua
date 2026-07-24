-- §16.7: shown to every player the instant a match hits its format's duration
-- cap (objects/matchmaking/duration.lua). Deliberately neutral -- not framed as
-- a win or a loss -- because who actually placed first isn't decided by this
-- screen; that still resolves the normal way via report_match_result (see
-- objects/actions/match_timeout.lua), exactly like a natural finish.
function SPDRN.timeout_body(buttons)
	local right_col = {
		create_UIBox_round_scores_row('furthest_ante', G.C.FILTER),
		create_UIBox_round_scores_row('furthest_round', G.C.FILTER),
		{ n = G.UIT.R, config = { align = 'cm', minh = 0.2, minw = 0.1 }, nodes = {} },
	}
	for _, b in ipairs(buttons or SPDRN.end_screen_buttons(false)) do
		right_col[#right_col + 1] = b
	end

	return {
		n = G.UIT.R,
		config = { align = 'cm', padding = 0.15 },
		nodes = {
			{
				n = G.UIT.C,
				config = { align = 'cm' },
				nodes = {
					{
						n = G.UIT.R,
						config = { align = 'cm', padding = 0.05, colour = G.C.BLACK, emboss = 0.05, r = 0.1 },
						nodes = {
							{ n = G.UIT.R, config = { align = 'cm', padding = 0.08 }, nodes = {
								create_UIBox_round_scores_row('hand'),
								create_UIBox_round_scores_row('poker_hand'),
							} },
							{
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
											UIBox_button({ button = 'copy_seed', label = { localize('b_copy') }, colour = G.C.BLUE, scale = 0.3, minw = 2.3, minh = 0.4, focus_args = { nav = 'wide' } }),
										},
									},
									{
										n = G.UIT.C,
										config = { align = 'tr', padding = 0.08 },
										nodes = right_col,
									},
								},
							},
						},
					},
				},
			},
		},
	}
end

SPDRN.show_timeout_screen = function()
	if SPDRN.timer then
		SPDRN.timer.stop()
	end
	MPAPI.end_screen_show({
		won = false,
		no_esc = true,
		title_key = 'k_times_up',
		title_colour = G.C.WHITE,
		bg_colour = G.C.BLUE,
		sounds = { { 'whoosh2', 0.9, 0.7 } },
		body = function()
			return SPDRN.timeout_body()
		end,
	})
end
