-- §16.11: Enemy Location Indicator -- spliced directly into the native HUD's
-- round/score row (row_dollars_chips), the same placement and stake-icon /
-- colored-swatch styling PvP's own ui/game/enemy_location.lua uses, rather
-- than a separate floating box. Data comes from objects/matchmaking/location.lua.
-- Unlike PvP (single nemesis, shown as a blind-name/icon), this only ever
-- displays "Run N, Ante M" for the furthest-along OTHER player -- no name, no
-- round (round only matters internally for furthest_opponent_location's
-- tiebreak) -- since SPDRN tracks progress through a race, not a 1v1 duel.
-- Hovering still expands into every OTHER player's own current position by
-- name (SPDRN is N-player; PvP's equivalent hover just re-shows the same
-- single nemesis), each row built from the same [label][colored swatch]
-- component as the main indicator itself (location_component below), just
-- without the stake icon and with the player's name as the label. The popup
-- opens upward (major's top edge, not its bottom) since the indicator sits
-- at the very top of the screen -- expanding downward would just draw over
-- the blind-select/shop UI directly beneath it.
--
-- The HUD row can get rebuilt from scratch by the base game on state
-- transitions (entering the shop, blind-select, ...), wiping whatever's
-- spliced into it -- rather than hooking every such transition individually
-- (PvP's approach, in ui/game/game_state.lua/functions.lua), hud._tick just
-- re-injects whenever its marker id goes missing, since it already polls
-- every frame for the text update anyway.
SPDRN.location_hud = SPDRN.location_hud or {}
local hud = SPDRN.location_hud
hud.text = 'Waiting for opponents...'

local HUD_MARKER_ID = 'spdrn_enemy_location_box'
hud.MARKER_ID = HUD_MARKER_ID

-- Ante is always shown as a plain integer; round is tracked purely for
-- furthest_opponent_location's tiebreak, never displayed.
local function loc_text(loc)
	if not loc then
		return 'Unknown'
	end
	return 'Run ' .. tostring(loc.run or 1) .. ', Ante ' .. tostring(loc.ante)
end

-- The shared [icon?][label][colored swatch] layout: the main HUD indicator
-- passes a stake icon + the static "Enemy"/"Location" label; each hover-popup
-- row passes no icon and a player's name as the label instead, so the popup
-- rows are genuinely built from the same component, not a lookalike copy.
local function location_component(icon_node, label_nodes, swatch_node, swatch_minw)
	local nodes = {}
	if icon_node then
		nodes[#nodes + 1] = icon_node
	end
	nodes[#nodes + 1] = { n = G.UIT.C, config = { align = 'cm', minw = 1.2 }, nodes = label_nodes }
	nodes[#nodes + 1] = { n = G.UIT.C, config = { align = 'cm', minw = swatch_minw or 2.8, minh = 0.7, r = 0.1, colour = G.C.DYN_UI.BOSS_DARK }, nodes = { swatch_node } }
	return { n = G.UIT.C, config = { align = 'cm', padding = 0.1 }, nodes = nodes }
end

local function location_row_definition(name, position_text)
	local label_nodes = { { n = G.UIT.R, config = { align = 'cm' }, nodes = {
		{ n = G.UIT.T, config = { text = name, scale = 0.4, colour = G.C.UI.TEXT_LIGHT, shadow = true } },
	} } }
	local swatch = { n = G.UIT.T, config = { text = position_text, scale = 0.32, colour = G.C.WHITE, shadow = true } }
	return { n = G.UIT.R, config = { align = 'cm', padding = 0.05 }, nodes = { location_component(nil, label_nodes, swatch, 2.2) } }
end

-- Opens ABOVE major_node (align 'tm' with a negative y offset positions this
-- box's bottom edge just above major's top edge -- see Moveable:align_to_major
-- in the base game engine: without the 'i' suffix, 't' anchors via
-- `offset.y - self.T.h`, so the box's own height pushes it further up as it
-- grows, rather than major's height pushing it further down like the old
-- 'tmi' + major.T.h version did).
local function build_expanded_popup(major_node)
	local lobby = MPAPI.get_current_lobby()
	local rows = {}
	if lobby then
		for _, p in ipairs(lobby:get_players()) do
			if p.id ~= lobby.player_id then
				rows[#rows + 1] = location_row_definition(p.displayName or p.id, loc_text(SPDRN._locations[p.id]))
			end
		end
	end
	if #rows == 0 then
		rows[1] = { n = G.UIT.R, config = { align = 'cm' }, nodes = {
			{ n = G.UIT.T, config = { text = 'No other players yet', scale = 0.32, colour = G.C.UI.TEXT_INACTIVE } },
		} }
	end
	return UIBox({
		definition = { n = G.UIT.ROOT, config = { align = 'cm', padding = 0.1, colour = G.C.DYN_UI.BOSS_MAIN, r = 0.25, emboss = 0.05, minw = 3.5 }, nodes = rows },
		config = { align = 'tm', offset = { x = 0, y = -0.15 }, major = major_node },
	})
end

-- Hand-rolled hover detection (the same technique PvP's own enemy_location.lua
-- uses) rather than the base-game Card h_popup/Node.hover mechanism, which
-- requires the hovering element to be (or convincingly fake being) a Card --
-- this indicator is a plain UI node, not a Card.
local function install_hover(node)
	if node._spdrn_hover_installed then
		return
	end
	node._spdrn_hover_installed = true
	-- A plain G.UIT.C node has no hover/collision detection by default (unlike
	-- a button) -- both flags must be explicitly enabled, exactly as PvP's own
	-- equivalent (mp_setup_hover_enemy_location_display) does.
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

G.FUNCS.spdrn_install_location_hover = function(e)
	install_hover(e)
end

-- Vanilla's own row_dollars_chips content (functions/UI_definitions.lua's
-- contents.dollars_chips), rebuilt here so hide_enemy_location can restore it
-- exactly -- mirrors PvP's PVP.UI.round_score_definition().
local function round_score_definition()
	return {
		n = G.UIT.C,
		config = { align = 'cm', padding = 0.1 },
		nodes = {
			{ n = G.UIT.C, config = { align = 'cm', minw = 1.3 }, nodes = {
				{ n = G.UIT.R, config = { align = 'cm', padding = 0, maxw = 1.3 }, nodes = {
					{ n = G.UIT.T, config = { text = localize('k_round'), scale = 0.42, colour = G.C.UI.TEXT_LIGHT, shadow = true } },
				} },
				{ n = G.UIT.R, config = { align = 'cm', padding = 0, maxw = 1.3 }, nodes = {
					{ n = G.UIT.T, config = { text = localize('k_lower_score'), scale = 0.42, colour = G.C.UI.TEXT_LIGHT, shadow = true } },
				} },
			} },
			{ n = G.UIT.C, config = { align = 'cm', minw = 3.3, minh = 0.7, r = 0.1, colour = G.C.DYN_UI.BOSS_DARK }, nodes = {
				{ n = G.UIT.O, config = { w = 0.5, h = 0.5, object = get_stake_sprite(G.GAME.stake or 1, 0.5), hover = true, can_collide = false } },
				{ n = G.UIT.B, config = { w = 0.1, h = 0.1 } },
				{ n = G.UIT.T, config = { ref_table = G.GAME, ref_value = 'chips_text', lang = G.LANGUAGES['en-us'], scale = 0.85, colour = G.C.WHITE, id = 'chip_UI_count', func = 'chip_UI_set', shadow = true } },
			} },
		},
	}
end

local function enemy_location_definition()
	local icon = { n = G.UIT.O, config = { w = 0.5, h = 0.5, object = get_stake_sprite(G.GAME.stake or 1, 0.5), hover = true, can_collide = false } }
	local label_nodes = {
		{ n = G.UIT.R, config = { align = 'cm', padding = 0, maxw = 1.2 }, nodes = {
			{ n = G.UIT.T, config = { text = 'Enemy', scale = 0.42, colour = G.C.UI.TEXT_LIGHT, shadow = true } },
		} },
		{ n = G.UIT.R, config = { align = 'cm', padding = 0, maxw = 1.2 }, nodes = {
			{ n = G.UIT.T, config = { text = 'Location', scale = 0.42, colour = G.C.UI.TEXT_LIGHT, shadow = true } },
		} },
	}
	local swatch = { n = G.UIT.C, config = { align = 'cm', maxw = 2.6 }, nodes = {
		{ n = G.UIT.O, config = { object = DynaText({
			string = { { ref_table = hud, ref_value = 'text' } },
			colours = { G.C.WHITE },
			scale = 0.35,
			shadow = true,
			pop_in_rate = 9999999,
			silent = true,
		}) } },
	} }
	local def = location_component(icon, label_nodes, swatch, 2.8)
	def.config.id = HUD_MARKER_ID
	def.config.func = 'spdrn_install_location_hover'
	return def
end

local function show_enemy_location()
	if not G.HUD then
		return
	end
	local row = G.HUD:get_UIE_by_ID('row_dollars_chips')
	if row and row.children[1] then
		row.children[1]:remove()
		row.children[1] = nil
		G.HUD:add_child(enemy_location_definition(), row)
	end
end

local function hide_enemy_location()
	if not G.HUD then
		return
	end
	local row = G.HUD:get_UIE_by_ID('row_dollars_chips')
	if row and row.children[1] then
		row.children[1]:remove()
		row.children[1] = nil
		G.HUD:add_child(round_score_definition(), row)
	end
end

function hud._tick()
	local in_match = (G.STAGE == G.STAGES.RUN) and MPAPI.is_active(SPDRN.id) and MPAPI.get_current_lobby() and true or false
	-- Practice is solo -- nothing to compare against, so never shown there.
	if in_match and SPDRN.get_lobby_kind() == SPDRN.LobbyKind.PRACTICE then
		in_match = false
	end

	if not in_match then
		if hud._shown then
			pcall(hide_enemy_location)
			hud._shown = false
		end
		return
	end

	local best_id, best_loc = SPDRN.furthest_opponent_location()
	hud.text = best_id and loc_text(best_loc) or 'Waiting for opponents...'

	if not (G.HUD and G.HUD:get_UIE_by_ID(HUD_MARKER_ID)) then
		pcall(show_enemy_location)
	end
	hud._shown = true
end

-- Exposed for the end-screen and tests; not needed by hud._tick itself.
hud._remove_box = function()
	if hud._popup then
		pcall(function() hud._popup:remove() end)
		hud._popup = nil
	end
	if hud._shown then
		pcall(hide_enemy_location)
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
