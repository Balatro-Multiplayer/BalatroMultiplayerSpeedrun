-- "My Replays" browser -- ported from BalatroMultiplayerPvP's
-- ui/replay/replay_browser.lua. Lists MPAPI.replay.list_mine, launches a
-- full replay of the picked run via SPDRN._start_playback
-- (playback_launch.lua) + MPAPI.playback (playback_handlers.lua's opcode
-- handlers drive it). v1 scope: no pagination, most-recent-first, capped to
-- the first page list_mine returns -- same scope decision as PvP's browser.

local function format_run_label(run)
	local date = tostring(run.startedAt or ''):match('^(%d%d%d%d%-%d%d%-%d%d)') or '?'
	return date .. '  ' .. tostring(run.lobbyCode or '??????') .. '  [' .. tostring(run.status or '?') .. ']'
end

-- Finds this player's own bootstrap data in an already-built timeline
-- (MPAPI.playback.build_timeline) -- merges the first match_manifest (for
-- schema_version) + first lobby_info (gamemode/ruleset) + first run_info
-- (seed/deck/stake) event, replacing the old single 'manifest' event's args
-- now that match framing is split across three events fired at three
-- different scopes (see BalatroMultiplayerAPI/api/replay/framing_codes.lua).
-- Returns the same {seed, deck, gamemode, ...} shape SPDRN._start_playback
-- already expects, plus schema_version for the compatibility gate below.
local function find_bootstrap(timeline, player_id)
	local bootstrap = {}
	local found = {}
	for _, entry in ipairs(timeline) do
		if entry.player_id == player_id then
			if not found.match_manifest and entry.opcode == 'match_manifest' then
				found.match_manifest = true
				bootstrap.schema_version = entry.args.schema_version
			elseif not found.lobby_info and entry.opcode == 'lobby_info' then
				found.lobby_info = true
				bootstrap.gamemode = entry.args.gamemode
				bootstrap.ruleset = entry.args.ruleset
			elseif not found.run_info and entry.opcode == 'run_info' then
				found.run_info = true
				bootstrap.seed = entry.args.seed
				bootstrap.deck = entry.args.deck
				bootstrap.stake = entry.args.stake
			end
			if found.match_manifest and found.lobby_info and found.run_info then break end
		end
	end
	if not (found.lobby_info and found.run_info) then return nil end
	return bootstrap
end

function SPDRN._launch_replay(run_id)
	MPAPI.replay.get(run_id, function(err, data)
		if err or not data or not data.logs then
			SPDRN.sendWarnMessage('[replay] failed to load run ' .. tostring(run_id) .. ': ' .. tostring(err and err.message))
			return
		end

		local timeline = MPAPI.playback.build_timeline(data.logs)
		local conn = MPAPI.get_connection()
		local my_id = conn and conn.player_id
		local bootstrap = find_bootstrap(timeline, my_id)
		if not bootstrap then
			SPDRN.sendWarnMessage('[replay] no bootstrap data found for our own player in run ' .. tostring(run_id))
			return
		end
		if not MPAPI.replay.is_schema_compatible(bootstrap.schema_version) then
			SPDRN.sendWarnMessage(
				'[replay] recording schema_version ' .. tostring(bootstrap.schema_version)
				.. ' is newer than this client understands (' .. tostring(MPAPI.replay.SCHEMA_VERSION) .. '); refusing to play'
			)
			return
		end

		SPDRN._start_playback(bootstrap, function()
			local driver = MPAPI.playback.new_driver(timeline, {
				mod_id = 'spdrn',
				pov_player_id = my_id,
				schema_version = bootstrap.schema_version,
				on_complete = function()
					-- No `cover` field: confirmed live to crash
					-- (functions/UI_definitions.lua's attention_text expects
					-- a real UI target with its own `.T` transform there, not
					-- a bare {align=...} table) -- `cover` is optional, so
					-- omitting it entirely sidesteps that branch rather than
					-- trying to construct a valid one just for a toast.
					attention_text({
						text = 'Replay finished',
						scale = 1,
						hold = 3,
						pos = { x = 0, y = 0 },
					})
				end,
			})
			driver:finish()
			driver:play()
		end)
	end)
end

-- Registered under SPDRN.id (the SMODS mod id, what a RunRow's own `modId`
-- carries, since MPAPI.create_lobby/create_local_lobby are always called
-- with SPDRN.id) -- NOT the literal 'spdrn' string used above for
-- mod_id = 'spdrn' / register_handler('spdrn', ...), a separate opcode-
-- dispatch namespace this mod happens to also use the same word for.
MPAPI.playback.register_launcher(SPDRN.id, SPDRN._launch_replay)

G.FUNCS.spdrn_open_replay_browser = function()
	MPAPI.replay.list_mine(nil, function(err, data)
		if err then
			SPDRN.sendWarnMessage('[replay] list_mine failed: ' .. tostring(err.message))
			return
		end

		-- MPAPI.replay.list_mine returns every run for this player across every
		-- mod (the server route has no modId filter) -- confirmed live: with
		-- PvP also installed, this list included PvP runs too. Filter to
		-- SPDRN's own here rather than showing (and mis-launching, via the
		-- wrong playback engine/opcode vocabulary) another mod's replay.
		local all_runs = (data and data.runs) or {}
		local runs = {}
		for _, run in ipairs(all_runs) do
			if run.modId == SPDRN.id then runs[#runs + 1] = run end
		end
		local rows = {
			{ n = G.UIT.R, config = { align = 'cm', padding = 0.1 }, nodes = {
				{ n = G.UIT.T, config = { text = 'My Replays', scale = 0.6, colour = G.C.UI.TEXT_LIGHT, shadow = true } },
			} },
		}

		if #runs == 0 then
			rows[#rows + 1] = { n = G.UIT.R, config = { align = 'cm', minh = 2 }, nodes = {
				{ n = G.UIT.T, config = { text = 'No replays yet.', scale = 0.4, colour = G.C.UI.TEXT_LIGHT } },
			} }
		else
			for _, run in ipairs(runs) do
				rows[#rows + 1] = { n = G.UIT.R, config = { align = 'cm', padding = 0.05 }, nodes = {
					UIBox_button({
						button = 'spdrn_replay_pick_' .. run.id,
						label = { format_run_label(run) },
						colour = G.C.GREEN,
						minw = 5,
						minh = 0.6,
						scale = 0.35,
					}),
				} }
				G.FUNCS['spdrn_replay_pick_' .. run.id] = function()
					G.FUNCS.exit_overlay_menu()
					SPDRN._launch_replay(run.id)
				end
			end
		end

		G.FUNCS.overlay_menu({ definition = create_UIBox_generic_options({ contents = rows }) })
	end)
end
