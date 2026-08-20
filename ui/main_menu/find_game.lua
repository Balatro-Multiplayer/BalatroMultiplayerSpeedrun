-- Live queue/in-game counts shown on each button below, fetched via
-- MPAPI.matchmaking.create_queue_counts_poller (a generic MPAPI helper, not
-- SPDRN-specific -- any mod's own menu can use it the same way). Polled
-- while this menu is open, stopped when it closes (see the
-- G.FUNCS.exit_overlay_menu wrap at the bottom of this file).
local POLL_INTERVAL_SECONDS = 5

-- game_mode string -> ui_element for its whole button (title + live counts
-- together, see build_stat_button below). Repopulated (overwritten in
-- place, same 4 keys) every time the menu opens; entries from a previous,
-- now-closed menu are never read again once the poller that would refresh
-- them has been stopped.
local _count_els = {}

-- nil until the first poll response lands this menu-session; then the
-- `gameModes` table from the server (game_mode -> {queued, inMatch}, a
-- missing key means 0/0). Reset to nil each time the menu (re)opens so a
-- reopen never briefly shows the previous session's numbers.
local _latest_counts = nil
local _last_fetch_failed = false

local function build_count_lines(game_mode)
	if not _latest_counts then
		return { '...' } -- before the first response lands
	end
	if _last_fetch_failed then
		return { '\226\128\148' } -- em dash: don't show stale numbers after a failed fetch
	end
	local c = _latest_counts[game_mode] or { queued = 0, inMatch = 0 }
	return { c.queued .. ' queued', c.inMatch .. ' in game' }
end

-- Vanilla UIBox_button (functions/UI_definitions.lua) gives every line in
-- `label` the same text_colour -- no per-line override -- so getting the
-- live-count lines into a dimmer colour than the button's own title,
-- inside the same clickable box, means building the button by hand here
-- rather than through MPAPI.disableable_button. Mirrors UIBox_button's
-- shape closely enough to behave like a real button (hover, click, the
-- same rounded coloured box); enabled/disabled just toggles the button tag
-- and dims the title the same way MPAPI's own disabled-button styling does.
local function build_stat_button(button_id, title_lines, game_mode, colour, enabled)
	local title_colour = enabled and G.C.UI.TEXT_LIGHT or G.C.UI.TEXT_INACTIVE
	local bg_colour = enabled and colour or G.C.UI.BACKGROUND_INACTIVE
	local nodes = {}
	for _, line in ipairs(title_lines) do
		nodes[#nodes + 1] = { n = G.UIT.R, config = { align = 'cm', padding = 0, minw = 2.3, maxw = 2.3 }, nodes = {
			{ n = G.UIT.T, config = { text = line, scale = 0.4, colour = title_colour, shadow = enabled } },
		} }
	end
	nodes[#nodes + 1] = { n = G.UIT.R, config = { minh = 0.1 }, nodes = {} } -- spacing before the live counts
	for _, line in ipairs(build_count_lines(game_mode)) do
		nodes[#nodes + 1] = { n = G.UIT.R, config = { align = 'cm', padding = 0, minw = 2.3, maxw = 2.3 }, nodes = {
			-- Always the "disabled" grey (G.C.UI.TEXT_INACTIVE, same colour
			-- MPAPI's own disabled-button styling uses), not tied to `enabled` --
			-- this is secondary/metadata text, not the button's own label.
			{ n = G.UIT.T, config = { text = line, scale = 0.3, colour = G.C.UI.TEXT_INACTIVE, shadow = false } },
		} }
	end
	return {
		n = G.UIT.C,
		config = { align = 'cm' },
		nodes = { {
			n = G.UIT.C,
			config = {
				align = 'cm', padding = 0.05, r = 0.1, hover = enabled, colour = bg_colour,
				button = enabled and button_id or nil, shadow = true, minh = 1.6,
			},
			nodes = nodes,
		} },
	}
end

local function refresh_button_counts()
	for _, el in pairs(_count_els) do
		el:update()
	end
end

-- One matchmaking section (Ranked or Casual): the two gamemode buttons stacked, with the
-- section label on a readable horizontal row beneath them. `enabled = false` greys the
-- buttons out (see build_stat_button above) instead of removing them, so the Ranked
-- section stays visible but non-interactive (see SPDRN._ranked_queue_available() below).
-- white_gm/gold_gm are the exact game_mode strings the server's queue-counts response
-- uses (i.e. already carrying the "ranked:" prefix for a ranked section) -- see
-- objects/matchmaking/queue.lua's own game_mode construction, which this must match.
local function queue_section(label, white_gm, white_btn, gold_gm, gold_btn, enabled)
	local white_el = MPAPI.ui_element(function() return { nodes = { build_stat_button(white_btn, { 'White Stake', 'Triple' }, white_gm, G.C.ETERNAL, enabled) } } end)
	local gold_el = MPAPI.ui_element(function() return { nodes = { build_stat_button(gold_btn, { 'Gold Stake', 'Single' }, gold_gm, G.C.GOLD, enabled) } } end)

	_count_els[white_gm] = white_el
	_count_els[gold_gm] = gold_el

	return {
		n = G.UIT.C,
		config = { align = 'cm', padding = 0.1, r = 0.2, colour = G.C.BLACK },
		nodes = {
			{ n = G.UIT.R, config = { align = 'cm', padding = 0.05 }, nodes = {
				white_el.node,
			} },
			{ n = G.UIT.R, config = { align = 'cm', padding = 0.05 }, nodes = {
				gold_el.node,
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
	_latest_counts = nil
	_last_fetch_failed = false
	_count_els = {}

	local def = create_UIBox_generic_options({
		contents = {
			{ n = G.UIT.R, config = { align = 'cm', padding = 0.1 }, nodes = {
				{ n = G.UIT.T, config = { text = 'Find Game', scale = 0.6, colour = G.C.UI.TEXT_LIGHT, shadow = true } },
			} },
			{
				n = G.UIT.R,
				config = { align = 'cm', padding = 0.1 },
				nodes = {
					{ n = G.UIT.C, config = { align = 'cm', padding = 0.1 }, nodes = {
						queue_section(localize('k_ranked_cap'), SPDRN.LobbyKind.RANKED_PREFIX .. SPDRN.Gamemode.WHITE_STAKE_TRIPLE, 'spdrn_queue_ranked_white', SPDRN.LobbyKind.RANKED_PREFIX .. SPDRN.Gamemode.GOLD_STAKE_SINGLE, 'spdrn_queue_ranked_gold', SPDRN._ranked_queue_available()),
					} },
					{ n = G.UIT.C, config = { align = 'cm', padding = 0.1 }, nodes = {
						queue_section(localize('k_casual_cap'), SPDRN.Gamemode.WHITE_STAKE_TRIPLE, 'spdrn_queue_casual_white', SPDRN.Gamemode.GOLD_STAKE_SINGLE, 'spdrn_queue_casual_gold', true),
					} },
				},
			},
		},
	})
	def.config.id = 'spdrn_find_game_root'

	G.FUNCS.overlay_menu({ definition = def })

	SPDRN._find_game_poller = MPAPI.matchmaking.create_queue_counts_poller(SPDRN.id, POLL_INTERVAL_SECONDS, function(err, game_modes)
		_latest_counts = game_modes or {}
		_last_fetch_failed = err ~= nil
		refresh_button_counts()
	end)
	SPDRN._find_game_poller.start()
end

-- Stops the live-counts poller when the Find Game menu closes, whichever way
-- that happens (Escape/X, or one of the queue buttons below calling
-- exit_overlay_menu() before it queues) -- captured before calling through
-- since the wrapped ref clears G.OVERLAY_MENU as part of closing.
local find_game_exit_overlay_menu_ref = G.FUNCS.exit_overlay_menu
G.FUNCS.exit_overlay_menu = function(...)
	local closing_find_game = G.OVERLAY_MENU
		and G.OVERLAY_MENU ~= true
		and G.OVERLAY_MENU:get_UIE_by_ID('spdrn_find_game_root') ~= nil
	if closing_find_game and SPDRN._find_game_poller then
		SPDRN._find_game_poller.stop()
		SPDRN._find_game_poller = nil
	end
	return find_game_exit_overlay_menu_ref(...)
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
