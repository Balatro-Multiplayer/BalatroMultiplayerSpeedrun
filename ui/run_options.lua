-- Custom pause/options screen for an active speedrun run.

-- §16.9: a real, per-player, current-run-only action -- no voting, no effect on
-- any other player, whether in practice or a live lobby (see
-- SPDRN.change_current_run_seed).
G.FUNCS.spdrn_seed_change = function()
	G.FUNCS.exit_overlay_menu()
	SPDRN.change_current_run_seed()
end

G.FUNCS.spdrn_forfeit = function()
	G.FUNCS.exit_overlay_menu()
	-- Practice is solo: forfeiting just ends the run, so show the game-over screen
	-- directly rather than broadcasting a forfeit to players who aren't there.
	if SPDRN.get_lobby_kind() == SPDRN.LobbyKind.PRACTICE then
		G.E_MANAGER:add_event(Event({
			func = function()
				SPDRN.show_forfeit_screen()
				return true
			end,
		}))
		return
	end
	local lobby = MPAPI.get_current_lobby()
	if not lobby then
		return
	end
	local action = lobby:action(MPAPI.ActionTypes['spdrn_forfeit'])
	action:broadcast({})
end

SPDRN.create_run_options = function()
	-- Build each button as its own row inside one column so they stack vertically.
	-- (Adding mixed node types as separate generic-options contents laid the seed
	-- and forfeit buttons out side by side.)
	local rows = {}
	local function add_row(node)
		rows[#rows + 1] = { n = G.UIT.R, config = { align = 'cm', padding = 0.08 }, nodes = { node } }
	end

	add_row(UIBox_button({ button = 'settings', label = { localize('b_settings') }, minw = 5, focus_args = { snap_to = true } }))

	-- §16.9: "at any point during a run, with no restriction" -- hidden entirely
	-- when the gamemode sets seed_change_allowed = false, otherwise always
	-- enabled (no time-window gate).
	local lobby = MPAPI.get_current_lobby()
	local meta = lobby and lobby:get_metadata()
	local gm = meta and meta.gamemode and MPAPI.GameModes[meta.gamemode]
	if not gm or gm.seed_change_allowed ~= false then
		add_row(UIBox_button({
			button = 'spdrn_seed_change',
			label = { 'Seed Change' },
			colour = G.C.BLUE,
			minw = 5,
		}))
	end

	add_row(UIBox_button({ button = 'spdrn_forfeit', label = { 'Forfeit' }, minw = 5, colour = G.C.RED }))

	-- §17.9: Collection/Mods, shared with PvP's identical overlay (both mods
	-- previously stopped at 3 buttons; the doc's claimed 5-button set needs
	-- these two on top of the mode-specific ones above).
	for _, row in ipairs(MPAPI.pause_menu_extra_rows()) do
		rows[#rows + 1] = row
	end

	return create_UIBox_generic_options({
		contents = {
			{ n = G.UIT.C, config = { align = 'cm' }, nodes = rows },
		},
	})
end
