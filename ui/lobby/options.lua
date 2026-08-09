G.FUNCS.spdrn_lobby_options = function()
	local lobby = SPDRN.lobby.ref
	local contents = {
		{ n = G.UIT.R, config = { align = 'cm', padding = 0.1 }, nodes = {
			{ n = G.UIT.T, config = { text = 'Lobby Options', scale = 0.5, colour = G.C.UI.TEXT_LIGHT, shadow = true } },
		} },
	}

	if lobby and lobby.is_host then
		local meta = lobby:get_metadata()
		local current_key = meta.gamemode
		local current_ruleset = meta.ruleset or SPDRN.Ruleset.ORDER
		contents[#contents + 1] = { n = G.UIT.R, config = { align = 'cm', padding = 0.05 }, nodes = {
			{ n = G.UIT.T, config = { text = 'Change Gamemode', scale = 0.4, colour = G.C.UI.TEXT_LIGHT } },
		} }
		contents[#contents + 1] = {
			n = G.UIT.R,
			config = { align = 'cm', padding = 0.05 },
			nodes = {
				UIBox_button({
					button = 'spdrn_change_white_stake_triple',
					label = { 'White Stake Triple' .. (current_key == SPDRN.Gamemode.WHITE_STAKE_TRIPLE and ' *' or '') },
					colour = current_key == SPDRN.Gamemode.WHITE_STAKE_TRIPLE and G.C.GREEN or G.C.GREY,
					minw = 4,
					minh = 0.6,
					scale = 0.45,
				}),
			},
		}
		contents[#contents + 1] = {
			n = G.UIT.R,
			config = { align = 'cm', padding = 0.05 },
			nodes = {
				UIBox_button({
					button = 'spdrn_change_gold_stake_single',
					label = { 'Gold Stake Single' .. (current_key == SPDRN.Gamemode.GOLD_STAKE_SINGLE and ' *' or '') },
					colour = current_key == SPDRN.Gamemode.GOLD_STAKE_SINGLE and G.C.GREEN or G.C.GREY,
					minw = 4,
					minh = 0.6,
					scale = 0.45,
				}),
			},
		}
		contents[#contents + 1] = {
			n = G.UIT.R,
			config = { align = 'cm', padding = 0.05 },
			nodes = {
				UIBox_button({
					button = 'spdrn_change_seed_scout',
					label = { 'Seed Scout' .. (current_key == SPDRN.Gamemode.SEED_SCOUT and ' *' or '') },
					colour = current_key == SPDRN.Gamemode.SEED_SCOUT and G.C.GREEN or G.C.GREY,
					minw = 4,
					minh = 0.6,
					scale = 0.45,
				}),
			},
		}
		contents[#contents + 1] = {
			n = G.UIT.R,
			config = { align = 'cm', padding = 0.05 },
			nodes = {
				UIBox_button({
					button = 'spdrn_change_challenge',
					label = { 'Challenge' .. (current_key == SPDRN.Gamemode.CHALLENGE and ' *' or '') },
					colour = current_key == SPDRN.Gamemode.CHALLENGE and G.C.GREEN or G.C.GREY,
					minw = 4,
					minh = 0.6,
					scale = 0.45,
				}),
			},
		}
		contents[#contents + 1] = {
			n = G.UIT.R,
			config = { align = 'cm', padding = 0.05 },
			nodes = {
				UIBox_button({
					button = 'spdrn_change_all_deck',
					label = { 'All Deck' .. (current_key == SPDRN.Gamemode.ALL_DECK and ' *' or '') },
					colour = current_key == SPDRN.Gamemode.ALL_DECK and G.C.GREEN or G.C.GREY,
					minw = 4,
					minh = 0.6,
					scale = 0.45,
				}),
			},
		}
		contents[#contents + 1] = {
			n = G.UIT.R,
			config = { align = 'cm', padding = 0.05 },
			nodes = {
				UIBox_button({
					button = 'spdrn_change_stake_climb',
					label = { 'Stake Climb' .. (current_key == SPDRN.Gamemode.STAKE_CLIMB and ' *' or '') },
					colour = current_key == SPDRN.Gamemode.STAKE_CLIMB and G.C.GREEN or G.C.GREY,
					minw = 4,
					minh = 0.6,
					scale = 0.45,
				}),
			},
		}
		contents[#contents + 1] = { n = G.UIT.R, config = { align = 'cm', padding = 0.05 }, nodes = {
			{ n = G.UIT.T, config = { text = 'Change Ruleset', scale = 0.4, colour = G.C.UI.TEXT_LIGHT } },
		} }
		contents[#contents + 1] = {
			n = G.UIT.R,
			config = { align = 'cm', padding = 0.05 },
			nodes = {
				UIBox_button({
					button = 'spdrn_set_ruleset_order',
					label = { 'The Order' .. (current_ruleset == SPDRN.Ruleset.ORDER and ' *' or '') },
					colour = current_ruleset == SPDRN.Ruleset.ORDER and G.C.GREEN or G.C.GREY,
					minw = 4,
					minh = 0.6,
					scale = 0.45,
				}),
			},
		}
		contents[#contents + 1] = {
			n = G.UIT.R,
			config = { align = 'cm', padding = 0.05 },
			nodes = {
				UIBox_button({
					button = 'spdrn_set_ruleset_vanilla',
					label = { 'Vanilla' .. (current_ruleset == SPDRN.Ruleset.VANILLA and ' *' or '') },
					colour = current_ruleset == SPDRN.Ruleset.VANILLA and G.C.GREEN or G.C.GREY,
					minw = 4,
					minh = 0.6,
					scale = 0.45,
				}),
			},
		}

			-- §16.7: duration cap is a per-gamemode option (MPAPI.GameMode's
			-- has_duration_cap) -- only show the toggle for a mode that has it at all.
			-- For a mode that does, private lobbies opt in explicitly (ranked/casual
			-- always have it on); off by default (existing lobbies' metadata has no
			-- duration_cap_opt_in key at all, which reads as false).
			local current_gm_def = current_key and MPAPI.GameModes[current_key]
			if current_gm_def and current_gm_def.has_duration_cap then
				local cap_on = meta.duration_cap_opt_in == true
				contents[#contents + 1] = { n = G.UIT.R, config = { align = 'cm', padding = 0.05 }, nodes = {
					{ n = G.UIT.T, config = { text = localize('k_duration_cap_cap') or 'Duration Cap', scale = 0.4, colour = G.C.UI.TEXT_LIGHT } },
				} }
				contents[#contents + 1] = {
					n = G.UIT.R,
					config = { align = 'cm', padding = 0.05 },
					nodes = {
						UIBox_button({
							button = 'spdrn_set_duration_cap_on',
							label = { 'On' .. (cap_on and ' *' or '') },
							colour = cap_on and G.C.GREEN or G.C.GREY,
							minw = 4,
							minh = 0.6,
							scale = 0.45,
						}),
					},
				}
				contents[#contents + 1] = {
					n = G.UIT.R,
					config = { align = 'cm', padding = 0.05 },
					nodes = {
						UIBox_button({
							button = 'spdrn_set_duration_cap_off',
							label = { 'Off' .. (not cap_on and ' *' or '') },
							colour = (not cap_on) and G.C.GREEN or G.C.GREY,
							minw = 4,
							minh = 0.6,
							scale = 0.45,
						}),
					},
				}
			end
	end

	G.FUNCS.overlay_menu({
		definition = create_UIBox_generic_options({ contents = contents }),
	})
