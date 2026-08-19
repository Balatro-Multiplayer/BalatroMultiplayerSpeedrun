-- Card-info provider for MPAPI's Lobby Info overlay (see
-- BalatroMultiplayerAPI/api/card_info_providers.lua): ranked lobbies show
-- Elo, everything else shows this player's own current run/ante via
-- SPDRN._locations (objects/matchmaking/location.lua) -- nil pre-match/until
-- they've broadcast at least once, same graceful "Waiting for opponents..."
-- fallback ui/enemy_location.lua's own hover popup already uses.
--
-- Elo is cached per (gamemode, player) since MPAPI.matchmaking.get_rating is
-- an async network call and hover callbacks must return synchronously: the
-- first hover with no cache entry fires the lookup in the background and
-- shows a placeholder immediately, a later hover shows the resolved value.
SPDRN._rating_cache = SPDRN._rating_cache or {}

local function location_text(loc)
	if not loc then
		return 'Waiting for opponents...'
	end
	return 'Run ' .. tostring(loc.run or 1) .. ', Ante ' .. tostring(loc.ante)
end

local function text_row(text)
	return { n = G.UIT.R, config = { align = 'cm', padding = 0.03 }, nodes = {
		{ n = G.UIT.T, config = { text = text, scale = 0.35, colour = G.C.UI.TEXT_DARK } },
	} }
end

local function elo_row(lobby, player_data)
	local meta = lobby:get_metadata() or {}
	local gamemode = meta.gamemode
	if not gamemode then
		return text_row('Elo: N/A')
	end

	local cache_key = gamemode .. ':' .. player_data.id
	local cached = SPDRN._rating_cache[cache_key]

	if cached == nil then
		SPDRN._rating_cache[cache_key] = false -- in-flight marker, avoids re-firing on every hover
		MPAPI.matchmaking.get_rating(SPDRN.id, gamemode, nil, player_data.id, function(err, data)
			if err then
				SPDRN._rating_cache[cache_key] = nil -- allow a retry on the next hover
				return
			end
			SPDRN._rating_cache[cache_key] = data or { rating = nil }
		end)
		return text_row('Elo: ...')
	end

	if cached == false then
		return text_row('Elo: ...')
	end

	return text_row('Elo: ' .. tostring(cached.rating or 'Placement'))
end

MPAPI.register_card_info_provider(SPDRN.id, function(lobby, player_data)
	local meta = lobby:get_metadata() or {}
	if meta.kind == SPDRN.LobbyKind.RANKED then
		return { elo_row(lobby, player_data) }
	end
	return { text_row(location_text(SPDRN._locations[player_data.id])) }
end)
