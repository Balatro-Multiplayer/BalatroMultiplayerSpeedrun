-- §16.10: end-of-run roster -- every player's outcome side by side (deck,
-- run time, and a per-player joker drilldown), not just the local player's
-- own stats. Reachable from the win/lose/timeout screens via a "Roster"
-- button (SPDRN.end_screen_buttons).
--
-- SPDRN._collected_results (objects/matchmaking/result.lua) is populated
-- asynchronously -- a player who hasn't finished yet simply has no entry.
-- This screen is a reactive MPAPI.ui_element (the same pattern
-- SPDRN.lobby.refresh_mm_status uses for the live ban-pick draft view) so it
-- updates in place as stragglers' own spdrn_player_result broadcasts arrive,
-- rather than needing to be manually reopened.

local _roster_el = nil

local function format_time(ms)
	if not ms then
		return '--'
	end
	return SPDRN.timer and SPDRN.timer.format and SPDRN.timer.format(ms / 1000) or string.format('%.1fs', ms / 1000)
end

local function roster_row(player, result)
	local name = player.displayName or player.id
	local deck_label = (result and result.deck_back and SPDRN.deck_label(result.deck_back)) or '--'
	local status = result and (format_time(result.best_run_time_ms) .. ' -- Ante ' .. tostring(result.furthest_ante) .. '.' .. tostring(result.furthest_round)) or 'Still playing...'
	local joker_count = result and result.jokers and #result.jokers or 0

	local nodes = {
		{ n = G.UIT.C, config = { align = 'cm', minw = 3, padding = 0.05 }, nodes = {
			{ n = G.UIT.T, config = { text = name, scale = 0.4, colour = G.C.UI.TEXT_LIGHT, shadow = true } },
		} },
		{ n = G.UIT.C, config = { align = 'cm', minw = 2.2, padding = 0.05 }, nodes = {
			{ n = G.UIT.T, config = { text = deck_label, scale = 0.32, colour = G.C.UI.TEXT_INACTIVE } },
		} },
		{ n = G.UIT.C, config = { align = 'cm', minw = 3, padding = 0.05 }, nodes = {
			{ n = G.UIT.T, config = { text = status, scale = 0.32, colour = G.C.UI.TEXT_INACTIVE } },
		} },
	}
	if joker_count > 0 then
		nodes[#nodes + 1] = { n = G.UIT.C, config = { align = 'cm', padding = 0.05 }, nodes = {
			UIBox_button({
				button = 'spdrn_view_roster_jokers',
				ref_table = { player_id = player.id },
				label = { 'Jokers (' .. joker_count .. ')' },
				colour = G.C.PURPLE,
				minw = 1.8,
				minh = 0.5,
				scale = 0.3,
			}),
		} }
	end

	return { n = G.UIT.R, config = { align = 'cm', padding = 0.06, colour = G.C.BLACK, emboss = 0.03, r = 0.08 }, nodes = nodes }
end

local function build_roster_contents()
	local lobby = MPAPI.get_current_lobby()
	local rows = {
		{ n = G.UIT.R, config = { align = 'cm', padding = 0.1 }, nodes = {
			{ n = G.UIT.T, config = { text = 'Roster', scale = 0.5, colour = G.C.UI.TEXT_LIGHT, shadow = true } },
		} },
	}
	if lobby then
		for _, p in ipairs(lobby:get_players()) do
			rows[#rows + 1] = roster_row(p, SPDRN._collected_results and SPDRN._collected_results[p.id])
		end
	end
	return rows
end

function SPDRN.show_roster_overlay()
	_roster_el = _roster_el or MPAPI.ui_element(build_roster_contents)
	G.FUNCS.overlay_menu({
		definition = create_UIBox_generic_options({ contents = { _roster_el.node } }),
	})
end

-- Called by objects/actions/player_result.lua whenever a new result arrives, so
-- an already-open roster reflects it without needing to be closed and reopened.
function SPDRN.refresh_roster()
	if _roster_el then
		_roster_el:update()
	end
end

G.FUNCS.spdrn_open_roster = function()
	SPDRN.show_roster_overlay()
end

-- Read-only display of one player's captured joker snapshot (key/edition/
-- eternal/perishable -- see objects/matchmaking/progress.lua's capture_local_jokers).
-- Builds ordinary display Cards, the same technique MPAPI.BanPick's own deck
-- tiles use (api/ban_pick.lua's deck_tile) -- these are never clickable/playable.
local function build_joker_area(jokers)
	local area = CardArea(0, 0, math.max(#jokers, 1) * 1.1, 1.6 * G.CARD_H / G.CARD_W, { card_limit = math.max(#jokers, 1), type = 'joker' })
	for _, j in ipairs(jokers or {}) do
		local center = G.P_CENTERS[j.key]
		if center then
			local card = Card(area.T.x, area.T.y, G.CARD_W, G.CARD_H, nil, center, { bypass_discovery_center = true })
			if j.edition then
				card:set_edition(j.edition, true, true)
			end
			card.ability.eternal = j.eternal or false
			card.ability.perishable = j.perishable or false
			area:emplace(card)
		end
	end
	return area
end

G.FUNCS.spdrn_view_roster_jokers = function(e)
	local player_id = e.config.ref_table.player_id
	local result = SPDRN._collected_results and SPDRN._collected_results[player_id]
	local jokers = (result and result.jokers) or {}

	local area = build_joker_area(jokers)
	G.FUNCS.overlay_menu({
		definition = create_UIBox_generic_options({ contents = {
			{ n = G.UIT.R, config = { align = 'cm', padding = 0.1 }, nodes = {
				{ n = G.UIT.T, config = { text = 'Jokers', scale = 0.5, colour = G.C.UI.TEXT_LIGHT, shadow = true } },
			} },
			{ n = G.UIT.R, config = { align = 'cm', padding = 0.1 }, nodes = {
				{ n = G.UIT.O, config = { object = area } },
			} },
		} }),
	})
end
