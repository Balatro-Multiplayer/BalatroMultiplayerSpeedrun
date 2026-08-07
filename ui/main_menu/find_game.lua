-- One matchmaking section (Ranked or Casual): the two gamemode buttons stacked, with the
-- section label on a readable horizontal row beneath them. `enabled = false` greys the
-- buttons out via MPAPI's standard disabled-button styling (see SPDRN.RANKED_ENABLED below)
-- instead of removing them, so the Ranked section stays visible but non-interactive.
local function queue_section(label, white_btn, gold_btn, enabled)
	return {
		n = G.UIT.C,
		config = { align = 'cm', padding = 0.1, r = 0.2, colour = G.C.BLACK },
		nodes = {
			{ n = G.UIT.R, config = { align = 'cm', padding = 0.05 }, nodes = {
				MPAPI.disableable_button({ button = white_btn, label = { 'White Stake', 'Triple' }, colour = G.C.ETERNAL, minw = 2.5, minh = 1.0, scale = 0.4, col = true, enabled = enabled }).node,
			} },
			{ n = G.UIT.R, config = { align = 'cm', padding = 0.05 }, nodes = {
				MPAPI.disableable_button({ button = gold_btn, label = { 'Gold Stake', 'Single' }, colour = G.C.GOLD, minw = 2.5, minh = 1.0, scale = 0.4, col = true, enabled = enabled }).node,
			} },
			{ n = G.UIT.R, config = { align = 'cm', padding = 0.05 }, nodes = {
				{ n = G.UIT.T, config = { text = label, scale = 0.5, colour = G.C.UI.TEXT_LIGHT, shadow = true } },
			} },
		},
	}
end

-- Client-side mirror of the server's ranked-disable flag (see server: env
-- RANKED_ENABLED / assertRankedEnabled in matchmaking.route.ts). Hardcoded
-- off for now -- the client has no config-fetch path to learn the server's
-- live value (see BalatroMultiplayerServer's config.route.ts: chatEnabled/
-- testingMode are the only flags exposed today, and nothing consumes them
-- client-side yet). Flip this back to `true` to re-enable the buttons once
-- ranked play is turned back on.
SPDRN.RANKED_ENABLED = false

G.FUNCS.spdrn_find_game = function()
	G.FUNCS.overlay_menu({
		definition = create_UIBox_generic_options({
			contents = {
				{ n = G.UIT.R, config = { align = 'cm', padding = 0.1 }, nodes = {
					{ n = G.UIT.T, config = { text = 'Find Game', scale = 0.6, colour = G.C.UI.TEXT_LIGHT, shadow = true } },
				} },
				{
					n = G.UIT.R,
					config = { align = 'cm', padding = 0.1 },
					nodes = {
						{ n = G.UIT.C, config = { align = 'cm', padding = 0.1 }, nodes = {
							queue_section(localize('k_ranked_cap'), 'spdrn_queue_ranked_white', 'spdrn_queue_ranked_gold', SPDRN.RANKED_ENABLED),
						} },
						{ n = G.UIT.C, config = { align = 'cm', padding = 0.1 }, nodes = {
							queue_section(localize('k_casual_cap'), 'spdrn_queue_casual_white', 'spdrn_queue_casual_gold', true),
						} },
					},
				},
			},
		}),
	})
end

G.FUNCS.spdrn_queue_ranked_white = function()
	if not SPDRN.RANKED_ENABLED then
		return
	end
	G.FUNCS.exit_overlay_menu()
	SPDRN._join_queue(SPDRN.LobbyKind.RANKED, SPDRN.Gamemode.WHITE_STAKE_TRIPLE)
end

G.FUNCS.spdrn_queue_ranked_gold = function()
	if not SPDRN.RANKED_ENABLED then
		return
	end
	G.FUNCS.exit_overlay_menu()
	SPDRN._join_queue(SPDRN.LobbyKind.RANKED, SPDRN.Gamemode.GOLD_STAKE_SINGLE)
end

G.FUNCS.spdrn_queue_casual_white = function()
	G.FUNCS.exit_overlay_menu()
	SPDRN._join_queue(SPDRN.LobbyKind.CASUAL, SPDRN.Gamemode.WHITE_STAKE_TRIPLE)
end

G.FUNCS.spdrn_queue_casual_gold = function()
	G.FUNCS.exit_overlay_menu()
	SPDRN._join_queue(SPDRN.LobbyKind.CASUAL, SPDRN.Gamemode.GOLD_STAKE_SINGLE)
end

G.FUNCS.spdrn_cancel_queue = function()
	SPDRN._cancel_queue()
end
