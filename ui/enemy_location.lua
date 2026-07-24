-- §16.11: Enemy Location Indicator -- a small persistent HUD element during a
-- match showing the furthest-along opponent's current ante/round (data comes
-- from objects/matchmaking/location.lua). Hovering expands it into every
-- player's current location at once. Modeled structurally on SPDRN's own
-- speedrun-clock HUD (ui/timer/lifecycle.lua/appearance.lua): a standalone
-- UIBox, `major = G`, absolute world coordinates set directly on T.x/y and
-- VT.x/y -- proven (by that existing feature) to render correctly throughout
-- G.STAGE == RUN, unlike splicing into an existing HUD row's child slot the
-- way PvP's own equivalent does (which only works because PvP's row layout
-- already reserves a slot for it).
SPDRN.location_hud = SPDRN.location_hud or {}
local hud = SPDRN.location_hud
hud.text = 'Waiting for opponents...'

local function player_display_name(lobby, player_id)
	for _, p in ipairs(lobby:get_players()) do
		if p.id == player_id then
			return p.displayName or p.id
		end
	end
	return player_id
end

local function loc_text(loc)
	if not loc then
		return 'Unknown'
	end
	return 'Ante ' .. tostring(loc.ante) .. '.' .. tostring(loc.round)
end

local function build_expanded_popup(major_node)
	local lobby = MPAPI.get_current_lobby()
	local rows = {}
	if lobby then
		for _, p in ipairs(lobby:get_players()) do
			if p.id ~= lobby.player_id then
				rows[#rows + 1] = { n = G.UIT.R, config = { align = 'cm', padding = 0.05 }, nodes = {
					{ n = G.UIT.T, config = { text = (p.displayName or p.id) .. ':  ' .. loc_text(SPDRN._locations[p.id]), scale = 0.32, colour = G.C.UI.TEXT_LIGHT } },
				} }
			end
		end
	end
	if #rows == 0 then
		rows[1] = { n = G.UIT.R, config = { align = 'cm' }, nodes = {
			{ n = G.UIT.T, config = { text = 'No other players yet', scale = 0.32, colour = G.C.UI.TEXT_INACTIVE } },
		} }
	end
	return UIBox({
		definition = { n = G.UIT.ROOT, config = { align = 'cm', padding = 0.1, colour = G.C.BLACK, r = 0.1, emboss = 0.05, minw = 3.5 }, nodes = rows },
		config = { align = 'tmi', offset = { x = 0, y = (major_node.T and major_node.T.h or 0.5) + 0.15 }, major = major_node },
	})
end

-- Hand-rolled hover detection (the same technique PvP's own enemy_location.lua
-- uses) rather than the base-game Card h_popup/Node.hover mechanism, which
-- requires the hovering element to be (or convincingly fake being) a Card --
-- this indicator is a plain text node, not a Card.
local function install_hover(node)
	if node._spdrn_hover_installed then
		return
	end
	node._spdrn_hover_installed = true
	-- A plain G.UIT.ROOT/C node has no hover/collision detection by default
	-- (unlike a button) -- both flags must be explicitly enabled, exactly as
	-- PvP's own equivalent (mp_setup_hover_enemy_location_display) does.
	node.states.collide.can = true
	node.states.hover.can = true
	local orig_hover = node.hover
	local orig_stop_hover = node.stop_hover
	local orig_remove = node.remove
	node.hover = function(self)
		if orig_hover then
			orig_hover(self)
		end
		if not hud._popup then
			local ok, popup = pcall(build_expanded_popup, self)
			if ok then
				hud._popup = popup
			end
		end
	end
	node.stop_hover = function(self)
		if orig_stop_hover then
			orig_stop_hover(self)
		end
		if hud._popup then
			pcall(function() hud._popup:remove() end)
			hud._popup = nil
		end
	end
	node.remove = function(self)
		if hud._popup then
			pcall(function() hud._popup:remove() end)
			hud._popup = nil
		end
		return orig_remove(self)
	end
end

local function build_indicator_definition()
	return {
		n = G.UIT.ROOT,
		config = { align = 'cm', padding = 0.06, colour = G.C.BLACK, r = 0.1, emboss = 0.05, func = 'spdrn_install_location_hover' },
		nodes = {
			{ n = G.UIT.O, config = { align = 'cm', object = DynaText({
				string = { { ref_table = hud, ref_value = 'text' } },
				colours = { G.C.UI.TEXT_LIGHT },
				scale = 0.35,
				shadow = true,
				pop_in_rate = 9999999,
				silent = true,
			}) } },
		},
	}
end

G.FUNCS.spdrn_install_location_hover = function(e)
	install_hover(e)
end

hud._remove_box = function()
	if hud._popup then
		pcall(function() hud._popup:remove() end)
		hud._popup = nil
	end
	if hud._box then
		pcall(function() hud._box:remove() end)
		hud._box = nil
	end
end

hud._build_box = function()
	local def = build_indicator_definition()
	local box = UIBox({
		definition = def,
		config = { align = '', offset = { x = 0, y = 0 }, major = G, bond = 'Weak' },
	})
	local rw = (G.ROOM and G.ROOM.T and G.ROOM.T.w) or 0
	local x = rw / 2 - (box.T.w or 0) / 2
	local y = 8.6
	box.T.x = x
	box.T.y = y
	box.VT.x = x
	box.VT.y = y
	return box
end

function hud._tick()
	local in_match = (G.STAGE == G.STAGES.RUN) and MPAPI.is_active(SPDRN.id) and MPAPI.get_current_lobby() and true or false
	-- Practice is solo -- nothing to compare against, so never shown there.
	if in_match and SPDRN.get_lobby_kind() == SPDRN.LobbyKind.PRACTICE then
		in_match = false
	end

	if not in_match then
		if hud._box then
			hud._remove_box()
		end
		return
	end

	local best_id, best_loc = SPDRN.furthest_opponent_location()
	if best_id then
		local lobby = MPAPI.get_current_lobby()
		hud.text = player_display_name(lobby, best_id) .. ':  ' .. loc_text(best_loc)
	else
		hud.text = 'Waiting for opponents...'
	end

	if hud._box and hud._box.REMOVED then
		hud._box = nil
	end
	if not hud._box then
		local ok, box = pcall(hud._build_box)
		if ok then
			hud._box = box
		end
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
