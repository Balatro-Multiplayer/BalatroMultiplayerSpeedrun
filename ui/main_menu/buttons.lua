SPDRN.main_menu = SPDRN.main_menu or { buttons = {}, initialized = false }

-- Distinct teal for the Leaderboard button: unused by any other menu button
-- (Blue/Green/Red/Purple/Orange) yet sits within Balatro's bright UI palette.
local _leaderboard_colour = { 0.20, 0.74, 0.72, 1 }

function SPDRN.main_menu.create_buttons()
	local M = SPDRN.main_menu
	if M.initialized then
		return
	end
	local b = M.buttons

	M.find_game_args = {
		id = 'spdrn_find_game',
		button = 'spdrn_find_game',
		colour = G.C.BLUE,
		minw = 3.65,
		minh = 1.55,
		label = { localize('b_find_game_cap') },
		scale = 0.7,
		col = true,
		enabled = true,
	}
	b.find_game = MPAPI.disableable_button(M.find_game_args)
	b.create_lobby = MPAPI.disableable_button({
		id = 'spdrn_create_lobby',
		button = 'spdrn_create_lobby',
		colour = G.C.GREEN,
		minw = 3.65,
		minh = 1.55,
		label = localize('b_create_lobby_cap'),
		scale = 0.7,
		col = true,
		enabled = MPAPI.is_connected(),
	})
	b.join_by_code = MPAPI.disableable_button({
		id = 'spdrn_join_lobby_by_code',
		button = 'spdrn_join_lobby_by_code',
		colour = G.C.RED,
		minw = 3.65,
		minh = 0.6,
		label = { localize('b_by_code_cap') },
		scale = 0.45,
		enabled = MPAPI.is_connected(),
	})
	b.join_from_clipboard = MPAPI.disableable_button({
		id = 'spdrn_join_lobby_from_clipboard',
		button = 'spdrn_join_lobby_from_clipboard',
		colour = G.C.PURPLE,
		minw = 3.65,
		minh = 0.6,
		label = { localize('b_from_clipboard_cap') },
		scale = 0.45,
		enabled = MPAPI.is_connected(),
	})
	b.practice = MPAPI.disableable_button({
		id = 'spdrn_practice',
		button = 'spdrn_practice',
		colour = G.C.ORANGE,
		minw = 2.65,
		minh = 1.35,
		label = { localize('b_practice_cap') },
		scale = 0.54,
		col = true,
		enabled = true,
	})
	b.leaderboard = MPAPI.disableable_button({
		id = 'spdrn_leaderboard',
		button = 'spdrn_open_leaderboard',
		colour = _leaderboard_colour,
		minw = 2.65,
		minh = 1.35,
		label = { localize('b_leaderboard_cap') },
		scale = 0.54,
		col = true,
		enabled = function()
			return MPAPI.is_connected()
		end,
	})
	M.initialized = true
end

SPDRN.update_main_menu_buttons = function()
	local M = SPDRN.main_menu
	if not M.initialized then
		return
	end
	M.buttons.find_game:update()
	M.buttons.create_lobby:update()
	M.buttons.join_by_code:update()
	M.buttons.join_from_clipboard:update()
	M.buttons.leaderboard:update()
end

SPDRN._show_searching_state = function(searching)
	local M = SPDRN.main_menu
	if not M.initialized or not M.find_game_args then
		return
	end
	if searching then
		M.find_game_args.label = { localize('b_cancel_search_cap') }
		M.find_game_args.button = 'spdrn_cancel_queue'
		M.find_game_args.colour = G.C.RED
	else
		M.find_game_args.label = { localize('b_find_game_cap') }
		M.find_game_args.button = 'spdrn_find_game'
		M.find_game_args.colour = G.C.BLUE
	end
	M.buttons.find_game:update()
end
