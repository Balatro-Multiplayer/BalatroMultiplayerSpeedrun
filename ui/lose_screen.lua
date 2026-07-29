-- Shared end-screen button handlers (used by both win and lose screens).

G.FUNCS.spdrn_continue_sp = function()
	G.FUNCS.exit_overlay_menu()
	G.SETTINGS.paused = false
	local lobby = MPAPI.get_current_lobby()
	if lobby then
		lobby:leave()
	end
end

G.FUNCS.spdrn_return_to_lobby = function()
	G.FUNCS.exit_overlay_menu()
	G.SETTINGS.paused = false
	G.FUNCS.go_to_menu()
end

G.FUNCS.spdrn_leave_from_game = function()
	G.FUNCS.exit_overlay_menu()
	G.SETTINGS.paused = false
	local lobby = MPAPI.get_current_lobby()
	if lobby then
		lobby:leave()
	end
	G.FUNCS.go_to_menu()
end

-- Practice only: restart the same gamemode on a fresh seed.
G.FUNCS.spdrn_play_again = function()
	G.FUNCS.exit_overlay_menu()
	G.SETTINGS.paused = false
	local lobby = MPAPI.get_current_lobby()
	if not lobby then
		G.FUNCS.go_to_menu()
		return
	end
	local meta = lobby:get_metadata()
	SPDRN.begin_run(meta.gamemode, meta.deck or SPDRN.Deck.DEFAULT, SPDRN.generate_seed())
end

-- Restart the current run after losing it to a blind: same seed, same gamemode
-- instance (so White Stake Triple keeps its run count). Works for every lobby kind.
G.FUNCS.spdrn_restart_run = function()
	G.FUNCS.exit_overlay_menu()
	G.SETTINGS.paused = false
	SPDRN.restart_current_run()
end

-- Buttons for the "lost a run to a blind" screen: retry the same seed, or forfeit.
function SPDRN.run_lost_buttons()
	return MPAPI.end_screen_buttons({
		{ button = 'spdrn_restart_run', label = 'Restart Run', colour = G.C.BLUE },
		{ button = 'spdrn_forfeit', label = 'Forfeit', colour = G.C.RED },
	})
end

