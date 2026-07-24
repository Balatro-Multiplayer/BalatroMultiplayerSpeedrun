SPDRN.lobby = SPDRN.lobby or { buttons = {} }

function SPDRN.lobby.create_buttons()
	local L = SPDRN.lobby
	if L.buttons_initialized then
		return
	end
	local b = L.buttons

	b.start_game = MPAPI.disableable_button({
		id = 'spdrn_start_game',
		button = 'spdrn_start_game',
		colour = G.C.BLUE,
		minw = 3.65,
		minh = 1.55,
		label = { 'START GAME' },
		scale = 0.7,
		enabled = function()
			local lobby = L.ref
			if not lobby or not lobby.is_host then
				return false
			end
			local meta = lobby:get_metadata()
			local gm = meta.gamemode and MPAPI.GameModes[meta.gamemode]
			if not gm then
				return false
			end
			local players = lobby:get_players()
			if #players < gm:get_min_players('private') then
				return false
			end
			-- Multi-deck modes (e.g. White Stake Triple) need one deck per run chosen up front
			-- via the deck picker; block START until enough are saved. Naturally a no-op for
			-- every always_draft mode (Challenge/Seed Scout keep=1, All Deck keep=0) -- none of
			-- them show a deck picker at all (draft_panel instead), so `need > 1` is false or
			-- there's no meta.deck to gate on regardless.
			local need = SPDRN.required_deck_count(gm)
			if need > 1 then
				local have = type(meta.deck) == 'table' and #meta.deck or 1
				if have < need then
					return false
				end
			end
			for _, p in ipairs(players) do
				if p.id ~= lobby.player_id and not L.ready:is_ready(p.id) then
					return false
				end
			end
			return true
		end,
	})
	b.ready_args = {
		id = 'spdrn_ready',
		button = 'spdrn_toggle_ready',
		colour = G.C.GREEN,
		minw = 3.65,
		minh = 1.55,
		label = { localize('b_ready_cap') or 'READY' },
		scale = 0.7,
		col = true,
		enabled = true,
	}
	b.ready = MPAPI.disableable_button(b.ready_args)
	b.lobby_options = MPAPI.disableable_button({
		id = 'spdrn_lobby_options',
		button = 'spdrn_lobby_options',
		colour = G.C.ORANGE,
		minw = 2.65,
		minh = 1.35,
		label = localize('b_lobby_options_cap'),
		scale = 0.7,
		col = true,
		enabled = true,
	})
	b.view_code = MPAPI.disableable_button({
		id = 'spdrn_view_code',
		button = 'spdrn_view_code',
		colour = G.C.GREEN,
		minw = 3.65,
		minh = 0.6,
		label = { localize('b_view_code_cap') },
		scale = 0.45,
		enabled = true,
	})
	b.copy_code = MPAPI.disableable_button({
		id = 'spdrn_copy_code',
		button = 'spdrn_copy_code',
		colour = G.C.PURPLE,
		minw = 3.65,
		minh = 0.6,
		label = { localize('b_copy_code_cap') },
		scale = 0.45,
		enabled = true,
	})
	b.leave = MPAPI.disableable_button({
		id = 'spdrn_leave_lobby',
		button = 'spdrn_leave_lobby',
		colour = G.C.RED,
		minw = 3.65,
		minh = 1.55,
		label = localize('b_leave_lobby_cap'),
		scale = 0.7,
		col = true,
		enabled = true,
	})

	L.buttons_initialized = true
end
