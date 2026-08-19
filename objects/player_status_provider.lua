-- Player-status provider for MPAPI's lobby card grid (see
-- BalatroMultiplayerAPI/api/player_status_providers.lua): SPDRN is a
-- race/placement format, not attrition, so there's no "lives" concept --
-- once a player has reported a result (win, loss, or forfeit all funnel
-- through the same report_match_result broadcast, see
-- objects/matchmaking/result.lua), they're done with the current run and
-- render debuffed. objects/actions/player_result.lua's on_receive collects
-- every player's result identically on every client (not host-only), so
-- this is accurate everywhere, not just for the host.
MPAPI.register_player_status_provider(SPDRN.id, function(lobby, player_data)
	return SPDRN._collected_results[player_data.id] ~= nil
end)
