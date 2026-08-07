-- The speedrun win screen's body: the exact same shared MPAPI.end_screen_body
-- PvP's own PVP.UI.end_game_body (ui/game/game_end.lua) calls, with SPDRN's
-- own button set. No side_rows/defeated_by -- SPDRN has no PvP-style
-- opponent-comparison row (it's a race, not a duel), and this is a win, not
-- a loss to a blind.
function SPDRN.win_body()
	local player_panel = SPDRN.build_end_game_extras()
	return MPAPI.end_screen_body({
		player_panel = player_panel,
		stat_rows = SPDRN.build_end_game_stat_rows(SPDRN._end_screen_selected_player_id),
		buttons = SPDRN.end_screen_buttons(true),
	})
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