-- Builds the end-screen action buttons for the current lobby kind.
--   practice    -> Play Again + Leave
--   matchmaking -> (loser) Continue in Singleplayer + Leave; (winner) Leave only
--   private     -> Continue in Singleplayer + Return to Lobby + Leave
function SPDRN.end_screen_buttons(is_winner)
	local kind = SPDRN.get_lobby_kind()
	local specs = {}
	if kind == SPDRN.LobbyKind.PRACTICE then
		specs[#specs + 1] = { button = 'spdrn_play_again', label = 'Practice Again', colour = G.C.BLUE }
		specs[#specs + 1] = { button = 'spdrn_leave_from_game', label = 'Back to Main Menu', colour = G.C.RED }
	elseif SPDRN.is_matchmaking(kind) then
		specs[#specs + 1] = { button = 'spdrn_open_roster', label = 'Roster', colour = G.C.PURPLE }
		if not is_winner then
			specs[#specs + 1] = { button = 'spdrn_continue_sp', label = 'Continue in Singleplayer', colour = G.C.BLUE }
		end
		specs[#specs + 1] = { button = 'spdrn_leave_from_game', label = 'Leave Lobby', colour = G.C.RED }
	else
		specs[#specs + 1] = { button = 'spdrn_open_roster', label = 'Roster', colour = G.C.PURPLE }
		specs[#specs + 1] = { button = 'spdrn_continue_sp', label = 'Continue in Singleplayer', colour = G.C.BLUE }
		specs[#specs + 1] = { button = 'spdrn_return_to_lobby', label = 'Return to Lobby', colour = G.C.GREEN }
		specs[#specs + 1] = { button = 'spdrn_leave_from_game', label = 'Leave Lobby', colour = G.C.RED }
	end

	return MPAPI.end_screen_buttons(specs)
end

-- The speedrun-specific body of the lose screen, rendered inside the shared
-- MPAPI.end_screen shell. `defeated_by_blind` gates the base game's
-- "Defeated By" row (the blind that beat you): it only makes sense when the
-- run actually ended by dying to a blind mid-run. The base-game renderer
-- reads G.GAME.blind.config.blind unconditionally, which for every OTHER
-- loss reason here (an opponent won the race, a self-forfeit) is whatever
-- blind happens to be on deck -- usually not even selected yet -- and its
-- name has no matching localization entry, rendering literally as "ERROR"
-- instead of a blind name (reproduced live: a losing player sitting on the
-- very first blind-select screen when an opponent won showed "Defeated By
-- ERROR"). Only show_run_lost_screen has that "died to a blind" context.
function SPDRN.lose_body(buttons, defeated_by_blind)
	local right_col = {
		create_UIBox_round_scores_row('furthest_ante', G.C.FILTER),
		create_UIBox_round_scores_row('furthest_round', G.C.FILTER),
	}
	if defeated_by_blind then
		right_col[#right_col + 1] = create_UIBox_round_scores_row('defeated_by')
	end
	right_col[#right_col + 1] = { n = G.UIT.R, config = { align = 'cm', minh = 0.2, minw = 0.1 }, nodes = {} }
	for _, b in ipairs(buttons or SPDRN.end_screen_buttons(false)) do
		right_col[#right_col + 1] = b
	end

	local panel_nodes = {}
	for _, row in ipairs(SPDRN.build_end_game_extras()) do
		panel_nodes[#panel_nodes + 1] = row
	end
	panel_nodes[#panel_nodes + 1] = { n = G.UIT.R, config = { align = 'cm', padding = 0.08 }, nodes = {
		create_UIBox_round_scores_row('hand'),
		create_UIBox_round_scores_row('poker_hand'),
	} }
	panel_nodes[#panel_nodes + 1] = {
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
	}

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
						nodes = panel_nodes,
					},
				},
			},
		},
	}
end

-- Loss uses RED at/under the win-ante, BLUE beyond it (a "you gave up a winnable run").
local function lose_bg_colour()
	return (G.GAME.round_resets.ante <= G.GAME.win_ante) and G.C.RED or G.C.BLUE
end

function SPDRN.create_lose_screen(buttons)
	return MPAPI.end_screen_uibox({
		won = false,
		no_esc = true,
		bg_colour = lose_bg_colour(),
		body = function()
			return SPDRN.lose_body(buttons)
		end,
	})
end

-- `keep_timer_running` is set only for the run-lost-to-a-blind screen: that's a restartable
-- run loss, not the match ending, so the speedrun clock must keep counting (including the time
-- spent deciding on this screen). Every terminal screen -- win, opponent-won, forfeit -- leaves
-- it unset so the timer freezes at the match's final time. It doubles as the "did we actually
-- die to a blind" signal for lose_body's defeated_by row, above -- true in exactly the same
-- one case.
SPDRN.show_lose_screen = function(buttons, keep_timer_running)
	if SPDRN.timer and not keep_timer_running then
		SPDRN.timer.stop()
	end
	MPAPI.end_screen_show({
		won = false,
		no_esc = true,
		bg_colour = lose_bg_colour(),
		sounds = { { 'negative', 0.5, 0.7 }, { 'whoosh2', 0.9, 0.7 } },
		room_jiggle = 3,
		quip = { prefix = 'lq_', max = 10 },
		body = function()
			return SPDRN.lose_body(buttons, keep_timer_running)
		end,
	})
end

-- Shown when the player loses their run to a blind (as opposed to an opponent
-- winning): same presentation as the lose screen but offering Restart Run / Forfeit.
SPDRN.show_run_lost_screen = function()
	SPDRN.show_lose_screen(SPDRN.run_lost_buttons(), true)
end

-- Balatro has no single "you lost" callback, so we watch the game-over state off
-- the update loop. Fires once per loss, only inside a SPDRN lobby.
--
-- Deliberately does NOT check `not G.GAME.won` here: end_round() sets G.GAME.won = true
-- whenever ante >= win_ante and the boss blind is up, unconditionally -- it does not check
-- whether the score requirement was actually met. So dying to the win-ante (8) boss blind
-- also leaves G.GAME.won true, which used to make this look like a win and silently skip
-- the lose screen. G.STATE == G.STATES.GAME_OVER is a reliable loss-only signal on its own:
-- every G.STATE = G.STATES.GAME_OVER assignment in the game/SMODS/mod code (end_round's
-- game_over branch, the two hand-limit-0 deck-out checks, and the DT_lose_game debug
-- trigger) is a loss path -- a genuine win never sets it (win_game() shows its own overlay
-- from ROUND_EVAL instead).
function SPDRN._check_run_lost()
	if not (MPAPI.is_active(SPDRN.id) and MPAPI.get_current_lobby()) then
		SPDRN._run_lost_shown = false
		return
	end
	local lost = G.STATE == G.STATES.GAME_OVER
	if not lost then
		SPDRN._run_lost_shown = false
		return
	end
	if SPDRN._run_lost_shown then
		return
	end
	-- A gamemode instance can suppress the default lose screen and handle the loss itself (e.g.
	-- Seed Scout silently restarting a scouting-phase death instead of showing Restart/Forfeit).
	-- Undefined on every existing gamemode, so this is a no-op for them.
	local lobby = MPAPI.get_current_lobby()
	local instance = lobby and lobby:get_gamemode_instance()
	if instance and instance.on_run_lost and instance:on_run_lost() then
		return
	end
	SPDRN._run_lost_shown = true
	SPDRN.show_run_lost_screen()
end