end

local function change_gamemode(key)
	local lobby = SPDRN.lobby.ref
	if lobby and lobby.is_host then
		local meta = lobby:get_metadata()
		-- If the new mode needs a different number of decks, the saved deck(s) no longer fit;
		-- reset to the default so the host re-picks the right count via the deck button.
		local need = SPDRN.required_deck_count(MPAPI.GameModes[key])
		local have = type(meta.deck) == 'table' and #meta.deck or 1
		local deck = (have == need and meta.deck) or SPDRN.Deck.DEFAULT
		-- stake/challenge are preserved across a switch (harmless for modes that don't use
		-- them) so a host who already picked one doesn't lose it if they switch back to a mode
		-- that does -- stake falls back to White (1) since every mode's metadata already
		-- carries some value for it (see create_lobby_with_gamemode's universal default).
		lobby:set_metadata({ gamemode = key, deck = deck, ruleset = meta.ruleset or SPDRN.Ruleset.ORDER, stake = meta.stake or 1, challenge = meta.challenge, duration_cap_opt_in = meta.duration_cap_opt_in })
	end
	G.FUNCS.exit_overlay_menu()
end

G.FUNCS.spdrn_change_white_stake_triple = function()
	change_gamemode(SPDRN.Gamemode.WHITE_STAKE_TRIPLE)
end

G.FUNCS.spdrn_change_gold_stake_single = function()
	change_gamemode(SPDRN.Gamemode.GOLD_STAKE_SINGLE)
end

G.FUNCS.spdrn_change_seed_scout = function()
	change_gamemode(SPDRN.Gamemode.SEED_SCOUT)
end

G.FUNCS.spdrn_change_challenge = function()
	change_gamemode(SPDRN.Gamemode.CHALLENGE)
end

G.FUNCS.spdrn_change_all_deck = function()
	change_gamemode(SPDRN.Gamemode.ALL_DECK)
end

G.FUNCS.spdrn_change_stake_climb = function()
	change_gamemode(SPDRN.Gamemode.STAKE_CLIMB)
end

local function change_ruleset(key)
	local lobby = SPDRN.lobby.ref
	if lobby and lobby.is_host then
		local meta = lobby:get_metadata()
		lobby:set_metadata({ gamemode = meta.gamemode, deck = meta.deck or SPDRN.Deck.DEFAULT, ruleset = key, stake = meta.stake, challenge = meta.challenge, duration_cap_opt_in = meta.duration_cap_opt_in })
	end
	G.FUNCS.exit_overlay_menu()
end

G.FUNCS.spdrn_set_ruleset_order = function()
	change_ruleset(SPDRN.Ruleset.ORDER)
end

G.FUNCS.spdrn_set_ruleset_vanilla = function()
	change_ruleset(SPDRN.Ruleset.VANILLA)
end

-- §16.7: private-lobby opt-in for the same duration cap ranked/casual matches
-- always have (SPDRN._check_match_duration reads this metadata field directly,
-- polled live, so no restart is needed for a toggle mid-lobby to take effect).
local function set_duration_cap_opt_in(value)
	local lobby = SPDRN.lobby.ref
	if lobby and lobby.is_host then
		local meta = lobby:get_metadata()
		lobby:set_metadata({ gamemode = meta.gamemode, deck = meta.deck or SPDRN.Deck.DEFAULT, ruleset = meta.ruleset or SPDRN.Ruleset.ORDER, stake = meta.stake, challenge = meta.challenge, duration_cap_opt_in = value })
	end
	G.FUNCS.exit_overlay_menu()
end

G.FUNCS.spdrn_set_duration_cap_on = function()
	set_duration_cap_opt_in(true)
end

G.FUNCS.spdrn_set_duration_cap_off = function()
	set_duration_cap_opt_in(false)
end
