-- §16.11: Enemy Location Indicator -- thin SPDRN-specific wrapper over
-- MPAPI.enemy_location (see BalatroMultiplayerAPI/ui/enemy_location.lua for
-- the shared swap/hover mechanics and the id contract that keeps this
-- crash-safe -- an earlier from-scratch version here got that contract
-- wrong and crashed functions/common_events.lua's ease_chips). Unlike PvP
-- (single nemesis, shown as a blind-name/icon), this only ever displays
-- "Run N, Ante M" for the furthest-along OTHER player -- no name, no round
-- (round only matters internally for furthest_opponent_location's tiebreak)
-- -- since SPDRN tracks progress through a race, not a 1v1 duel. Hovering
-- expands into every OTHER player's own current position by name (SPDRN is
-- N-player; PvP's equivalent hover just re-shows the same single nemesis),
-- and -- like PvP -- this works whether the main indicator is currently
-- shown (blind-select/shop) or the vanilla chip counter is (mid-blind):
-- MPAPI.enemy_location wires hover onto both states identically.
SPDRN.location_hud = SPDRN.location_hud or {}
local hud = SPDRN.location_hud
hud.text = 'Waiting for opponents...'

-- Ante is always shown as a plain integer; round is tracked purely for
-- furthest_opponent_location's tiebreak, never displayed.
local function loc_text(loc)
	if not loc then
		return 'Unknown'
	end
	return 'Run ' .. tostring(loc.run or 1) .. ', Ante ' .. tostring(loc.ante)
end

local function value_nodes(chip_ui_id)
	return {
		{ n = G.UIT.O, config = { id = chip_ui_id, object = DynaText({
			string = { { ref_table = hud, ref_value = 'text' } },
			colours = { G.C.WHITE },
			scale = 0.35,
			shadow = true,
			pop_in_rate = 9999999,
			silent = true,
		}) } },
	}
end

local function popup_rows()
	local lobby = MPAPI.get_current_lobby()
	local rows = {}
	if lobby then
		for _, p in ipairs(lobby:get_players()) do
			if p.id ~= lobby.player_id then
				rows[#rows + 1] = MPAPI.enemy_location_row(
					nil,
					{ { n = G.UIT.R, config = { align = 'cm' }, nodes = {
						{ n = G.UIT.T, config = { text = p.displayName or p.id, scale = 0.4, colour = G.C.UI.TEXT_LIGHT, shadow = true } },
					} } },
					{ { n = G.UIT.T, config = { text = loc_text(SPDRN._locations[p.id]), scale = 0.32, colour = G.C.WHITE, shadow = true } } },
					2.2
				)
			end
		end
	end
	if #rows == 0 then
		rows[1] = { n = G.UIT.R, config = { align = 'cm' }, nodes = {
			{ n = G.UIT.T, config = { text = 'No other players yet', scale = 0.32, colour = G.C.UI.TEXT_INACTIVE } },
		} }
	end
	return rows
end

hud._ctrl = MPAPI.enemy_location({
	label = { 'Enemy', 'Location' },
	build_value_nodes = value_nodes,
	build_popup_rows = popup_rows,
	swatch_minw = 2.8,
})

-- Shown only at blind-select/shop (mirroring PvP: the vanilla chip counter
-- is what's live during a blind, since that's the node base-game chip
-- animations actually target) -- but hovering shows the same roster popup
-- either way, so the info is always one hover away.
local function in_showable_state()
	return G.STATE == G.STATES.BLIND_SELECT or G.STATE == G.STATES.SHOP
end

function hud._tick()
	local in_match = (G.STAGE == G.STAGES.RUN) and MPAPI.is_active(SPDRN.id) and MPAPI.get_current_lobby() and true or false
	-- Practice is solo -- nothing to compare against, so never shown there.
	if in_match and SPDRN.get_lobby_kind() == SPDRN.LobbyKind.PRACTICE then
		in_match = false
	end

	local should_show = in_match and in_showable_state()

	if not should_show then
		if hud._shown then
			pcall(hud._ctrl.hide)
			hud._shown = false
		end
		return
	end

	local best_id, best_loc = SPDRN.furthest_opponent_location()
	hud.text = best_id and loc_text(best_loc) or 'Waiting for opponents...'

	if not hud._shown then
		pcall(hud._ctrl.show)
		hud._shown = true
	end
end

-- Exposed for the end-screen and tests; not needed by hud._tick itself.
hud._remove_box = function()
	if hud._ctrl.popup then
		pcall(function() hud._ctrl.popup:remove() end)
		hud._ctrl.popup = nil
	end
	if hud._shown then
		pcall(hud._ctrl.hide)
		hud._shown = false
	end
end

if not SPDRN._location_hud_update_hooked then
	SPDRN._location_hud_update_hooked = true
	local _location_hud_update_ref = Game.update
	function Game:update(dt)
		_location_hud_update_ref(self, dt)
		pcall(hud._tick)
	end
end
