-- One matchmaking section (Ranked or Casual): the two gamemode buttons stacked, with the
-- section label on a readable horizontal row beneath them. `enabled = false` greys the
-- buttons out via MPAPI's standard disabled-button styling instead of removing them, so
-- the Ranked section stays visible but non-interactive (see SPDRN._ranked_queue_available()
-- below).
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

-- Whether the Ranked queue buttons should actually be clickable right now:
-- MPAPI's confirmation that the *server* accepted our launcher-integrity
-- challenge response (see MPAPI.is_launcher_verified() in
-- api/connection/lifecycle.lua - NOT a client-side-only "did BET answer"
-- check, the actual server verdict). server.joinQueue() enforces this same
-- requirement independently either way (matchmaking.service.ts) - this only
-- avoids sending a request that's going to 403, and gives the player an
-- honest button state instead of a click that silently does nothing or
-- bounces off an error toast. Ranked play itself used to also be gated
-- behind a separate, always-off SPDRN.RANKED_ENABLED kill switch (a
-- client-side mirror of the server's own RANKED_ENABLED env flag) - removed
-- now that Ranked is actually live; the server's assertRankedEnabled()
-- guard in matchmaking.route.ts is still the real switch if it ever needs
-- to come back.
function SPDRN._ranked_queue_available()
	return MPAPI.is_launcher_verified()
end

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
							queue_section(localize('k_ranked_cap'), 'spdrn_queue_ranked_white', 'spdrn_queue_ranked_gold', SPDRN._ranked_queue_available()),
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
	if not SPDRN._ranked_queue_available() then
		return
	end
	G.FUNCS.exit_overlay_menu()
	SPDRN._join_queue(SPDRN.LobbyKind.RANKED, SPDRN.Gamemode.WHITE_STAKE_TRIPLE)
end

G.FUNCS.spdrn_queue_ranked_gold = function()
	if not SPDRN._ranked_queue_available() then
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
