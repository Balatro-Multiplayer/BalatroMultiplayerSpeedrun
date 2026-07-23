-- Tear down the live run's board and blind HUD before a fresh one is started. G.FUNCS.start_run
-- queues its own delete_run but never nils G.HUD_blind synchronously, so a stale blind HUD
-- lingers and crashes the blind-HUD update assert (smods src/overrides.lua), reliably at high
-- game speed. delete_run is nil-guarded and leaves G.STAGE untouched, so calling this twice
-- (once here, once inside a gamemode's start_run) is a harmless no-op the second time.
--
-- G.TAROT_INTERRUPT is set while a consumable is being used and cleared by a queued event after.
-- Tearing a run down mid-animation (or G.FUNCS.start_run's clear_queue) strands that event, so the
-- flag leaks into the next run -- where smods handle_card_limit then skips initialising
-- card_limits.extra_slots_used and crashes the next run's CardArea:init on nil arithmetic. Reset
-- it so every fresh run starts from a clean interrupt state.
function SPDRN.teardown_existing_run()
	pcall(function()
		if G.STAGE == G.STAGES.RUN and G.delete_run then
			G:delete_run()
		end
		G.HUD_blind = nil
		G.TAROT_INTERRUPT = nil
		G.TAROT_INTERRUPT_PULSE = nil
	end)
end

-- Pending run-start/restart request, consumed outside any Event's call stack -- see
-- SPDRN._check_pending_run_transition, polled from core.lua's Game:update hook (the same spot
-- SPDRN._check_run_lost already runs from). Deferring via another queued Event is NOT safe here:
-- G.FUNCS.start_run calls G.E_MANAGER:clear_queue(), and calling that from inside an Event.func
-- that EventManager:update() is still iterating corrupts the iterator's stale index -- its next
-- unconditional table.remove(v, i) can delete the screenwipe overlay's own cleanup event (the
-- screen stays black forever, locked, since G.CONTROLLER.locks.wipe follows G.screenwipe ~= nil)
-- or the real G:start_run() call itself (nothing gets rebuilt), depending on what else happens to
-- be queued at that instant -- which is exactly why White Stake Triple's deck switch black-
-- screened only sometimes. Confirmed by directly reproducing the EventManager mutation-during-
-- iteration hazard in isolation. A flag polled on the next Game:update tick runs after that
-- frame's EventManager:update() has already returned, so it's never inside an active iteration.
SPDRN._pending_run_transition = nil

function SPDRN.request_run_transition(instance, deck, seed)
	SPDRN._pending_run_transition = { instance = instance, deck = deck, seed = seed }
end

function SPDRN._check_pending_run_transition()
	local pending = SPDRN._pending_run_transition
	if not pending then
		return
	end
	SPDRN._pending_run_transition = nil
	-- §16.8: every individual run (first and subsequent, within a multi-run
	-- match) gets its own start timestamp, so record_run_completed measures
	-- just this run rather than the whole match's elapsed time.
	SPDRN.reset_current_run_timer()
	pending.instance:start_run(pending.deck, pending.seed)
end

-- Start (or restart) a Balatro run safely: tear down the current run first, then start fresh on
-- the next Game:update tick (see SPDRN.request_run_transition above for why not another Event).
local function safe_start_run(instance, deck, seed)
	SPDRN.teardown_existing_run()
	SPDRN.request_run_transition(instance, deck, seed)
end

