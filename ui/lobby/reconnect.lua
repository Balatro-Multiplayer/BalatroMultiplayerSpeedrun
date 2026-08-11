-- Crash-relaunch reconnect: called once the lobby object itself has already
-- been recreated (MPAPI._internal.create_reconnected_lobby, driven by
-- ui/reconnect_prompt.lua) and there's no active RLOG match run to hand off
-- to instead (that's the OTHER branch of that file's Reconnect handler --
-- this one only ever runs pre-match: waiting room or mid-ban-pick-draft).
MPAPI.register_lobby_reconnect(SPDRN.id, function(lobby)
	-- Mirrors ui/main_menu/join.lua / create_lobby.lua / practice.lua's own
	-- SPDRN._lobby_kind assignment -- every other entry path sets this from
	-- the button the player actually clicked (Create Private / Find Game /
	-- Practice); a reconnect has no such click to read, so it's derived from
	-- the lobby's own server-reported type instead. MPAPI.LobbyType has no
	-- CASUAL value of its own (only PUBLIC/PRIVATE/RANKED) -- SPDRN's own
	-- "casual" matchmaking queue is what a plain PUBLIC lobby type means here.
	if lobby.type == MPAPI.LobbyType.RANKED then
		SPDRN._lobby_kind = SPDRN.LobbyKind.RANKED
	elseif lobby.type == MPAPI.LobbyType.PUBLIC then
		SPDRN._lobby_kind = SPDRN.LobbyKind.CASUAL
	else
		SPDRN._lobby_kind = SPDRN.LobbyKind.PRIVATE
	end

	SPDRN.setup_lobby_events(lobby)

	-- Resume a ban-pick draft that was already in progress, if any. Restore
	-- lobby._ban_pick from the host's own metadata mirror first (see
	-- MPAPI.BanPick.broadcast_state's comment) -- a reconnecting player's own
	-- lobby object never had this field populated any other way, since it's
	-- assembled fresh from context.reconnected_lobby (api/lobby/public.lua),
	-- which carries metadata but has no _ban_pick field of its own.
	local meta = lobby:get_metadata() or {}
	if not lobby._ban_pick and meta._mp_ban_pick_state then
		lobby._ban_pick = meta._mp_ban_pick_state
	end
	if lobby._ban_pick and not lobby._ban_pick.complete then
		local gm_def = meta.gamemode and MPAPI.GameModes[meta.gamemode]
		if gm_def and gm_def.ban_pick then
			MPAPI.BanPick.resume(
				lobby,
				SPDRN._ban_pick_config_for(gm_def),
				SPDRN._ban_pick_on_complete_for(gm_def, meta, lobby, meta._mp_pending_seed)
			)
		end
	end
end)
