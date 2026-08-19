SPDRN.build_pre_lobby_ui = function()
	SPDRN.main_menu.create_buttons()
	MPAPI.set_logo_offset(0, true)
	local b = SPDRN.main_menu.buttons
	return {
		n = G.UIT.ROOT,
		config = { align = 'cm', colour = G.C.CLEAR },
		nodes = {
			{
				n = G.UIT.C,
				config = { align = 'bm' },
				nodes = {
					{
						n = G.UIT.R,
						config = { align = 'cm', padding = 0.1, r = 0.1, emboss = 0.1, colour = G.C.L_BLACK, mid = true },
						nodes = {
							b.find_game.node,
							{
								n = G.UIT.C,
								config = { align = 'cm' },
								nodes = {
									{ n = G.UIT.R, config = { align = 'cm' }, nodes = {
										{ n = G.UIT.C, config = { align = 'cm', padding = 0.05 }, nodes = { b.leaderboard.node } },
										{ n = G.UIT.C, config = { align = 'cm', padding = 0.05 }, nodes = { b.practice.node } },
									} },
								},
							},
							{
								n = G.UIT.C,
								config = { align = 'cm', padding = 0.1, r = 0.2, colour = G.C.BLACK },
								nodes = {
									{
										n = G.UIT.C,
										config = { align = 'cm', maxh = 1.4 },
										nodes = {
											{ n = G.UIT.T, config = { text = localize('k_join_lobby_cap'), scale = 0.45, colour = G.C.UI.TEXT_LIGHT, vert = true, maxh = 1.4 } },
										},
									},
									{
										n = G.UIT.C,
										config = { align = 'cm', padding = 0.1 },
										nodes = {
											{ n = G.UIT.R, config = { align = 'cm' }, nodes = { b.join_by_code.node } },
											{ n = G.UIT.R, config = { align = 'cm' }, nodes = { b.join_from_clipboard.node } },
										},
									},
								},
							},
							b.create_lobby.node,
						},
					},
					{ n = G.UIT.R, config = { align = 'cm', padding = 0.05 }, nodes = {
						{ n = G.UIT.T, config = { text = 'Made Possible by Artifex Digital', scale = 0.34, colour = G.C.UI.TEXT_INACTIVE } },
					} },
				},
			},
		},
	}
end