-- Deferred starting-money override (Seed Scout's $500 scouting budget). G.FUNCS.start_run has
-- no `dollars` opt -- Game:start_run sets G.GAME.dollars = G.GAME.starting_params.dollars
-- synchronously inside its own queued Event, so any override has to happen strictly after that,
-- not be passed in up front. Level-triggered (polls every frame until the new run is actually
-- ready) rather than a fixed tick count, since start_run's own delete_run/start_run Event pair
-- doesn't guarantee a specific number of frames before the run is actually live.
--
-- Waits for G.STATE == G.STATES.BLIND_SELECT specifically (the same signal SPDRN.begin_run's
-- own wait condition already uses as "a run has actually started") -- NOT G.STAGE ==
-- G.STAGES.RUN. A same-stage restart (e.g. Seed Scout's scout-death auto-restart) never leaves
-- the RUN stage at all, so checking G.STAGE alone fires immediately on the OLD (dying) run's
-- still-current G.GAME, before delete_run/start_run's queued events even replace it with the
-- fresh object -- the override lands on a G.GAME that's about to be discarded, so it never
-- actually sticks. G.STATE, by contrast, genuinely leaves BLIND_SELECT (goes to GAME_OVER) on
-- death and only returns to it once the NEW run's setup has fully completed.
SPDRN._pending_dollars_override = nil

function SPDRN._check_pending_dollars_override()
	local amount = SPDRN._pending_dollars_override
	if not amount then
		return
	end
	if not (G.GAME and G.STATE == G.STATES.BLIND_SELECT and G.blind_select ~= nil) then
		return
	end
	SPDRN._pending_dollars_override = nil
	G.GAME.dollars = amount
	G.GAME.starting_params.dollars = amount
end

-- Instantiate the gamemode for the current lobby and start the Balatro run. Shared by the
-- start_game action, practice, play-again, and seed-vote restart. `decks` is either a single
-- deck ref (single-deck flow) or a list of deck refs from a ban-pick draft (one per run). A
-- "ref" is a center key or display name; see SPDRN.resolve_back_key.
function SPDRN.begin_run(gamemode_key, decks, seed)
	local lobby = MPAPI.get_current_lobby()
	if not lobby then
		return
	end
	local gm_def = gamemode_key and MPAPI.GameModes[gamemode_key]
	if not gm_def then
		SPDRN.sendWarnMessage('begin_run: unknown gamemode: ' .. tostring(gamemode_key))
		return
	end
	local deck_list = type(decks) == 'table' and decks or { decks }
	-- Starting the game clears everyone's ready state (every client assumes this locally, no
	-- broadcast needed), so returning to the lobby requires re-readying.
	SPDRN.reset_ready_state()
	SPDRN.lobby.seed_votes:reset()
	-- §16.8: fresh per-match progress/result-collection state -- must not carry
	-- over from whatever match (if any) this player was previously in.
	SPDRN.reset_match_progress()
	-- Client-side run clock (gates the seed-change window) and the deck(s) used for this run
	-- (so a same-seed restart can reuse them).
	SPDRN._run_started_at = love.timer.getTime()
	SPDRN._run_deck = deck_list[1]
	SPDRN._run_decks = deck_list
	if SPDRN.timer then
		SPDRN.timer.start()
	end
	local instance = gm_def:new_instance()
	instance._run_decks = deck_list
	-- The match's base seed (run 1). Multi-run formats derive their later runs' seeds from this
	-- so every client lands on the same sequence (see SPDRN.derive_seed). All clients receive the
	-- same broadcast `seed`, so this is identical across the lobby.
	instance._base_seed = seed
	-- Optional per-lobby-metadata fields a gamemode may need at run-start time (Challenge's
	-- picked challenge id, Seed Scout's picked stake) -- unused by every other gamemode.
	local meta = lobby:get_metadata() or {}
	instance._meta_challenge = meta.challenge
	instance._meta_stake = tonumber(meta.stake)
	lobby._gamemode_instance = instance
	safe_start_run(instance, deck_list[1], seed)
end

-- Restart the *current* run on its current seed without creating a new gamemode instance, so
-- per-format progress (e.g. White Stake Triple's run count) is kept. Used by "Restart Run".
function SPDRN.restart_current_run()
	local lobby = MPAPI.get_current_lobby()
	if not lobby then
		return
	end
	local instance = lobby:get_gamemode_instance()
	if not instance then
		return
	end
	local seed = G.GAME and G.GAME.pseudorandom and G.GAME.pseudorandom.seed
	-- Replay the current run's deck. With a draft (or a multi-deck mode), that's the deck for
	-- the run in progress (_run_count counts completed runs, so the live run is index + 1).
	local run_idx = (instance._run_count or 0) + 1
	local meta_deck = (lobby:get_metadata() or {}).deck
	local meta_deck_for_run = type(meta_deck) == 'table' and (meta_deck[run_idx] or meta_deck[1]) or meta_deck
	local deck = (instance._run_decks and instance._run_decks[run_idx])
		or SPDRN._run_deck or meta_deck_for_run or SPDRN.Deck.DEFAULT
	SPDRN.lobby.seed_votes:reset()
	-- Don't reset SPDRN._run_started_at: a restart continues the same run clock, matching
	-- multi-run progression. resume() keeps the timer active without zeroing it (and is a safe
	-- no-op since the run-lost screen no longer freezes the clock).
	if SPDRN.timer then
		SPDRN.timer.resume()
	end
	safe_start_run(instance, deck, seed)
end

-- Host broadcasts the start so every client (itself included, via the loopback) runs the same
-- synced countdown and starts on the same seed.
function SPDRN.broadcast_start(seed)
	local lobby = SPDRN.lobby.ref or MPAPI.get_current_lobby()
	if not lobby then
		return
	end
	local action = lobby:action(MPAPI.ActionTypes['spdrn_start_game'])
	action:broadcast({ seed = seed or SPDRN.generate_seed() })
end

-- Host (private) clicks START -> broadcast the start to everyone.
G.FUNCS.spdrn_start_game = function()
	local lobby = SPDRN.lobby.ref
	if not lobby or not lobby.is_host then
		return
	end
	SPDRN.broadcast_start(SPDRN.generate_seed())
end
